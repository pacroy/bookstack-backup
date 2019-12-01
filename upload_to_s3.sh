#!/bin/bash
set -e

[ -z "$S3_SFTP_SERVER" ] && echo "ERROR: Environment variable S3_SFTP_SERVER is not set" && exit 1
[ -z "$S3_BUCKET_NAME" ] && echo "ERROR: Environment variable S3_BUCKET_NAME is not set" && exit 1
[ -z "$S3_FOLDER_NAME" ] && echo "ERROR: Environment variable S3_FOLDER_NAME is not set" && exit 1

# Upload backup files to S3
CURRENT_DATE=`date +%Y%m%d`
sftp $S3_SFTP_SERVER <<EOF
mkdir /$S3_BUCKET_NAME/$S3_FOLDER_NAME/$CURRENT_DATE
cd /$S3_BUCKET_NAME/$S3_FOLDER_NAME/$CURRENT_DATE
put backup/bookstack.sql
put backup/uploads.tgz
bye
