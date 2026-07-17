#!/usr/bin/env bash
set -o errexit
set -o pipefail

start_clock() {
	START=$(date +%s)
}

stop_clock() {
	END=$(date +%s)
	DIFF=$((END - START))
	# shellcheck disable=SC2059
	printf "$1" "$DIFF"
}

# Check Parameters
[ -z "$KUBE_CONTEXT" ] && echo "ERROR: Environment variable KUBE_CONTEXT is not set" && exit 1
[ -z "$WIKI_NAMESPACE" ] && echo "ERROR: Environment variable WIKI_NAMESPACE is not set" && exit 1
[ -z "$MYSQL_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1
[ -z "$BOOKSTACK_APP_LABEL" ] && echo "ERROR: Environment variable BOOKSTACK_APP_LABEL is not set" && exit 1
MYSQL_PASSWORD="${MYSQL_PASSWORD:-secret}"
MYSQL_CONTAINER="bookstack-mysql"
BOOKSTACK_CONTAINER="bookstack"

# Print parameters
echo "KUBE_CONTEXT       : $KUBE_CONTEXT"
echo "WIKI_NAMESPACE     : $WIKI_NAMESPACE"
echo "MYSQL_APP_LABEL    : $MYSQL_APP_LABEL"
echo "BOOKSTACK_APP_LABEL: $BOOKSTACK_APP_LABEL"
echo

if [ -z "$1" ] || [ "$1" != '-y' ]; then
	read -rp "Press [Enter] to restore into $KUBE_CONTEXT/$WIKI_NAMESPACE..."
	echo
fi

# Restore MySQL
MYSQL_PODS="$(kubectl get pod -o name -l app="$MYSQL_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE")"
if [ -z "$MYSQL_PODS" ]; then echo "ERROR: Cannot find any $MYSQL_APP_LABEL pod" >&2 && exit 90; fi
MYSQL_POD_NAME="$(echo "${MYSQL_PODS}" | head -1 | grep -o '[^/]*$')"

printf "Copying MySQL DB Backup into %s ... " "$MYSQL_POD_NAME"
start_clock
kubectl cp --context "$KUBE_CONTEXT" --namespace "$WIKI_NAMESPACE" -c "$MYSQL_CONTAINER" \
	./backup/bookstack.tgz "$MYSQL_POD_NAME:/tmp/bookstack.tgz"
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- \
	tar -xzf /tmp/bookstack.tgz -C /root
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- \
	rm /tmp/bookstack.tgz
stop_clock "%s seconds\n"

if { [ -z "$HOST_FROM" ] || [ -z "$HOST_TO" ]; }; then
	printf "HOST_FROM and/or HOST_TO not specified. Skip updating hostname.\n"
else
	printf "Updating hostname from '%s' to '%s' ... " "$HOST_FROM" "$HOST_TO"
	start_clock
	kubectl exec --context="$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- bash -c "sed -i'.bak' -e 's/$HOST_FROM/$HOST_TO/g' /root/bookstack.sql"
	stop_clock "%s seconds\n"
fi
printf "Restoring MySQL DB on %s ... " "$MYSQL_POD_NAME"
start_clock
kubectl exec --context="$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- env MYSQL_PWD="$MYSQL_PASSWORD" bash -c "echo 'FLUSH PRIVILEGES;' >> /root/bookstack.sql && mysql < /root/bookstack.sql && rm /root/bookstack.sql"
stop_clock "%s seconds\n"
echo

# Restore Bookstack
BOOKSTACK_PODS="$(kubectl get pod -o name -l app="$BOOKSTACK_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE")"
if [ -z "$BOOKSTACK_PODS" ]; then echo "ERROR: Cannot find any $BOOKSTACK_APP_LABEL pod" >&2 && exit 90; fi
BOOKSTACK_POD_NAME="$(echo "${BOOKSTACK_PODS}" | head -1 | grep -o '[^/]*$')"

printf "Copying Bookstack Uploads into %s ... " "$BOOKSTACK_POD_NAME"
start_clock
kubectl cp --context "$KUBE_CONTEXT" --namespace "$WIKI_NAMESPACE" -c "$BOOKSTACK_CONTAINER" \
	./backup/uploads.tgz "$BOOKSTACK_POD_NAME:/tmp/uploads.tgz"
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- \
	tar -xzf /tmp/uploads.tgz -C /var/www/bookstack/public/uploads
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- \
	rm /tmp/uploads.tgz
stop_clock "%s seconds\n"
echo

printf "Copying Bookstack Storage into %s ... " "$BOOKSTACK_POD_NAME"
start_clock
kubectl cp --context "$KUBE_CONTEXT" --namespace "$WIKI_NAMESPACE" -c "$BOOKSTACK_CONTAINER" \
	./backup/storage.tgz "$BOOKSTACK_POD_NAME:/tmp/storage.tgz"
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- \
	tar -xzf /tmp/storage.tgz -C /var/www/bookstack/storage
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- \
	rm /tmp/storage.tgz
stop_clock "%s seconds\n"
echo

printf "Recreating %s pod ...\n" "$BOOKSTACK_APP_LABEL"
kubectl scale --replicas=0 deploy -l app="$BOOKSTACK_APP_LABEL" --namespace="$WIKI_NAMESPACE"
kubectl scale --replicas=1 deploy -l app="$BOOKSTACK_APP_LABEL" --namespace="$WIKI_NAMESPACE"

printf "\nNOTE: If the BookStack pod is in an error state, check logs; if it complains about table 'api_tokens', drop the table.\n"
