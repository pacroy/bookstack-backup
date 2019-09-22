# Bookstack Backup Scripts

## kubernates.sh

Shell script for backing up Bookstack application on a Kubernetes cluster and upload to an AWS S3 bucket.

### Prerequisites

In order to use this scipt, you need:

- `kubectl` with active context of the cluster
- An AWS S3 bucket with [SFTP-enabled](https://docs.aws.amazon.com/transfer/latest/userguide/what-is-aws-transfer-for-sftp.html)
- ssh client with active SSH connection the S3 SFTP server

### Execute

Set the following environment variables:

| Name | Desscription |
| --- | --- |
| KUBE_CONTEXT | Kubernetes cluster context | 
| WIKI_NAMSPACE | Kubernetes namespace running Bookstack application |
| S3_SFTP_SERVER | AWS SFTP Server Login e.g. user@sftp-server.com |
| S3_BUCKET_NAME | AWS S3 bucket name |
| S3_FOLDER_NAME | Top-level folder of the bucket where the backup files will be kept |

Execute

```
source <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/master/kubernetes.sh)
```