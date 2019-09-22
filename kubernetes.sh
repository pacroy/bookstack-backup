#!/bin/bash
set -e

# Check Parameters
[ -z "$KUBE_CONTEXT" ] && echo "ERROR: Environment variable KUBE_CONTEXT is not set" && exit 1
[ -z "$WIKI_NAMSPACE" ] && echo "ERROR: Environment variable WIKI_NAMSPACE is not set" && exit 1
[ -z "$S3_SFTP_SERVER" ] && echo "ERROR: Environment variable S3_SFTP_SERVER is not set" && exit 1
[ -z "$S3_BUCKET_NAME" ] && echo "ERROR: Environment variable S3_BUCKET_NAME is not set" && exit 1
[ -z "$S3_FOLDER_NAME" ] && echo "ERROR: Environment variable S3_FOLDER_NAME is not set" && exit 1

# Backup MySQL
MYSQL_POD_NAME=$(kubectl get pod -o name -l app=bookstack-mysql --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $MYSQL_POD_NAME -- bash -c "rm -f ~/bookstack.sql && mysqldump --password='secret' --all-databases > ~/bookstack.sql && exit"
kubectl cp --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $MYSQL_POD_NAME:/root/bookstack.sql ./backup/bookstack.sql

# Backup Bookstack
BOOKSTACK_POD_NAME=$(kubectl get pod -o name -l app=bookstack --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE | head -1 | grep -o '[^/]*$')
kubectl exec -it --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $BOOKSTACK_POD_NAME -- bash -c "rm -f ~/uploads.tgz && cd /var/www/bookstack/public/uploads/ && tar -cvzf ~/uploads.tgz * && exit"
kubectl cp --context $KUBE_CONTEXT --namespace $WIKI_NAMSPACE $BOOKSTACK_POD_NAME:/root/uploads.tgz ./backup/uploads.tgz

# Upload backup files to S3
CURRENT_DATE=`date +%Y%m%d`
sftp $S3_SFTP_SERVER <<EOF
mkdir /$S3_BUCKET_NAME/$S3_FOLDER_NAME/$CURRENT_DATE
cd /$S3_BUCKET_NAME/$S3_FOLDER_NAME/$CURRENT_DATE
put backup/bookstack.sql
put backup/uploads.tgz
bye
EOF
