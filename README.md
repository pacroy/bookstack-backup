# Bookstack Backup Scripts

Shell scripts to back up and restore Bookstack + MySQL on a Kubernetes cluster.

## Prerequisites

In order to use [backup](backup.sh) and [restore](restore.sh) script, you need:

- `kubectl` with active context of the cluster to backup

In order to use upload_to_s3 script, you need:

- An AWS S3 bucket with [SFTP-enabled](https://docs.aws.amazon.com/transfer/latest/userguide/what-is-aws-transfer-for-sftp.html) 
- ssh client with active SSH connection to the S3 SFTP server

## Backup

Create and execute shell script file like this:

```shell
#!/bin/bash
set -e

# Parameters
KUBE_CONTEXT=<Kubernetes Context Name>
WIKI_NAMSPACE=<Bookstack Namespace>

# Execute
source <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/master/backup.sh)
```

## Restore

Create and execute shell script file like this:

```shell
#!/bin/bash
set -e

# Parameters
KUBE_CONTEXT=<Kubernetes Context Name>
WIKI_NAMSPACE=<Bookstack Namespace>

# Execute
source <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/master/restore.sh)
```

## Upload to S3 via SFTP

Create and execute shell script file like this:

```shell
#!/bin/bash
set -e

# Parameters
S3_SFTP_SERVER=<user@your-sftp-server.com>
S3_BUCKET_NAME=<S3 Bucket Name>
S3_FOLDER_NAME=<Folder Name>

# Execute
source <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/master/upload_to_s3.sh)
```