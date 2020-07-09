#!/bin/bash
set -e

# Check Parameters
[ -z "$KUBE_CONTEXT" ] && echo "ERROR: Environment variable KUBE_CONTEXT is not set" && exit 1
[ -z "$WIKI_NAMSPACE" ] && echo "ERROR: Environment variable WIKI_NAMSPACE is not set" && exit 1
[ -z "$MYSQL_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1
[ -z "$BOOKSTACK_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1
if [ -z "$1" ] || [ $1 != '-y' ]; then
    read -p "Press [Enter] to restore into $KUBE_CONTEXT/$WIKI_NAMSPACE..."
fi

# Restore MySQL
MYSQL_POD_NAME=$(kubectl get pod -o name -l app=$MYSQL_APP_LABEL --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
[ -z "$MYSQL_POD_NAME" ] && echo "ERROR: Cannot find a $MYSQL_APP_LABEL pod" && exit 1
echo -e "\nCopying MySQL DB Backup into $MYSQL_POD_NAME..."
kubectl cp --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE ./backup/bookstack.sql $MYSQL_POD_NAME:/root/bookstack.sql
if { [ -z "$HOST_FROM" ] || [ -z "$HOST_TO" ]; }; then 
    echo -e "\nPROD_HOST and/or UAT_HOST not specified. Skip updating hostname."
else
    echo -e "\nUpdating hostname from '$HOST_FROM' to '$HOST_TO'..."
    kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $MYSQL_POD_NAME -- bash -c "sed -i'.bak' -e 's/$HOST_FROM/$HOST_TO/g' /root/bookstack.sql"
fi 
echo -e "\nRestoring MySQL DB on $MYSQL_POD_NAME..."
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $MYSQL_POD_NAME -- bash -c "echo 'FLUSH PRIVILEGES;' >> /root/bookstack.sql && MYSQL_PWD=secret mysql < /root/bookstack.sql && rm /root/bookstack.sql && exit"

# Restore Bookstack
BOOKSTACK_POD_NAME=$(kubectl get pod -o name -l app=$BOOKSTACK_APP_LABEL --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
[ -z "$BOOKSTACK_POD_NAME" ] && echo "ERROR: Cannot find a $BOOKSTACK_APP_LABEL pod" && exit 1
echo -e "\nCopying Bookstack Uploads Backup into $BOOKSTACK_POD_NAME..."
kubectl cp --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE ./backup/uploads.tgz $BOOKSTACK_POD_NAME:/var/www/bookstack/uploads.tgz
echo -e "\nExtracting Bookstack Uploads Backup on $BOOKSTACK_POD_NAME..."
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "tar -xvzf /var/www/bookstack/uploads.tgz -C /var/www/bookstack/public/uploads | wc -l | xargs -i echo {} 'file(s) extracted' && rm /var/www/bookstack/uploads.tgz && exit"
echo -e "\nCopying Bookstack Storage Backup into $BOOKSTACK_POD_NAME..."
kubectl cp --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE ./backup/storage.tgz $BOOKSTACK_POD_NAME:/var/www/bookstack/storage.tgz
echo -e "\nExtracting Bookstack Storage Backup on $BOOKSTACK_POD_NAME..."
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "tar -xvzf /var/www/bookstack/storage.tgz -C /var/www/bookstack/storage | wc -l | xargs -i echo {} 'file(s) extracted' && rm /var/www/bookstack/storage.tgz && exit"
echo -e "\nRecreating $BOOKSTACK_APP_LABEL pod..."
kubectl scale --replicas=0 deploy -l app=$BOOKSTACK_APP_LABEL --namespace=$WIKI_NAMSPACE
kubectl scale --replicas=1 deploy -l app=$BOOKSTACK_APP_LABEL --namespace=$WIKI_NAMSPACE

echo -e "\nNOTE: If Bookstack pod is error. Check logs and if it complains about table 'api_tokens', drop the table."