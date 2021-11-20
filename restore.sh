#!/usr/bin/env bash
set -o errexit
set -o pipefail

# Check Parameters
[ -z "$KUBE_CONTEXT" ] && echo "ERROR: Environment variable KUBE_CONTEXT is not set" && exit 1
[ -z "$WIKI_NAMSPACE" ] && echo "ERROR: Environment variable WIKI_NAMSPACE is not set" && exit 1
[ -z "$MYSQL_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1
[ -z "$BOOKSTACK_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1
MYSQL_CONTAINER="bookstack-mysql"
BOOKSTACK_CONTAINER="bookstack"

# Print parameters
echo "KUBE_CONTEXT       : $KUBE_CONTEXT"
echo "WIKI_NAMSPACE      : $WIKI_NAMSPACE"
echo "MYSQL_APP_LABEL    : $MYSQL_APP_LABEL"
echo "BOOKSTACK_APP_LABEL: $BOOKSTACK_APP_LABEL"
echo

if [ -z "$1" ] || [ "$1" != '-y' ]; then
    read -rp "Press [Enter] to restore into $KUBE_CONTEXT/$WIKI_NAMSPACE..."
    echo
fi

# Restore MySQL
MYSQL_PODS="$(kubectl get pod -o name -l app="$MYSQL_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE")"
if [ -z "$MYSQL_PODS" ]; then echo "ERROR: Cannot find any $MYSQL_APP_LABEL pod" >&2 && exit 90; fi
MYSQL_POD_NAME="$(echo "${MYSQL_PODS}" | head -1 | grep -o '[^/]*$')"

printf "Copying MySQL DB Backup into %s ...\n" "$MYSQL_POD_NAME"
tar -czf - ./backup/bookstack.sql | kubectl exec -i --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- tar -xzf - -C /root

if { [ -z "$HOST_FROM" ] || [ -z "$HOST_TO" ]; }; then 
    printf "HOST_FROM and/or HOST_TO not specified. Skip updating hostname.\n"
else
    printf "Updating hostname from '%s' to '%s' ...\n" "$HOST_FROM" "$HOST_TO"
    kubectl exec --context="$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- bash -c "sed -i'.bak' -e 's/$HOST_FROM/$HOST_TO/g' /root/bookstack.sql"
fi 
printf "\nRestoring MySQL DB on %s ...\n" "$MYSQL_POD_NAME"
kubectl exec --context="$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- bash -c "echo 'FLUSH PRIVILEGES;' >> /root/bookstack.sql && MYSQL_PWD=secret mysql < /root/bookstack.sql && rm /root/bookstack.sql"

# Restore Bookstack
BOOKSTACK_PODS="$(kubectl get pod -o name -l app="$BOOKSTACK_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE")"
if [ -z "$BOOKSTACK_PODS" ]; then echo "ERROR: Cannot find any $BOOKSTACK_APP_LABEL pod" >&2 && exit 90; fi
BOOKSTACK_POD_NAME="$(echo "${BOOKSTACK_PODS}" | head -1 | grep -o '[^/]*$')"

printf "Copying Bookstack Uploads into %s ...\n" "$BOOKSTACK_POD_NAME"
kubectl exec -i --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- tar -xzf - -C /var/www/bookstack/public/uploads < ./backup/uploads.tgz

printf "Copying Bookstack Storage into %s ...\n" "$BOOKSTACK_POD_NAME"
kubectl exec -i --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- tar -xzf - -C /var/www/bookstack/storage < ./backup/storage.tgz

printf "Recreating %s pod ...\n" "$BOOKSTACK_APP_LABEL"
kubectl scale --replicas=0 deploy -l app="$BOOKSTACK_APP_LABEL" --namespace="$WIKI_NAMSPACE"
kubectl scale --replicas=1 deploy -l app="$BOOKSTACK_APP_LABEL" --namespace="$WIKI_NAMSPACE"

printf "\nNOTE: If Bookstack pod is error. Check logs and if it complains about table 'api_tokens', drop the table.\n"