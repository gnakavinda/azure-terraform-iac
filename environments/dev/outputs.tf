# environments/dev/outputs.tf
#
# Useful values exposed after terraform apply.
# View them with: terraform output
# View a specific one: terraform output aks_cluster_name

# --- Resource Group ---

output "resource_group_name" {
  description = "Name of the dev resource group."
  value       = azurerm_resource_group.dev.name
}

# --- Networking ---

output "vnet_id" {
  description = "Resource ID of the dev Virtual Network."
  value       = module.vnet.vnet_id
}

output "subnet_ids" {
  description = "Map of subnet name → subnet ID."
  value       = module.vnet.subnet_ids
}

# --- AKS ---

output "aks_cluster_name" {
  description = "Name of the AKS cluster. Use with: az aks get-credentials --name <value> --resource-group <rg>"
  value       = module.aks.cluster_name
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = module.aks.cluster_id
}

output "aks_node_resource_group" {
  description = "Auto-generated resource group where AKS puts node VMs, disks, and NICs."
  value       = module.aks.node_resource_group
}

output "aks_kube_config" {
  description = "Kubeconfig to connect kubectl to the cluster. Marked sensitive — use: terraform output -raw aks_kube_config"
  value       = module.aks.kube_config
  sensitive   = true
}

output "aks_identity_principal_id" {
  description = "Principal ID of the AKS managed identity. Used for role assignments (e.g. ACR pull, Key Vault access)."
  value       = module.aks.identity_principal_id
}

# --- Key Vault ---

output "keyvault_uri" {
  description = "URI of the Key Vault. Use this in app config to reference secrets."
  value       = module.keyvault.vault_uri
}

output "keyvault_id" {
  description = "Resource ID of the Key Vault."
  value       = module.keyvault.keyvault_id
}
