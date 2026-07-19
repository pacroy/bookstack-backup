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
[ -z "$BOOKSTACK_APP_LABEL" ] && echo "ERROR: Environment variable BOOKSTACK_APP_LABEL is not set" && exit 1
BOOKSTACK_CONTAINER="bookstack"

# Get Bookstack pod
BOOKSTACK_PODS="$(kubectl get pod -o name -l app="$BOOKSTACK_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE")"
if [ -z "$BOOKSTACK_PODS" ]; then echo "ERROR: Cannot find any $BOOKSTACK_APP_LABEL pod" >&2 && exit 90; fi
BOOKSTACK_POD_NAME="$(echo "${BOOKSTACK_PODS}" | head -1 | grep -o '[^/]*$')"

# Print parameters
echo "KUBE_CONTEXT       : $KUBE_CONTEXT"
echo "WIKI_NAMESPACE     : $WIKI_NAMESPACE"
echo "BOOKSTACK_APP_LABEL: $BOOKSTACK_APP_LABEL"
echo

if [ -z "$1" ] || [ "$1" != '-y' ]; then
	read -rp "Press [Enter] to cleanup images on $KUBE_CONTEXT/$WIKI_NAMESPACE/$BOOKSTACK_POD_NAME..."
	echo
fi

printf "Cleaning up Bookstack images on %s ... " "$BOOKSTACK_POD_NAME"
start_clock
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- \
	php artisan bookstack:cleanup-images
stop_clock "%s seconds\n"
echo

printf "Recreating %s pod ...\n" "$BOOKSTACK_APP_LABEL"
kubectl scale --replicas=0 deploy -l app="$BOOKSTACK_APP_LABEL" --namespace="$WIKI_NAMESPACE"
kubectl scale --replicas=1 deploy -l app="$BOOKSTACK_APP_LABEL" --namespace="$WIKI_NAMESPACE"
