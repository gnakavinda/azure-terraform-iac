# modules/aks/variables.tf

variable "cluster_name" {
  description = "Name of the AKS cluster."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "environment" {
  description = "Environment label (dev/staging/prod). Applied as a node label."
  type        = string
}

variable "dns_prefix" {
  description = "DNS prefix for the cluster API server. Defaults to cluster_name if null."
  type        = string
  default     = null
}

variable "kubernetes_version" {
  description = "Kubernetes version to use. Check 'az aks get-versions' for available versions."
  type        = string
  default     = "1.28"
}

variable "subnet_id" {
  description = "Subnet resource ID for Azure CNI — nodes and pods get IPs from this subnet."
  type        = string
}

# --- System node pool ---

variable "system_node_count" {
  description = "Number of nodes in the system pool (when autoscaling is disabled)."
  type        = number
  default     = 2
}

variable "system_vm_size" {
  description = "VM SKU for system pool nodes."
  type        = string
  default     = "Standard_D2s_v3"
}

variable "system_min_count" {
  description = "Minimum node count for system pool autoscaler."
  type        = number
  default     = 1
}

variable "system_max_count" {
  description = "Maximum node count for system pool autoscaler."
  type        = number
  default     = 3
}

# --- User node pool ---

variable "create_user_node_pool" {
  description = "Whether to create a separate user node pool for application workloads."
  type        = bool
  default     = false
}

variable "user_node_count" {
  description = "Number of nodes in the user pool."
  type        = number
  default     = 2
}

variable "user_vm_size" {
  description = "VM SKU for user pool nodes."
  type        = string
  default     = "Standard_D4s_v3"
}

variable "user_min_count" {
  description = "Minimum node count for user pool autoscaler."
  type        = number
  default     = 1
}

variable "user_max_count" {
  description = "Maximum node count for user pool autoscaler."
  type        = number
  default     = 5
}

# --- Autoscaling ---

variable "enable_autoscaling" {
  description = "Enable cluster autoscaler on node pools."
  type        = bool
  default     = false
}

# --- Networking ---

variable "service_cidr" {
  description = "CIDR for Kubernetes services. Must not overlap with VNet address space."
  type        = string
  default     = "10.100.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for the Kubernetes DNS service. Must be within service_cidr."
  type        = string
  default     = "10.100.0.10"
}

# --- RBAC ---

variable "enable_azure_rbac" {
  description = "Enable Azure RBAC for Kubernetes authorisation (recommended over local accounts)."
  type        = bool
  default     = true
}

variable "admin_group_object_ids" {
  description = "List of Azure AD group object IDs granted cluster-admin via Azure RBAC."
  type        = list(string)
  default     = []
}

# --- Monitoring ---

variable "log_analytics_workspace_id" {
  description = "Resource ID of Log Analytics workspace for Container Insights. Null disables monitoring."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
