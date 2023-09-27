# Bookstack Backup & Restore

This repository contians bash scripts and GitHub Actions workflows to backup and restore Bookstack nad its MySQL deployed on a [Microk8s cluster](https://github.com/pacroy/microk8s-azure-vm) using [this Helm chart](https://github.com/pacroy/bookstack-helm).

## CLI Usages

### Prerequisites

1. Make sure [kubectl](https://kubernetes.io/docs/tasks/tools/) is installed, the current context is configured, and it can connect to the cluster successfully.
2. The following environment variables are set:

    ```bash
    export KUBE_CONTEXT="microk8s"
    export WIKI_NAMSPACE="wiki"
    export MYSQL_APP_LABEL="release-mysql"
    export BOOKSTACK_APP_LABEL="release-bookstack"
    ```

### Backup

Execute the script.

```bash
source <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/main/backup.sh)
```

### Restore

If you copyback from one environment to another, you can additionally set the following variables to update all links.

```sh
export HOST_FROM="wiki.yourdomain.com"
export HOST_TO="wiki2.yourdomain.com"
```

Execute the script.

```bash
bash -e <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/main/restore.sh)
```
