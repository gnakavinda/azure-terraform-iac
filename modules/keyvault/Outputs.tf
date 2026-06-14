# modules/keyvault/outputs.tf

output "keyvault_id" {
  description = "Resource ID of the Key Vault."
  value       = azurerm_key_vault.this.id
}

output "keyvault_name" {
  description = "Name of the Key Vault."
  value       = azurerm_key_vault.this.name
}

output "keyvault_uri" {
  description = "URI for accessing the Key Vault (used by apps and SDKs)."
  value       = azurerm_key_vault.this.vault_uri
}

output "vault_uri" {
  description = "Alias for keyvault_uri."
  value       = azurerm_key_vault.this.vault_uri
}
