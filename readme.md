# azure-terraform-iac

Production ready Azure infrastructure as code using Terraform. A modular, environment-aware, and built for scale.

## Architecture

```
azure-terraform-iac/
├── modules/          # Reusable building blocks (one per Azure resource type)
│   ├── vnet/         # Virtual Network + subnets + NSGs
│   ├── keyvault/     # Key Vault + access policies + RBAC
│   └── aks/          # AKS cluster + node pools + RBAC integration
├── environments/
│   ├── dev/          # Dev tfvars + state config
│   └── prod/         # Prod tfvars + state config (stricter sizing + policies)
├── backend.tf        # Remote state on Azure Storage Account
└── .gitignore
```

## Design Principles

- **Modules over copy-paste** - every resource lives in a versioned, parameterised module
- **Environment parity** - dev and prod call the same modules; only variable values differ
- **Remote state** - Terraform state stored in Azure Blob Storage with state locking via lease
- **Least privilege** - Key Vault access and AKS RBAC scoped to what each identity actually needs
- **No hardcoded secrets** - sensitive values flow through Key Vault or environment variables; never committed

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | >= 1.6 |
| Azure CLI | >= 2.55 |
| kubectl | >= 1.28 (for AKS work) |

## Quick Start

### 1. Bootstrap remote state (one-time)

```bash
# Create the storage account that holds Terraform state
az group create --name rg-tfstate --location australiaeast
az storage account create \
  --name sttfstate<your-suffix> --resource-group rg-tfstate --sku Standard_LRS --allow-blob-public-access false
az storage container create \
  --name tfstate \
  --account-name sttfstate<your-suffix>
```

### 2. Authenticate

```bash
az login
az account set --subscription "<subscription-id>"
```

### 3. Deploy an environment

```bash
cd environments/dev
terraform init
terraform plan -var-file="dev.tfvars"
terraform apply -var-file="dev.tfvars"
```

For prod:

```bash
cd environments/prod
terraform init
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

## Module Reference

### `modules/vnet`

Provisions a Virtual Network with configurable subnets and Network Security Groups.

| Variable | Description | Default |
|----------|-------------|---------|
| `vnet_name` | Name of the VNet | - |
| `location` | Azure region | - |
| `resource_group_name` | Target resource group | - |
| `address_space` | VNet CIDR block | `["10.0.0.0/16"]` |
| `subnets` | Map of subnet name → CIDR | - |

### `modules/keyvault`

Provisions a Key Vault with soft-delete, purge protection, and RBAC-based access.

| Variable | Description | Default |
|----------|-------------|---------|
| `keyvault_name` | Globally unique KV name | - |
| `location` | Azure region | - |
| `resource_group_name` | Target resource group | - |
| `sku_name` | `standard` or `premium` | `standard` |
| `access_policies` | List of object-id + permission sets | `[]` |

### `modules/aks`

Provisions an AKS cluster with a system node pool, optional user node pools, and Azure AD RBAC.

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | AKS cluster name | - |
| `location` | Azure region | - |
| `resource_group_name` | Target resource group | - |
| `kubernetes_version` | K8s version | `1.28` |
| `system_node_count` | Nodes in system pool | `2` |
| `system_vm_size` | VM SKU for system pool | `Standard_D2s_v3` |
| `enable_azure_rbac` | Enable Azure AD RBAC | `true` |

## State Management

State is stored remotely in Azure Blob Storage - never locally and never in Git.

```
Storage Account: sttfstate<suffix>
Container:       tfstate
Key (dev):       dev/terraform.tfstate
Key (prod):      prod/terraform.tfstate
```

State locking is handled automatically via Azure Blob lease - concurrent `apply` runs are safely blocked.

## Environments

| Setting | Dev | Prod |
|---------|-----|------|
| AKS node count | 1 | 3 |
| AKS VM size | Standard_B2s | Standard_D4s_v3 |
| Key Vault SKU | standard | premium |
| Soft delete retention | 7 days | 90 days |
| Resource locks | No | Yes (CanNotDelete) |

## CI/CD (Planned)

- GitHub Actions workflow: `plan` on PR, `apply` on merge to `main`
- Separate service principals per environment with minimal RBAC scope
- `terraform fmt` and `tflint` checks in PR pipeline

## Learning Notes

This repo is a living document - I'm adding to it as I deepen my Terraform and Azure knowledge. Commits track what I learned and when.