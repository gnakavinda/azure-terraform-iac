# modules/vm/variables.tf

variable "vm_name" {
  description = "Name of the Virtual Machine."
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

variable "subnet_id" {
  description = "ID of the subnet the VM's NIC will be placed into."
  type        = string
}

variable "vm_size" {
  description = "VM SKU, e.g. Standard_DS1_v2."
  type        = string
  default     = "Standard_DS1_v2"
}

variable "admin_username" {
  description = "Admin username for the VM's OS."
  type        = string
}

variable "admin_password" {
  description = "Admin password for the VM's OS."
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to all resources."
  type        = map(string)
  default     = {}
}