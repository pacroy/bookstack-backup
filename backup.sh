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
    read -rp "Press [Enter] to backup from $KUBE_CONTEXT/$WIKI_NAMSPACE..."
    echo
fi

# Backup MySQL
MYSQL_PODS="$(kubectl get pod -o name -l app="$MYSQL_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE")"
if [ -z "$MYSQL_PODS" ]; then echo "ERROR: Cannot find any $MYSQL_APP_LABEL pod" >&2 && exit 90; fi
MYSQL_POD_NAME="$(echo "${MYSQL_PODS}" | head -1 | grep -o '[^/]*$')"

printf "Copying BookStack MySQL DB from %s ...\n" "$MYSQL_POD_NAME"
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="$MYSQL_CONTAINER" "$MYSQL_POD_NAME" -- bash -c "MYSQL_PWD=secret mysqldump --all-databases" > ./backup/bookstack.sql

# Backup Bookstack
BOOKSTACK_PODS="$(kubectl get pod -o name -l app="$BOOKSTACK_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE")"
if [ -z "$BOOKSTACK_PODS" ]; then echo "ERROR: Cannot find any $BOOKSTACK_APP_LABEL pod" >&2 && exit 90; fi
BOOKSTACK_POD_NAME="$(echo "${BOOKSTACK_PODS}" | head -1 | grep -o '[^/]*$')"

printf "Copying BookStack Uploads from %s ...\n" "$BOOKSTACK_POD_NAME"
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- bash -c "cd /var/www/bookstack/public/uploads && tar -czf - * | cat" > ./backup/uploads.tgz

printf "Copying BookStack Storage from %s ...\n" "$BOOKSTACK_POD_NAME"
kubectl exec --quiet --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="$BOOKSTACK_CONTAINER" "$BOOKSTACK_POD_NAME" -- bash -c "cd /var/www/bookstack/storage && tar -czf - uploads | cat" > ./backup/storage.tgz
