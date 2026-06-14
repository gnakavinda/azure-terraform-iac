# modules/keyvault/variables.tf

variable "keyvault_name" {
  description = "Globally unique name for the Key Vault (3-24 alphanumeric chars and hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]{3,24}$", var.keyvault_name))
    error_message = "Key Vault name must be 3-24 characters, alphanumeric and hyphens only."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group to deploy into."
  type        = string
}

variable "sku_name" {
  description = "Key Vault SKU: 'standard' or 'premium' (premium supports HSM-backed keys)."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.sku_name)
    error_message = "sku_name must be 'standard' or 'premium'."
  }
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain a deleted Key Vault before permanent removal. Min 7, max 90."
  type        = number
  default     = 90

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days must be between 7 and 90."
  }
}

variable "purge_protection_enabled" {
  description = "Enable purge protection — prevents permanent deletion during retention window. Recommended for prod."
  type        = bool
  default     = true
}

variable "enable_rbac_authorization" {
  description = "Use Azure RBAC for access control (recommended). Set false to use legacy access policies."
  type        = bool
  default     = true
}

variable "network_default_action" {
  description = "Default network action: 'Allow' (open) or 'Deny' (allowlist only). Use 'Deny' in prod."
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.network_default_action)
    error_message = "network_default_action must be 'Allow' or 'Deny'."
  }
}

variable "allowed_ip_ranges" {
  description = "List of IP ranges (CIDR) allowed through the Key Vault firewall."
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "List of subnet resource IDs allowed to access Key Vault via service endpoint."
  type        = list(string)
  default     = []
}

# Used when enable_rbac_authorization = false
variable "access_policies" {
  description = "Legacy access policies. Only used when enable_rbac_authorization = false."
  type = list(object({
    object_id               = string
    key_permissions         = optional(list(string), [])
    secret_permissions      = optional(list(string), [])
    certificate_permissions = optional(list(string), [])
  }))
  default = []
}

# Used when enable_rbac_authorization = true
variable "role_assignments" {
  description = "RBAC role assignments on the Key Vault. Used when enable_rbac_authorization = true."
  type = list(object({
    principal_id = string
    role         = string  # e.g. "Key Vault Secrets User", "Key Vault Administrator"
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
