# environments/dev/dev.tfvars
#
# Non-sensitive configuration values for the dev environment.
# Safe to commit to Git — no secrets, no subscription IDs.
#
# Usage:
#   terraform plan  -var-file="dev.tfvars"
#   terraform apply -var-file="dev.tfvars"

# --- General ---
location    = "eastus"
environment = "dev"

# --- Resource Group ---
resource_group_name = "rg-dev-eastus"

# --- Networking ---
vnet_name          = "vnet-dev-eastus"
vnet_address_space = ["10.0.0.0/16"]

# --- AKS ---
aks_cluster_name   = "aks-dev-eastus"
kubernetes_version = "1.30"
system_node_count  = 1           # Single node is fine for dev
system_vm_size     = "Standard_B2s"
enable_autoscaling = false

# --- Key Vault ---
keyvault_name              = "kv-dev-eastus-001"   # Must be globally unique
keyvault_sku               = "standard"
soft_delete_retention_days = 7

# --- Tags ---
tags = {
  project     = "azure-terraform-iac"
  owner       = "kavinda"
  cost-center = "dev"
}
