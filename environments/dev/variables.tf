# environments/dev/variables.tf
#
# All inputs for the dev environment.
# Values are supplied via dev.tfvars at plan/apply time.
# Sensitive values (subscription_id, tenant_id) come from ARM_* env vars — not tfvars.

variable "location" {
  description = "Azure region for all dev resources."
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment label applied to resource names and tags."
  type        = string
  default     = "dev"
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
  default     = ["10.0.0.0/16"]
}

# --- AKS ---

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster."
  type        = string
  default     = "1.30"
}

variable "system_node_count" {
  description = "Number of nodes in the system node pool."
  type        = number
  default     = 1
}

variable "system_vm_size" {
  description = "VM SKU for system pool nodes."
  type        = string
  default     = "Standard_B2s"
}

variable "enable_autoscaling" {
  description = "Enable cluster autoscaler on node pools."
  type        = bool
  default     = false
}

variable "admin_group_object_ids" {
  description = "Azure AD group object IDs granted cluster-admin access."
  type        = list(string)
  default     = []
}

# --- Key Vault ---

variable "keyvault_sku" {
  description = "Key Vault SKU — standard for dev, premium for prod."
  type        = string
  default     = "standard"
}

variable "soft_delete_retention_days" {
  description = "Days to retain a deleted Key Vault. Min 7, max 90."
  type        = number
  default     = 7  # Short retention in dev to keep things easy to clean up
}

# --- Tags ---

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
# trigger
# trigger
# updated
