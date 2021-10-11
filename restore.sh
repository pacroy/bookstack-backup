#!/usr/bin/env bash
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

if [ -z "$1" ] || [ $1 != '-y' ]; then
    read -p "Press [Enter] to restore into $KUBE_CONTEXT/$WIKI_NAMSPACE..."
fi

# Restore MySQL
MYSQL_PODS="$(kubectl get pod -o name -l app="$MYSQL_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE")"
if [ -z "$MYSQL_PODS" ]; then echo "ERROR: Cannot find any $MYSQL_APP_LABEL pod" >&2 && exit 90; fi
MYSQL_POD_NAME="$(echo "${MYSQL_PODS}" | head -1 | grep -o '[^/]*$')"

printf "\nCopying MySQL DB Backup into $MYSQL_POD_NAME...\n"
tar -czf - ./backup/bookstack.sql | kubectl exec -i --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="bookstack-mysql" "$MYSQL_POD_NAME" -- tar -xzf - -C /root

if { [ -z "$HOST_FROM" ] || [ -z "$HOST_TO" ]; }; then 
    printf "\nHOST_FROM and/or HOST_TO not specified. Skip updating hostname.\n"
else
    printf "\nUpdating hostname from '$HOST_FROM' to '$HOST_TO'...\n"
    kubectl exec --context="$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="bookstack-mysql" "$MYSQL_POD_NAME" -- bash -c "sed -i'.bak' -e 's/$HOST_FROM/$HOST_TO/g' /root/bookstack.sql"
fi 
printf "\nRestoring MySQL DB on $MYSQL_POD_NAME...\n"
kubectl exec -it --context="$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE" --container="bookstack-mysql" "$MYSQL_POD_NAME" -- bash -c "echo 'FLUSH PRIVILEGES;' >> /root/bookstack.sql && MYSQL_PWD=secret mysql < /root/bookstack.sql && rm /root/bookstack.sql && exit"

# Restore Bookstack
BOOKSTACK_PODS="$(kubectl get pod -o name -l app="$BOOKSTACK_APP_LABEL" --context "$KUBE_CONTEXT" --namespace="$WIKI_NAMSPACE")"
if [ -z "$BOOKSTACK_PODS" ]; then echo "ERROR: Cannot find any $BOOKSTACK_APP_LABEL pod" >&2 && exit 90; fi
BOOKSTACK_POD_NAME="$(echo "${BOOKSTACK_PODS}" | head -1 | grep -o '[^/]*$')"

printf "\nCopying Bookstack Uploads Backup into $BOOKSTACK_POD_NAME...\n"
kubectl cp --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE ./backup/uploads.tgz -c bookstack $BOOKSTACK_POD_NAME:/var/www/bookstack/uploads.tgz
printf "\nExtracting Bookstack Uploads Backup on $BOOKSTACK_POD_NAME...\n"
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE -c bookstack $BOOKSTACK_POD_NAME -- bash -c "tar -xvzf /var/www/bookstack/uploads.tgz -C /var/www/bookstack/public/uploads | wc -l | xargs -i echo {} 'file(s) extracted' && rm /var/www/bookstack/uploads.tgz && exit"
printf "\nCopying Bookstack Storage Backup into $BOOKSTACK_POD_NAME...\n"
kubectl cp --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE ./backup/storage.tgz -c bookstack $BOOKSTACK_POD_NAME:/var/www/bookstack/storage.tgz
printf "\nExtracting Bookstack Storage Backup on $BOOKSTACK_POD_NAME...\n"
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE -c bookstack $BOOKSTACK_POD_NAME -- bash -c "tar -xvzf /var/www/bookstack/storage.tgz -C /var/www/bookstack/storage | wc -l | xargs -i echo {} 'file(s) extracted' && rm /var/www/bookstack/storage.tgz && exit"
printf "\nRecreating $BOOKSTACK_APP_LABEL pod...\n"
kubectl scale --replicas=0 deploy -l app=$BOOKSTACK_APP_LABEL --namespace=$WIKI_NAMSPACE
kubectl scale --replicas=1 deploy -l app=$BOOKSTACK_APP_LABEL --namespace=$WIKI_NAMSPACE

printf "\nNOTE: If Bookstack pod is error. Check logs and if it complains about table 'api_tokens', drop the table.\n"