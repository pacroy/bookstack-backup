# Bookstack Backup & Restore

This repository contains bash scripts and GitHub Actions workflows to back up and restore BookStack and MySQL deployed on a [MicroK8s cluster](https://github.com/pacroy/microk8s-azure-vm) using [this Helm chart](https://github.com/pacroy/bookstack-helm).

## CLI Usages

### CLI Usage Prerequisites

1. Make sure [kubectl](https://kubernetes.io/docs/tasks/tools/) is installed, the current context is configured, and it can connect to the cluster successfully.
2. The following environment variables are set:

    ```bash
    export KUBE_CONTEXT="microk8s"
    export WIKI_NAMESPACE="wiki"
    export MYSQL_APP_LABEL="release-mysql"
    export BOOKSTACK_APP_LABEL="release-bookstack"
    export MYSQL_PASSWORD="secret" # optional when not using the chart default
    ```

3. Run the scripts from the repository root. The backup script writes these files into `./backup/`:

    ```text
    backup/bookstack.tgz
    backup/uploads.tgz
    backup/storage.tgz
    ```

### CLI Usage - Backup

Execute the script.

```bash
bash -e <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/main/backup.sh)
```

Add `-y` to skip the confirmation prompt.

```bash
bash -e <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/main/backup.sh) -y
```

The backup script exports non-system MySQL databases only so dumps from MySQL 5.7 can be restored safely into MySQL 8.4.

### CLI Usage - Restore

Make sure the backup files exist locally under `./backup/` before restoring.

If you are restoring into a different environment, you can additionally set the following variables to update links inside the SQL dump.

```sh
export HOST_FROM="wiki.yourdomain.com"
export HOST_TO="wiki2.yourdomain.com"
```

Execute the script.

```bash
bash -e <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/main/restore.sh)
```

Add `-y` to skip the confirmation prompt.

```bash
bash -e <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/main/restore.sh) -y
```

## GitHub Actions Usages

### GitHub Actions Prerequisites

1. Create AzureAD application, if you don't already have one.
2. Grant the application so it can access storage account.
3. [Configure OIDC federated credential](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Clinux) in your application to allow GitHub Actions to access your Azure environment.
4. Fork or clone this repository into yours.

### GitHub Actions Usages - Backup

1. Go to your repository settings and create a new environment `production`.
2. Add the following environment secrets:

| Name                  | Description                                                       |
| --------------------- | ----------------------------------------------------------------- |
| AZURE_CLIENT_ID       | AzureAD application client ID                                     |
| AZURE_SUBSCRIPTION_ID | Azure subscription ID                                             |
| AZURE_TENANT_ID       | Azure tenant ID                                                   |
| BLOB_CONTAINER_NAME   | Blob container name within Azure storage for storing backup files |
| BOOKSTACK_APP_LABEL   | Bookstack pod label e.g. `release-bookstack`                      |
| KUBE_API_SERVER       | Kubeconfig clusters.cluster.server                                |
| KUBE_CA_BASE64        | Kubeconfig clusters.cluster.certificate-authority-data            |
| KUBE_CLIENT_CERT      | *Optional.* Base64 client certificate when not using token auth   |
| KUBE_CLIENT_KEY       | *Optional.* Base64 client key when not using token auth           |
| KUBE_CONTEXT          | Kubeconfig contexts.context.name                                  |
| KUBE_USER_TOKEN       | *Optional.* Kubeconfig users.user.token                           |
| MYSQL_APP_LABEL       | MySQL pod label e.g. `release-mysql`                              |
| SENDGRID_API_KEY      | SendGrid API Key for sending email notification                   |
| SENDGRID_RECIPIENTS   | Recipient email address(es), separated by semicolon               |
| SENDGRID_SENDER       | Verified sender email address                                     |
| STORAGE_ACCOUNT_NAME  | Azure storage account name for storing backup files               |
| WIKI_NAMESPACE        | Kubernetes namespace containing bookstack release                 |

Use either `KUBE_USER_TOKEN`, or `KUBE_CLIENT_CERT` together with `KUBE_CLIENT_KEY`.

1. The `Backup` workflow is configured to run every Sunday at 00:00 UTC. You can also run it manually and optionally set `is_dry_run` to skip uploading blobs.

### GitHub Actions Usages - Restore

1. Go to your repository settings and create a new environment you want to restore to.
2. Add the following environment secrets:

| Name                  | Description                                                           |
| --------------------- | --------------------------------------------------------------------- |
| AZURE_CLIENT_ID       | AzureAD application client ID                                         |
| AZURE_SUBSCRIPTION_ID | Azure subscription ID                                                 |
| AZURE_TENANT_ID       | Azure tenant ID                                                       |
| BLOB_CONTAINER_NAME   | Blob container name within Azure storage for downloading backup files |
| BOOKSTACK_APP_LABEL   | Bookstack pod label e.g. `release-bookstack`                          |
| KUBE_API_SERVER       | Kubeconfig clusters.cluster.server                                    |
| KUBE_CA_BASE64        | Kubeconfig clusters.cluster.certificate-authority-data                |
| KUBE_CLIENT_CERT      | *Optional.* Base64 client certificate when not using token auth       |
| KUBE_CLIENT_KEY       | *Optional.* Base64 client key when not using token auth               |
| KUBE_CONTEXT          | Kubeconfig contexts.context.name                                      |
| KUBE_USER_TOKEN       | *Optional.* Kubeconfig users.user.token                               |
| MYSQL_APP_LABEL       | MySQL pod label e.g. `release-mysql`                                  |
| STORAGE_ACCOUNT_NAME  | Azure storage account name for downloading backup files               |
| WIKI_NAMESPACE        | Kubernetes namespace containing bookstack release                     |
| UPDATE_HOST_FROM      | *Optional.* Domain to search in the URLs.                             |
| UPDATE_HOST_TO        | *Optional.* Domain to replace in the URLs.                            |

Use either `KUBE_USER_TOKEN`, or `KUBE_CLIENT_CERT` together with `KUBE_CLIENT_KEY`.

1. Run the workflow `Restore`, provide a backup date such as `20231008`, and select the target environment.
