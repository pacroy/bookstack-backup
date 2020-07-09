# Bookstack Backup Scripts

Shell scripts to back up and restore Bookstack + MySQL on a Kubernetes cluster.

## Prerequisites

In order to use [backup](backup.sh) and [restore](restore.sh) script, you need:

- `kubectl` with the context of the cluster to backup

## Backup

Create and execute shell script file like this:

```sh
#!/bin/bash
set -e

# Parameters
export KUBE_CONTEXT=<Kubectl Context Name>
export WIKI_NAMSPACE=<Kubernetes Namespace>
export MYSQL_APP_LABEL=<App Label of MySQL>
export BOOKSTACK_APP_LABEL=<App Label of Bookstack>

# Execute
bash -e <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/master/backup.sh)
```

## Restore

Create and execute shell script file like this:

```sh
#!/bin/bash
set -e

# Parameters
export KUBE_CONTEXT=<Kubernetes Context Name>
export WIKI_NAMSPACE=<Bookstack Namespace>
export MYSQL_APP_LABEL=<App Label of MySQL>
export BOOKSTACK_APP_LABEL=<App Label of Bookstack>

# Execute
bash -e <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/master/restore.sh)
```

You can additionally set the following variables if you copyback from one environment to another.

```sh
export HOST_FROM=<wiki.yourdomain.com>
export HOST_TO=<wiki2.yourdomain.com>
```
