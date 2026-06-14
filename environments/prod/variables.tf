# environments/prod/variables.tf
#
# All inputs for the prod environment.
# Values are supplied via prod.tfvars at plan/apply time.
# Sensitive values (subscription_id, tenant_id) come from ARM_* env vars — not tfvars.

variable "location" {
  description = "Azure region for all prod resources."
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment label applied to resource names and tags."
  type        = string
  default     = "prod"
}

# --- Naming ---

variable "vnet_name" {
  description = "Name of the Virtual Network."
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "keyvault_name" {
  description = "Globally unique name for the Key Vault (3-24 alphanumeric and hyphens)."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group all resources will be deployed into."
  type        = string
}

# --- Networking ---

variable "vnet_address_space" {
  description = "CIDR block for the Virtual Network."
  type        = list(string)
  default     = ["10.1.0.0/16"]  # Separate address space from dev to allow future VNet peering
}

# --- AKS ---

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster."
  type        = string
  default     = "1.30"
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool (when autoscaling is disabled)."
  type        = number
  default     = 3
}

variable "system_vm_size" {
  description = "VM SKU for system pool nodes."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_min_count" {
  description = "Minimum node count for system pool autoscaler."
  type        = number
  default     = 3
}

variable "system_max_count" {
  description = "Maximum node count for system pool autoscaler."
  type        = number
  default     = 5
}

variable "enable_autoscaling" {
  description = "Enable cluster autoscaler on node pools."
  type        = bool
  default     = true
}

variable "create_user_node_pool" {
  description = "Whether to create a separate user node pool for application workloads."
  type        = bool
  default     = true
}

variable "user_vm_size" {
  description = "VM SKU for user pool nodes."
  type        = string
  default     = "Standard_D4s_v3"
}

variable "user_min_count" {
  description = "Minimum node count for user pool autoscaler."
  type        = number
  default     = 2
}

variable "user_max_count" {
  description = "Maximum node count for user pool autoscaler."
  type        = number
  default     = 10
}

variable "admin_group_object_ids" {
  description = "Azure AD group object IDs granted cluster-admin access."
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  description = "Resource ID of Log Analytics workspace for Container Insights. Required in prod."
  type        = string
  default     = null
}

# --- Key Vault ---

variable "keyvault_sku" {
  description = "Key Vault SKU — standard for dev, premium for prod."
  type        = string
  default     = "premium"  # HSM-backed keys in prod
}

variable "soft_delete_retention_days" {
  description = "Days to retain a deleted Key Vault. Min 7, max 90."
  type        = number
  default     = 90  # Maximum retention in prod
}

# --- Tags ---

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
