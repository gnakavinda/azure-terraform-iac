# environments/prod/prod.tfvars
#
# Non-sensitive configuration values for the prod environment.
# Safe to commit to Git — no secrets, no subscription IDs.
#
# Usage:
#   terraform plan  -var-file="prod.tfvars"
#   terraform apply -var-file="prod.tfvars"

# --- General ---
location    = "eastus"
environment = "prod"

# --- Resource Group ---
resource_group_name = "rg-prod-eastus"

# --- Networking ---
vnet_name          = "vnet-prod-eastus"
vnet_address_space = ["10.1.0.0/16"]  # Separate from dev (10.0.0.0/16) — allows future peering

# --- AKS ---
aks_cluster_name   = "aks-prod-eastus"
kubernetes_version = "1.35.5"

# System pool — HA across 3 nodes minimum
system_node_count = 3
system_vm_size    = "Standard_D2s_v3"
system_min_count  = 3
system_max_count  = 5

# Autoscaling on in prod
enable_autoscaling = true

# Separate user node pool for application workloads
create_user_node_pool = true
user_vm_size          = "Standard_D4s_v3"
user_min_count        = 2
user_max_count        = 10

# --- Key Vault ---
keyvault_name              = "kv-prod-eastus-001"  # Must be globally unique
keyvault_sku               = "premium"
soft_delete_retention_days = 90

# --- Tags ---
tags = {
  project     = "azure-terraform-iac"
  owner       = "kavinda"
  cost-center = "prod"
}
