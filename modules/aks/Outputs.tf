# modules/aks/outputs.tf

output "cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.id
}

output "cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.name
}

output "kube_config" {
  description = "kubeconfig for connecting to the cluster (admin). Handle as sensitive."
  value       = azurerm_kubernetes_cluster.this.kube_config_raw
  sensitive   = true
}

output "kubelet_identity" {
  description = "Managed identity used by kubelet (useful for granting ACR pull, KV access, etc)."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
}

output "cluster_principal_id" {
  description = "Principal ID of the cluster's system-assigned managed identity."
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "identity_principal_id" {
  description = "Alias for cluster_principal_id — principal ID of the AKS managed identity."
  value       = azurerm_kubernetes_cluster.this.identity[0].principal_id
}

output "node_resource_group" {
  description = "Auto-generated resource group where AKS places node VMs, disks, and NICs."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}
