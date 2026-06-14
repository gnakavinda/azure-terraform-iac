# modules/vnet/main.tf
#
# Provisions:
#   - Azure Virtual Network
#   - Subnets (variable count, defined via var.subnets map)
#   - Network Security Groups (one per subnet) with deny-all default + allow rules
#   - NSG associations to subnets

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space

  tags = var.tags
}

# One subnet per entry in var.subnets
resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value.cidr]

  # Delegate to a service (e.g. AKS) if requested
  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_name
        actions = delegation.value.actions
      }
    }
  }

  service_endpoints = lookup(each.value, "service_endpoints", [])
}

# Network Security Group per subnet
resource "azurerm_network_security_group" "this" {
  for_each = var.subnets

  name                = "nsg-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Attach NSG to subnet
resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# NSG rules — one resource per rule per subnet
# We flatten the map-of-lists into a single map keyed by "subnet_name/rule_name"
# so for_each can iterate over every individual rule across all subnets
locals {
  # Example output:
  # {
  #   "snet-aks/allow-https-inbound" = { subnet_name = "snet-aks", rule = { ... } }
  #   "snet-aks/allow-dns-outbound"  = { subnet_name = "snet-aks", rule = { ... } }
  # }
  nsg_rules_flat = merge([
    for subnet_name, subnet in var.subnets : {
      for rule in subnet.nsg_rules :
      "${subnet_name}/${rule.name}" => {
        subnet_name = subnet_name
        rule        = rule
      }
    }
  ]...)
}

resource "azurerm_network_security_rule" "this" {
  for_each = local.nsg_rules_flat

  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.this[each.value.subnet_name].name

  name                       = each.value.rule.name
  priority                   = each.value.rule.priority
  direction                  = each.value.rule.direction
  access                     = each.value.rule.access
  protocol                   = each.value.rule.protocol
  source_port_range          = each.value.rule.source_port_range
  destination_port_range     = each.value.rule.destination_port_range
  source_address_prefix      = each.value.rule.source_address_prefix
  destination_address_prefix = each.value.rule.destination_address_prefix
}
