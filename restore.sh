#!/bin/bash
set -e

# Check Parameters
[ -z "$KUBE_CONTEXT" ] && echo "ERROR: Environment variable KUBE_CONTEXT is not set" && exit 1
[ -z "$WIKI_NAMSPACE" ] && echo "ERROR: Environment variable WIKI_NAMSPACE is not set" && exit 1
read -p "Press [Enter] to restore into $KUBE_CONTEXT/$WIKI_NAMSPACE..."

# Restore MySQL
MYSQL_POD_NAME=$(kubectl get pod -o name -l app=bookstack-mysql --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
echo -e "\nCopying MySQL DB Backup into $MYSQL_POD_NAME..."
kubectl cp --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE ./backup/bookstack.sql $MYSQL_POD_NAME:/root/bookstack.sql
echo -e "\nRestoring MySQL DB on $MYSQL_POD_NAME..."
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $MYSQL_POD_NAME -- bash -c "echo 'FLUSH PRIVILEGES;' >> /root/bookstack.sql && mysql --password='secret' < /root/bookstack.sql && rm /root/bookstack.sql && exit"

# Restore Bookstack
BOOKSTACK_POD_NAME=$(kubectl get pod -o name -l app=bookstack --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
echo -e "\nCopying Bookstack Uploads Backup into $BOOKSTACK_POD_NAME..."
kubectl cp --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE ./backup/uploads.tgz $BOOKSTACK_POD_NAME:/root/uploads.tgz
echo -e "\nExtracting Bookstack Uploads Backup on $BOOKSTACK_POD_NAME..."
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "tar -xvzf /root/uploads.tgz -C /var/www/bookstack/public/uploads | wc -l | xargs -i echo {} 'file(s) extracted' && rm /root/uploads.tgz && exit"
kubectl scale --replicas=0 deploy/bookstack
kubectl scale --replicas=1 deploy/bookstack