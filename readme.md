# azure-terraform-iac

Production-grade Azure infrastructure as code using Terraform. Modular, environment-aware, and CI/CD driven via GitHub Actions.

## Overview

This project provisions a complete AKS-based platform on Azure using reusable Terraform modules. The same modules are used for both dev and prod environments — only the variable values differ. All deployments are driven through GitHub Actions pipelines; no one runs `terraform apply` manually.

## Architecture

```
azure-terraform-iac/
├── modules/
│   ├── vnet/         # Virtual Network + subnets + per-subnet NSG rules
│   ├── keyvault/     # Key Vault + RBAC + network ACLs
│   └── aks/          # AKS cluster + system/user node pools + Azure AD RBAC
└── environments/
    ├── dev/          # Dev environment configuration
    │   ├── main.tf       # Calls all three modules, wires outputs between them
    │   ├── variables.tf  # Input declarations
    │   ├── outputs.tf    # Exposes useful values after apply
    │   ├── dev.tfvars    # Non-sensitive config values (committed to Git)
    │   └── backend.conf  # Remote state config (gitignored — never commit)
    └── prod/         # Prod environment configuration (same structure as dev)
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── prod.tfvars
        └── backend.conf
```

## Design Principles

- **Modules over copy-paste** — every resource lives in a parameterised, reusable module. Dev and prod call the same modules with different inputs.
- **Environment parity** — the same code path runs in dev and prod. If it works in dev, it will work in prod.
- **Remote state** — Terraform state stored in Azure Blob Storage with state locking via blob lease. Never stored locally or in Git.
- **No hardcoded secrets** — credentials flow via `ARM_*` environment variables injected by GitHub Actions secrets. Never in code or tfvars.
- **GitOps** — the pipeline is the only thing that runs `terraform apply`. No manual deployments.
- **Least privilege** — Key Vault uses RBAC, AKS uses Azure AD RBAC. Service principal scoped to Contributor only.

---

## Branch Strategy

```
feature/* → developer → main → prod
```

| Branch | Purpose | Deploys to |
|--------|---------|------------|
| `feature/*` | Individual changes | Nothing |
| `developer` | Integration branch | Nothing (plan only) |
| `main` | Dev source of truth | Azure dev environment |
| `prod` | Prod source of truth | Azure prod environment |

### How changes flow

1. Create a feature branch from `developer`, make your changes
2. Merge feature branch back into `developer`
3. Open a Pull Request from `developer` → `main`
4. Pipeline runs `terraform plan` and posts output as a PR comment
5. Review the plan — confirm what will change in Azure
6. Merge the PR → pipeline runs `terraform apply` → dev deploys
7. Test in dev
8. When ready for prod:
   ```bash
   git checkout prod
   git merge main
   git push origin prod
   ```
9. Prod pipeline triggers → manual approval required → prod deploys

**Rule: code only flows forward. Never merge prod back into main.**

---

## CI/CD Pipelines

### Dev pipeline (`.github/workflows/terraform-dev.yml`)

Triggers on changes to `environments/dev/**` or `modules/**`.

| Event | Steps |
|-------|-------|
| Push to `developer` | fmt → validate → plan (visible in Actions tab) |
| Pull Request to `main` | fmt → validate → plan → post plan as PR comment |
| Merge to `main` | fmt → validate → plan → apply (automatic) |

### Prod pipeline (`.github/workflows/terraform-prod.yml`)

Triggers on push to `prod` branch touching `environments/prod/**` or `modules/**`.

| Step | Description |
|------|-------------|
| Plan job | fmt → validate → plan |
| Apply job | Waits for manual approval in GitHub `production` environment → apply |

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.6 | [terraform.io](https://developer.hashicorp.com/terraform/install) |
| Azure CLI | >= 2.55 | [learn.microsoft.com](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) |
| kubectl | >= 1.28 | For AKS access after deploy |
| Git | Any | [git-scm.com](https://git-scm.com) |

---

## First-Time Setup

### 1. Clone the repo

```bash
git clone https://github.com/gnakavinda/azure-terraform-iac.git
cd azure-terraform-iac
```

### 2. Bootstrap remote state storage (one-time per environment)

```bash
# Dev state storage
az group create --name rg-tfstate-dev --location eastus
az storage account create --name <unique-name-dev> --resource-group rg-tfstate-dev --sku Standard_LRS --allow-blob-public-access false
az storage container create --name tfstate --account-name <unique-name-dev>

# Prod state storage
az group create --name rg-tfstate-prod --location eastus
az storage account create --name <unique-name-prod> --resource-group rg-tfstate-prod --sku Standard_LRS --allow-blob-public-access false
az storage container create --name tfstate --account-name <unique-name-prod>
```

### 3. Create a service principal

```bash
az ad sp create-for-rbac \
  --name "sp-terraform-cicd" \
  --role Contributor \
  --scopes /subscriptions/<subscription-id>
```

Save the output — you need `appId`, `password`, and `tenant`.

### 4. Add GitHub secrets

Go to **repo Settings → Secrets and variables → Actions** and add:

| Secret | Value |
|--------|-------|
| `ARM_CLIENT_ID` | Service principal `appId` |
| `ARM_CLIENT_SECRET` | Service principal `password` |
| `ARM_TENANT_ID` | Azure tenant ID |
| `ARM_SUBSCRIPTION_ID_DEV` | Dev subscription ID |
| `ARM_SUBSCRIPTION_ID_PROD` | Prod subscription ID |
| `BACKEND_STORAGE_ACCOUNT_DEV` | Dev tfstate storage account name |
| `BACKEND_STORAGE_ACCOUNT_PROD` | Prod tfstate storage account name |

### 5. Create the production GitHub Environment

Go to **repo Settings → Environments → New environment** → name it `production` → add required reviewers.

### 6. Create backend.conf files (gitignored — never commit)

`environments/dev/backend.conf`:
```
resource_group_name  = "rg-tfstate-dev"
storage_account_name = "<your-dev-storage-account>"
container_name       = "tfstate"
key                  = "dev/terraform.tfstate"
```

`environments/prod/backend.conf`:
```
resource_group_name  = "rg-tfstate-prod"
storage_account_name = "<your-prod-storage-account>"
container_name       = "tfstate"
key                  = "prod/terraform.tfstate"
```

### 7. Initialise each environment

```bash
cd environments/dev
terraform init -backend-config="backend.conf"

cd ../prod
terraform init -backend-config="backend.conf"
```

---

## Running Locally

Set credentials via environment variables before running any Terraform commands:

```bash
# Linux/macOS
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_CLIENT_ID="<sp-app-id>"
export ARM_CLIENT_SECRET="<sp-password>"

# Windows PowerShell
$env:ARM_SUBSCRIPTION_ID = "<subscription-id>"
$env:ARM_TENANT_ID = "<tenant-id>"
$env:ARM_CLIENT_ID = "<sp-app-id>"
$env:ARM_CLIENT_SECRET = "<sp-password>"
```

Then from the environment directory:

```bash
cd environments/dev
terraform init    -backend-config="backend.conf"
terraform validate
terraform plan    -var-file="dev.tfvars"
terraform apply   -var-file="dev.tfvars"

# Always destroy after testing to avoid cost
terraform destroy -var-file="dev.tfvars"
```

---

## Module Reference

### `modules/vnet`

Provisions a Virtual Network with configurable subnets and per-subnet NSG rules. NSG rules are defined in the environment layer so dev and prod can have different security postures without changing the module.

**Key outputs:** `vnet_id`, `subnet_ids`

### `modules/keyvault`

Provisions a Key Vault with soft-delete, optional purge protection, RBAC-based access, and network ACLs locked to specific subnets.

**Key outputs:** `keyvault_id`, `keyvault_uri`

### `modules/aks`

Provisions an AKS cluster with a system node pool, optional user node pool, Azure CNI networking, and Azure AD RBAC. Uses SystemAssigned managed identity — no service principal rotation needed.

**Key outputs:** `cluster_id`, `cluster_name`, `kube_config`, `identity_principal_id`, `node_resource_group`

---

## Environment Comparison

| Setting | Dev | Prod |
|---------|-----|------|
| AKS node count | 1 | 3 |
| AKS VM size | Standard_D2s_v3 | Standard_D2s_v3 |
| Autoscaling | No | Yes (3–10 nodes) |
| Key Vault SKU | standard | premium |
| Soft delete retention | 7 days | 90 days |
| Purge protection | No | Yes |
| Resource group lock | No | Yes (CanNotDelete) |
| NSG outbound deny-all | No | Yes |
| NSG inbound HTTPS | Allow from `*` | Allow from VNet only |
| Purge on destroy | Yes (easy cleanup) | No (safety) |
| Prevent RG deletion | No | Yes |

---

## Outputs

After `terraform apply`, run `terraform output` to see:

| Output | Description |
|--------|-------------|
| `aks_cluster_name` | Use with `az aks get-credentials` |
| `aks_cluster_id` | Full resource ID of the AKS cluster |
| `aks_node_resource_group` | Auto-generated RG for AKS node VMs |
| `aks_identity_principal_id` | Managed identity for downstream role assignments |
| `aks_kube_config` | Kubeconfig (sensitive — use `terraform output -raw aks_kube_config`) |
| `keyvault_uri` | Key Vault URI for app configuration |
| `keyvault_id` | Full resource ID of the Key Vault |
| `vnet_id` | Full resource ID of the VNet |
| `subnet_ids` | Map of subnet name → subnet resource ID |
| `resource_group_name` | Name of the environment resource group |

### Connecting kubectl after deploy

```bash
az aks get-credentials \
  --name $(terraform output -raw aks_cluster_name) \
  --resource-group $(terraform output -raw resource_group_name)

kubectl get nodes
```

---

## State Management

State is stored remotely in Azure Blob Storage — never locally, never in Git.

```
Dev:  <storage-account>/tfstate/dev/terraform.tfstate
Prod: <storage-account>/tfstate/prod/terraform.tfstate
```

State locking via Azure Blob lease prevents concurrent apply conflicts. If a lock gets stuck after a cancelled pipeline run:

```bash
terraform force-unlock <lock-id>
```

---

## Security Notes

- Service principal credentials stored only in GitHub secrets — never in code
- `backend.conf` is gitignored — contains storage account names
- `.terraform/` is gitignored — contains provider binaries (only `.terraform.lock.hcl` is committed)
- Key Vault network ACL defaults to `Deny` — only the AKS subnet is whitelisted
- AKS access is via Azure AD RBAC only
- Prod resource group has a `CanNotDelete` management lock

---

## Cost Awareness

Always destroy resources after testing — they incur costs while running.

| Resource | Approx/month |
|----------|-------------|
| AKS control plane (Free tier) | $0.00 |
| Standard_D2s_v3 node | ~$70 |
| Load Balancer (auto-created) | ~$18 |
| Key Vault (low usage) | ~$1–2 |
| **Dev total (1 node)** | **~$90** |
| **Prod total (3 nodes)** | **~$240** |

```bash
terraform destroy -var-file="dev.tfvars"
```

---

## Troubleshooting

**`SubscriptionNotFound`**
```bash
az account set --subscription "<subscription-id>"
```

**`AuthorizationFailed` on role assignments**
Your account needs `Owner` role, not just `Contributor`. Assign via Azure Portal → Subscriptions → Access Control (IAM).

**`K8sVersionNotSupported`**
Check available versions and update `kubernetes_version` in tfvars:
```bash
az aks get-versions --location eastus --output table
```

**`VaultAlreadyExists`**
A vault with that name is in soft-delete state. Purge it or use a different name:
```bash
az keyvault purge --name <vault-name> --location eastus
```

**State lock stuck**
```bash
terraform force-unlock <lock-id>
```

**Apply fails after partial create**
Destroy the partial resources first, then re-run:
```bash
terraform destroy -var-file="dev.tfvars"
```

---

## AzureRM 4.x Migration Notes

Several attributes were renamed when upgrading from AzureRM 3.x to 4.x:

| Old name | New name | Resource |
|----------|----------|----------|
| `enable_auto_scaling` | `auto_scaling_enabled` | `azurerm_kubernetes_cluster` node pool |
| `managed = true` | removed entirely | `azure_active_directory_role_based_access_control` |
| `enable_rbac_authorization` | `rbac_authorization_enabled` (deprecated warning, removed in 5.0) | `azurerm_key_vault` |
| `bypass = ["AzureServices"]` | `bypass = "AzureServices"` | Key Vault `network_acls` block |

Always check the provider docs for your pinned version rather than relying on older blog posts or examples.
