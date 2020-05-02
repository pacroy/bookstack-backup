#!/bin/bash
set -e

# Check Parameters
[ -z "$KUBE_CONTEXT" ] && echo "ERROR: Environment variable KUBE_CONTEXT is not set" && exit 1
[ -z "$WIKI_NAMSPACE" ] && echo "ERROR: Environment variable WIKI_NAMSPACE is not set" && exit 1
[ -z "$MYSQL_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1
[ -z "$BOOKSTACK_APP_LABEL" ] && echo "ERROR: Environment variable MYSQL_APP_LABEL is not set" && exit 1
read -p "Press [Enter] to backup from $KUBE_CONTEXT/$WIKI_NAMSPACE..."

# Backup MySQL
MYSQL_POD_NAME=$(kubectl get pod -o name -l app=$MYSQL_APP_LABEL --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
[ -z "$MYSQL_POD_NAME" ] && echo "ERROR: Cannot find a $MYSQL_APP_LABEL pod" && exit 1
echo -e "\nDumping BookStack MySQL DB from $MYSQL_POD_NAME..."
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $MYSQL_POD_NAME -- bash -c "rm -f ~/bookstack.sql && mysqldump --password='secret' --all-databases > ~/bookstack.sql && exit"
echo -e "\nCopying BookStack DB Backup from $MYSQL_POD_NAME..."
kubectl cp --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $MYSQL_POD_NAME:/root/bookstack.sql ./backup/bookstack.sql
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $MYSQL_POD_NAME -- bash -c "rm -f ~/bookstack.sql"

# Backup Bookstack
BOOKSTACK_POD_NAME=$(kubectl get pod -o name -l app=$BOOKSTACK_APP_LABEL --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
[ -z "$BOOKSTACK_POD_NAME" ] && echo "ERROR: Cannot find a $BOOKSTACK_APP_LABEL pod" && exit 1
echo -e "\nArchiving BookStack Uploads from $BOOKSTACK_POD_NAME..."
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "rm -f /var/www/uploads.tgz && cd /var/www/bookstack/public/uploads/ && tar -cvzf /var/www/uploads.tgz * | wc -l | xargs -i echo {} 'file(s) archived' && exit"
echo -e "\nCopying BookStack Uploads from $BOOKSTACK_POD_NAME..."
kubectl cp --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $BOOKSTACK_POD_NAME:/var/www/uploads.tgz ./backup/uploads.tgz
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "rm -f /var/www/uploads.tgz"
echo -e "\nArchiving BookStack Storage from $BOOKSTACK_POD_NAME..."
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "rm -f /var/www/storage.tgz && cd /var/www/bookstack/storage/ && tar -cvzf /var/www/storage.tgz * | wc -l | xargs -i echo {} 'file(s) archived' && exit"
echo -e "\nCopying BookStack Storage from $BOOKSTACK_POD_NAME..."
kubectl cp --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $BOOKSTACK_POD_NAME:/var/www/storage.tgz ./backup/storage.tgz
kubectl exec -it --context $KUBE_CONTEXT --namespace=$WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "rm -f /var/www/storage.tgz"
