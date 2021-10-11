#!/bin/bash
set -o errexit
set -o pipefail

# Check Parameters
[ -z "$KUBE_CONTEXT" ] && echo "ERROR: Environment variable KUBE_CONTEXT is not set" && exit 1
[ -z "$WIKI_NAMSPACE" ] && echo "ERROR: Environment variable WIKI_NAMSPACE is not set" && exit 1
[ -z "$MYSQL_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1
[ -z "$BOOKSTACK_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1

# Print parameters
echo "KUBE_CONTEXT       : $KUBE_CONTEXT"
echo "WIKI_NAMSPACE      : $WIKI_NAMSPACE"
echo "MYSQL_APP_LABEL    : $MYSQL_APP_LABEL"
echo "BOOKSTACK_APP_LABEL: $BOOKSTACK_APP_LABEL"
echo "KUBE CONTEXT       : v"
kubectl config get-contexts
echo

if [ -z "$1" ] || [ $1 != '-y' ]; then
    read -p "Press [Enter] to backup from $KUBE_CONTEXT/$WIKI_NAMSPACE..."
fi

# Backup MySQL
MYSQL_PODS=$(kubectl get pod -o name -l app=$MYSQL_APP_LABEL --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE)
[ -z "$MYSQL_PODS" ] && echo "ERROR: Cannot find any $MYSQL_APP_LABEL pod" >&2 && exit 1
MYSQL_POD_NAME=$(echo ${MYSQL_PODS} | head -1 | grep -o '[^/]*$')
echo -e "\nDumping BookStack MySQL DB from $MYSQL_POD_NAME..."
kubectl exec --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE -c bookstack-mysql $MYSQL_POD_NAME -- bash -c "rm -f ~/bookstack.sql && MYSQL_PWD=secret mysqldump --all-databases -r ~/bookstack.sql && exit"
echo -e "\nCopying BookStack DB Backup from $MYSQL_POD_NAME..."
kubectl cp --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE -c bookstack-mysql $MYSQL_POD_NAME:/root/bookstack.sql ./backup/bookstack.sql
kubectl exec --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE -c bookstack-mysql $MYSQL_POD_NAME -- bash -c "rm -f ~/bookstack.sql"

# Backup Bookstack
BOOKSTACK_PODS=$(kubectl get pod -o name -l app=$BOOKSTACK_APP_LABEL --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE)
[ -z "$BOOKSTACK_PODS" ] && echo "ERROR: Cannot find any $BOOKSTACK_APP_LABEL pod" >&2 && exit 1
BOOKSTACK_POD_NAME=$(echo ${BOOKSTACK_PODS} | head -1 | grep -o '[^/]*$')

echo -e "\nCopying BookStack Uploads from $BOOKSTACK_POD_NAME..."
kubectl exec --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="bookstack" "$BOOKSTACK_POD_NAME" -- cd /var/www/bookstack/public/uploads/ && tar czf - * > ./backup/uploads.tgz

echo -e "\nArchiving BookStack Storage from $BOOKSTACK_POD_NAME..."
kubectl exec --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE -c bookstack $BOOKSTACK_POD_NAME -- bash -c "rm -f /var/www/bookstack/storage.tgz && cd /var/www/bookstack/storage/ && tar -cvzf /var/www/bookstack/storage.tgz uploads | wc -l | xargs -i echo {} 'file(s) archived' && exit"
echo -e "\nCopying BookStack Storage from $BOOKSTACK_POD_NAME..."
kubectl cp --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE -c bookstack $BOOKSTACK_POD_NAME:/var/www/bookstack/storage.tgz ./backup/storage.tgz
kubectl exec --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE -c bookstack $BOOKSTACK_POD_NAME -- bash -c "rm -f /var/www/bookstack/storage.tgz"
