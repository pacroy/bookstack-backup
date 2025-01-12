#!/usr/bin/env bash
set -o errexit
set -o pipefail

start_clock() {
    START=$(date +%s.%N)
}

stop_clock() {
    END=$(date +%s.%N)
    DIFF=$(("$END" - "$START"))
    # shellcheck disable=SC2059
    printf "$1" "$DIFF"
}

# Check Parameters
[ -z "$KUBE_CONTEXT" ] && echo "ERROR: Environment variable KUBE_CONTEXT is not set" && exit 1
[ -z "$WIKI_NAMESPACE" ] && echo "ERROR: Environment variable WIKI_NAMESPACE is not set" && exit 1
[ -z "$MYSQL_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1
[ -z "$BOOKSTACK_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1
MYSQL_CONTAINER="bookstack-mysql"
BOOKSTACK_CONTAINER="bookstack"

# Print parameters
echo "KUBE_CONTEXT       : $KUBE_CONTEXT"
echo "WIKI_NAMESPACE     : $WIKI_NAMESPACE"
echo "MYSQL_APP_LABEL    : $MYSQL_APP_LABEL"
echo "BOOKSTACK_APP_LABEL: $BOOKSTACK_APP_LABEL"
echo

if [ -z "$1" ] || [ "$1" != '-y' ]; then
    read -rp "Press [Enter] to backup from $KUBE_CONTEXT/$WIKI_NAMESPACE..."
    echo
fi

# Backup MySQL
MYSQL_PODS="$(kubectl get pod -o name -l app="$MYSQL_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE")"
if [ -z "$MYSQL_PODS" ]; then echo "ERROR: Cannot find any $MYSQL_APP_LABEL pod" >&2 && exit 90; fi
MYSQL_POD_NAME="$(echo "${MYSQL_PODS}" | head -1 | grep -o '[^/]*$')"

printf "Copying BookStack MySQL DB from %s ... " "$MYSQL_POD_NAME"
start_clock
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- bash -c "MYSQL_PWD=secret mysqldump --all-databases > bookstack.sql"
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- bash -c "tar -czf - bookstack.sql | cat" > ./backup/bookstack.tgz
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- bash -c "rm -f bookstack.sql"
stop_clock "%s seconds\n"
echo

## Backup Bookstack
#BOOKSTACK_PODS="$(kubectl get pod -o name -l app="$BOOKSTACK_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE")"
#if [ -z "$BOOKSTACK_PODS" ]; then echo "ERROR: Cannot find any $BOOKSTACK_APP_LABEL pod" >&2 && exit 90; fi
#BOOKSTACK_POD_NAME="$(echo "${BOOKSTACK_PODS}" | head -1 | grep -o '[^/]*$')"
#
#printf "Copying BookStack Uploads from %s ... " "$BOOKSTACK_POD_NAME"
#start_clock
#kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- bash -c "cd /var/www/bookstack/public/uploads && tar -czf - * | cat" > ./backup/uploads.tgz
#stop_clock "%s seconds\n"
#echo
#
#printf "Copying BookStack Storage from %s ... " "$BOOKSTACK_POD_NAME"
#start_clock
#kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMESPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- bash -c "cd /var/www/bookstack/storage && tar -czf - uploads | cat" > ./backup/storage.tgz
#stop_clock "%s seconds\n"
