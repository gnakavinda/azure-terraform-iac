# azure-terraform-iac

Production-grade Azure infrastructure as code using Terraform. Modular, environment-aware, and CI/CD driven via GitHub Actions.

## Architecture

```
azure-terraform-iac/
├── modules/
│   ├── vnet/         # Virtual Network + subnets + NSG rules
│   ├── keyvault/     # Key Vault + RBAC + network ACLs
│   └── aks/          # AKS cluster + system/user node pools + Azure AD RBAC
└── environments/
    ├── dev/          # Dev environment — single node, standard SKUs, easy teardown
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── dev.tfvars
    └── prod/         # Prod environment — HA, autoscaling, resource locks, premium SKUs
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── prod.tfvars
```

## Design Principles

- **Modules over copy-paste** — every resource lives in a parameterised, reusable module
- **Environment parity** — dev and prod call the same modules; only variable values differ
- **Remote state** — Terraform state stored in Azure Blob Storage with state locking via blob lease
- **Least privilege** — Key Vault RBAC and AKS Azure AD RBAC scoped to what each identity needs
- **No hardcoded secrets** — credentials flow via `ARM_*` environment variables; never committed to Git
- **Auto-generated names** — Key Vault name derived from subscription ID prefix to guarantee global uniqueness

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | >= 1.6 |
| Azure CLI | >= 2.55 |
| kubectl | >= 1.28 (for AKS work) |

## Quick Start

### 1. Bootstrap remote state (one-time per environment)

```bash
az group create --name rg-tfstate-dev --location eastus

az storage account create --name sttfstatedev<suffix> --resource-group rg-tfstate-dev --sku Standard_LRS --allow-blob-public-access false

az storage container create --name tfstate --account-name sttfstatedev<suffix>
```

### 2. Authenticate

```bash
az login
az account set --subscription "<subscription-id>"

export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"
# PowerShell: $env:ARM_SUBSCRIPTION_ID = "<subscription-id>"
```

### 3. Create backend.conf (gitignored)

```
resource_group_name  = "rg-tfstate-dev"
storage_account_name = "sttfstatedev<suffix>"
container_name       = "tfstate"
key                  = "dev/terraform.tfstate"
```

### 4. Deploy

```bash
cd environments/dev
terraform init -backend-config="backend.conf"
terraform plan  -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

For prod:

```bash
cd environments/prod
terraform init -backend-config="backend.conf"
terraform plan  -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

## Module Reference

### `modules/vnet`

Provisions a Virtual Network with configurable subnets, service endpoints, and per-subnet NSG rules.

| Variable | Description | Default |
|----------|-------------|---------|
| `vnet_name` | Name of the VNet | required |
| `location` | Azure region | required |
| `resource_group_name` | Target resource group | required |
| `address_space` | VNet CIDR block | `["10.0.0.0/16"]` |
| `subnets` | Map of subnet name → cidr, service_endpoints, nsg_rules | required |

NSG rules are defined per subnet in the environment layer — dev and prod can have different rules without changing the module.

### `modules/keyvault`

Provisions a Key Vault with soft-delete, optional purge protection, RBAC-based access, and network ACLs.

| Variable | Description | Default |
|----------|-------------|---------|
| `keyvault_name` | Globally unique KV name | required |
| `location` | Azure region | required |
| `resource_group_name` | Target resource group | required |
| `sku_name` | `standard` or `premium` | `standard` |
| `soft_delete_retention_days` | Retention window (7–90) | `7` |
| `purge_protection_enabled` | Prevent permanent deletion | `false` |
| `enable_rbac_authorization` | Use RBAC over access policies | `true` |
| `allowed_subnet_ids` | Subnets allowed through network ACL | `[]` |

### `modules/aks`

Provisions an AKS cluster with system and optional user node pools, Azure CNI networking, and Azure AD RBAC.

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | AKS cluster name | required |
| `location` | Azure region | required |
| `resource_group_name` | Target resource group | required |
| `kubernetes_version` | K8s version | `1.35.5` |
| `system_node_count` | Nodes in system pool | `1` |
| `system_vm_size` | VM SKU for system pool | `Standard_D2s_v3` |
| `enable_autoscaling` | Enable cluster autoscaler | `false` |
| `create_user_node_pool` | Add a separate user node pool | `false` |
| `enable_azure_rbac` | Enable Azure AD RBAC | `true` |
| `subnet_id` | Subnet for Azure CNI | required |

## Environments

| Setting | Dev | Prod |
|---------|-----|------|
| AKS node count | 1 | 3 |
| AKS VM size | Standard_D2s_v3 | Standard_D4s_v3 |
| Autoscaling | No | Yes (3–10 nodes) |
| User node pool | No | Yes |
| Key Vault SKU | standard | premium |
| Soft delete retention | 7 days | 90 days |
| Purge protection | No | Yes |
| Resource locks | No | Yes (CanNotDelete) |
| NSG outbound deny-all | No | Yes |

## State Management

State is stored remotely in Azure Blob Storage — never locally, never in Git.

```
Container:    tfstate
Key (dev):    dev/terraform.tfstate
Key (prod):   prod/terraform.tfstate
```

State locking is handled automatically via Azure Blob lease — concurrent `apply` runs are safely blocked.

## CI/CD

GitHub Actions workflows trigger on changes to `environments/dev/**` or `modules/**`.

| Event | Dev | Prod |
|-------|-----|------|
| Pull Request | `terraform plan` → posted as PR comment | `terraform plan` → posted as PR comment |
| Merge to `main` | `terraform apply` (automatic) | — |
| Push to `prod` branch | — | `terraform apply` (requires manual approval) |

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `ARM_CLIENT_ID` | Service principal app ID |
| `ARM_CLIENT_SECRET` | Service principal password |
| `ARM_TENANT_ID` | Azure tenant ID |
| `ARM_SUBSCRIPTION_ID_DEV` | Dev subscription ID |
| `ARM_SUBSCRIPTION_ID_PROD` | Prod subscription ID |
| `BACKEND_STORAGE_ACCOUNT_DEV` | Dev tfstate storage account name |
| `BACKEND_STORAGE_ACCOUNT_PROD` | Prod tfstate storage account name |

Prod apply is gated behind a GitHub Environment (`production`) with required reviewers — no one can deploy to prod without manual approval.

## Outputs

After `terraform apply`, the following values are available via `terraform output`:

| Output | Description |
|--------|-------------|
| `aks_cluster_name` | Use with `az aks get-credentials` |
| `aks_cluster_id` | Full resource ID of the AKS cluster |
| `aks_node_resource_group` | Auto-generated RG for AKS node VMs |
| `aks_identity_principal_id` | Managed identity for role assignments |
| `aks_kube_config` | Kubeconfig (sensitive) |
| `keyvault_uri` | Key Vault URI for app configuration |
| `keyvault_id` | Full resource ID of the Key Vault |
| `vnet_id` | Full resource ID of the VNet |
| `subnet_ids` | Map of subnet name → subnet ID |
| `resource_group_name` | Name of the environment resource group |
