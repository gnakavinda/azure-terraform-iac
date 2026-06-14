# modules/keyvault/main.tf
#
# Provisions:
#   - Azure Key Vault with soft-delete and purge protection enabled
#   - RBAC-based access (preferred over legacy access policies)
#   - Optional access policies for backwards compatibility
#   - Private endpoint ready (subnet_id optional)

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                = var.keyvault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.sku_name

  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled
  rbac_authorization_enabled = var.enable_rbac_authorization

  network_acls {
    default_action = var.network_default_action
    bypass         = "AzureServices"
    ip_rules                   = var.allowed_ip_ranges
    virtual_network_subnet_ids = var.allowed_subnet_ids
  }

  tags = var.tags
}

# Optional legacy access policies (used when enable_rbac_authorization = false)
resource "azurerm_key_vault_access_policy" "this" {
  for_each = var.enable_rbac_authorization ? {} : { for p in var.access_policies : p.object_id => p }

  key_vault_id = azurerm_key_vault.this.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value.object_id

  key_permissions         = each.value.key_permissions
  secret_permissions      = each.value.secret_permissions
  certificate_permissions = each.value.certificate_permissions
}

# RBAC role assignments (used when enable_rbac_authorization = true)
resource "azurerm_role_assignment" "keyvault" {
  for_each = var.enable_rbac_authorization ? { for r in var.role_assignments : "${r.principal_id}-${r.role}" => r } : {}

  scope                = azurerm_key_vault.this.id
  role_definition_name = each.value.role
  principal_id         = each.value.principal_id
}
