# modules/vnet/variables.tf

variable "vnet_name" {
  description = "Name of the Virtual Network."
  type        = string
}

variable "location" {
  description = "Azure region for all resources in this module."
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into."
  type        = string
}

variable "address_space" {
  description = "CIDR block(s) for the Virtual Network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnets" {
  description = <<-EOT
    Map of subnet configurations. Key = subnet name.
    Each entry:
      cidr              - (required) CIDR for the subnet
      service_endpoints - (optional) list of service endpoints, e.g. ["Microsoft.KeyVault"]
      delegation        - (optional) object with { name, service_name, actions }
      nsg_rules         - (optional) list of NSG rules to apply to this subnet's NSG
  EOT
  type = map(object({
    cidr              = string
    service_endpoints = optional(list(string), [])
    delegation = optional(object({
      name         = string
      service_name = string
      actions      = list(string)
    }), null)
    nsg_rules = optional(list(object({
      name                       = string
      priority                   = number
      direction                  = string # "Inbound" or "Outbound"
      access                     = string # "Allow" or "Deny"
      protocol                   = string # "Tcp", "Udp", "*"
      source_port_range          = string
      destination_port_range     = string
      source_address_prefix      = string
      destination_address_prefix = string
    })), [])
  }))
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}
