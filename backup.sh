#!/bin/bash
set -e

# Check Parameters
[ -z "$KUBE_CONTEXT" ] && echo "ERROR: Environment variable KUBE_CONTEXT is not set" && exit 1
[ -z "$WIKI_NAMSPACE" ] && echo "ERROR: Environment variable WIKI_NAMSPACE is not set" && exit 1

# Backup MySQL
MYSQL_POD_NAME=$(kubectl get pod -o name -l app=bookstack-mysql --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $MYSQL_POD_NAME -- bash -c "rm -f ~/bookstack.sql && mysqldump --password='secret' --all-databases > ~/bookstack.sql && exit"
kubectl cp --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $MYSQL_POD_NAME:/root/bookstack.sql ./backup/bookstack.sql
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $MYSQL_POD_NAME -- bash -c "rm -f ~/bookstack.sql"

# Backup Bookstack
BOOKSTACK_POD_NAME=$(kubectl get pod -o name -l app=bookstack --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "rm -f ~/uploads.tgz && cd /var/www/bookstack/public/uploads/ && tar -cvzf ~/uploads.tgz * && exit"
kubectl cp --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $BOOKSTACK_POD_NAME:/root/uploads.tgz ./backup/uploads.tgz
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "rm -f ~/uploads.tgz"
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "rm -f ~/storage.tgz && cd /var/www/bookstack/storage/ && tar -cvzf ~/storage.tgz * && exit"
kubectl cp --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $BOOKSTACK_POD_NAME:/root/storage.tgz ./backup/storage.tgz
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "rm -f ~/storage.tgz"
