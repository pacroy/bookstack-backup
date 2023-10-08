# Bookstack Backup & Restore

This repository contians bash scripts and GitHub Actions workflows to backup and restore Bookstack nad its MySQL deployed on a [Microk8s cluster](https://github.com/pacroy/microk8s-azure-vm) using [this Helm chart](https://github.com/pacroy/bookstack-helm).

## CLI Usages

### CLI Usage Prerequisites

1. Make sure [kubectl](https://kubernetes.io/docs/tasks/tools/) is installed, the current context is configured, and it can connect to the cluster successfully.
2. The following environment variables are set:

    ```bash
    export KUBE_CONTEXT="microk8s"
    export WIKI_NAMESPACE="wiki"
    export MYSQL_APP_LABEL="release-mysql"
    export BOOKSTACK_APP_LABEL="release-bookstack"
    ```

### CLI Usage - Backup

Execute the script.

```bash
source <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/main/backup.sh)
```

### CLI Usage - Restore

If you copyback from one environment to another, you can additionally set the following variables to update all links.

```sh
export HOST_FROM="wiki.yourdomain.com"
export HOST_TO="wiki2.yourdomain.com"
```

Execute the script.

```bash
bash -e <(curl -s https://raw.githubusercontent.com/pacroy/bookstack-backup/main/restore.sh)
```

## GitHub Actions Usages

### GitHub Actions Prerequisites

1. Create AzureAD application, if you don't already have one.
2. Grant the application so it can access storage account.
3. [Configure OIDC federated credential](https://learn.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Clinux) in your application to allow GitHub Actions to acess your Azure environment.
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
| KUBE_CONTEXT          | Kubeconfig contexts.context.name                                  |
| KUBE_USER_TOKEN       | Kubeconfig users.user.token                                       |
| MYSQL_APP_LABEL       | MySQL pod label e.g. `release-mysql`                              |
| SENDGRID_API_KEY      | SendGrid API Key for sending email notification                   |
| SENDGRID_RECIPIENTS   | Recipient email address(es), separated by semicolon               |
| SENDGRID_SENDER       | Verified sender email address                                     |
| STORAGE_ACCOUNT_NAME  | Azure storage account name for storing backup files               |
| WIKI_NAMESPACE        | Kubernetes namespace containing bookstack release                 |

3. The `Backup` workflow is configured to run every Sunday's 0:00. You can also manually run it at anytime you want.

# GitHub Actions Usages - Restore

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
| KUBE_CONTEXT          | Kubeconfig contexts.context.name                                      |
| KUBE_USER_TOKEN       | Kubeconfig users.user.token                                           |
| MYSQL_APP_LABEL       | MySQL pod label e.g. `release-mysql`                                  |
| STORAGE_ACCOUNT_NAME  | Azure storage account name for downloading backup files               |
| WIKI_NAMESPACE        | Kubernetes namespace containing bookstack release                     |
| UPDATE_HOST_FROM      | *Optional.* Domain to search in the URLs.                             |
| UPDATE_HOST_TO        | *Optional.* Domain to replace in the URLs.                            |

3. Run the workflow `Restore` and input backup date e.g. `20231008` and environment name to restore.
