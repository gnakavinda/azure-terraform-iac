# modules/aks/main.tf
#
# Provisions:
#   - AKS cluster with system node pool
#   - Optional user node pool (for workload separation from system pods)
#   - Azure AD + Azure RBAC integration
#   - Managed identity (no service principal rotation headaches)
#   - Azure CNI networking (integrates with existing VNet subnets)
#   - Azure Monitor + Container Insights (optional)

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix != null ? var.dns_prefix : var.cluster_name
  kubernetes_version  = var.kubernetes_version

  # System node pool — runs kube-system workloads
  # Kept separate from user workloads via node taints (managed by AKS)
  default_node_pool {
    name                = "system"
    node_count          = var.system_node_count
    vm_size             = var.system_vm_size
    vnet_subnet_id      = var.subnet_id
    os_disk_size_gb     = 50
    type                = "VirtualMachineScaleSets"  # Required for autoscaler
    auto_scaling_enabled = var.enable_autoscaling
    min_count           = var.enable_autoscaling ? var.system_min_count : null
    max_count           = var.enable_autoscaling ? var.system_max_count : null

    node_labels = {
      "nodepool-type" = "system"
      "environment"   = var.environment
    }
  }

  # Use managed identity — no client secret to rotate
  identity {
    type = "SystemAssigned"
  }

  # Azure CNI: pods get IPs from the VNet subnet (required for KV, ACR, Storage access)
  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"     # Azure Network Policy Manager
    load_balancer_sku  = "standard"
    outbound_type      = "loadBalancer"
    service_cidr       = var.service_cidr
    dns_service_ip     = var.dns_service_ip
  }

  # Azure AD + Azure RBAC: use role assignments to control cluster access
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = var.enable_azure_rbac
    admin_group_object_ids = var.admin_group_object_ids
  }

  # Optional: Log Analytics / Container Insights
  dynamic "oms_agent" {
    for_each = var.log_analytics_workspace_id != null ? [1] : []
    content {
      log_analytics_workspace_id = var.log_analytics_workspace_id
    }
  }

  tags = var.tags
}

# Optional user node pool — for application workloads
# Keeping system and user pools separate avoids resource contention
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count = var.create_user_node_pool ? 1 : 0

  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.this.id
  vm_size               = var.user_vm_size
  node_count            = var.user_node_count
  vnet_subnet_id        = var.subnet_id
  os_disk_size_gb       = 128
  auto_scaling_enabled   = var.enable_autoscaling
  min_count             = var.enable_autoscaling ? var.user_min_count : null
  max_count             = var.enable_autoscaling ? var.user_max_count : null
  mode                  = "User"

  node_labels = {
    "nodepool-type" = "user"
    "environment"   = var.environment
  }

  # Taint the system pool to repel user workloads (AKS does this automatically for system pools)
  # User pods without explicit tolerations land here
  tags = var.tags
}
