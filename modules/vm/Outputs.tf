# modules/vnet/outputs.tf

output "vm_id" {
  description = "Resource ID of the Virtual Machine."
  value       = azurerm_virtual_machine.this.id
}

output "vm_name" {
  description = "Name of the Virtual Machine."
  value       = azurerm_virtual_machine.this.name
}
