#!/bin/bash
set -e

# Check Parameters
[ -z "$KUBE_CONTEXT" ] && echo "ERROR: Environment variable KUBE_CONTEXT is not set" && exit 1
[ -z "$WIKI_NAMSPACE" ] && echo "ERROR: Environment variable WIKI_NAMSPACE is not set" && exit 1

# Restore MySQL
MYSQL_POD_NAME=$(kubectl get pod -o name -l app=bookstack-mysql --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
kubectl cp --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE ./backup/bookstack.sql $MYSQL_POD_NAME:/root/bookstack.sql
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $MYSQL_POD_NAME -- bash -c "echo 'FLUSH PRIVILEGES;' >> /root/bookstack.sql && mysql --password='secret' < /root/bookstack.sql && rm /root/bookstack.sql && exit"

# Restore Bookstack
BOOKSTACK_POD_NAME=$(kubectl get pod -o name -l app=bookstack --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
kubectl cp --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE ./backup/uploads.tgz $BOOKSTACK_POD_NAME:/root/uploads.tgz
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "tar -xvzf /root/uploads.tgz -C /var/www/bookstack/public/uploads && rm /root/uploads.tgz && exit"
kc scale --replicas=0 deploy/bookstack
kc scale --replicas=1 deploy/bookstack