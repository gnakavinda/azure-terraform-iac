# environments/dev/main.tf
#
# Dev environment — calls all three modules with dev-appropriate sizing.
#
# Authentication:
#   Set ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET
#   (or ARM_USE_OIDC=true) before running terraform plan/apply.
#
# Usage:
#   terraform init -backend-config="backend.conf"
#   terraform plan -var-file="dev.tfvars"
#   terraform apply -var-file="dev.tfvars"

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.1"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.1.0"
    }
  }

  # Backend config values (storage account name etc.) supplied via backend.conf
  # Run: terraform init -backend-config="backend.conf"
  backend "azurerm" {}
}

provider "azurerm" {
  # subscription_id sourced from ARM_SUBSCRIPTION_ID env var
  # This targets the DEV subscription
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true   # OK in dev — makes cleanup easier
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false  # Allow easy teardown in dev
    }
  }
}

# --- Resource Group ---
# All dev resources live in a single resource group
resource "azurerm_resource_group" "dev" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# --- Locals ---
# Common values computed once and reused across all module calls
locals {
  tags = merge(var.tags, {
    environment = var.environment
    managed-by  = "terraform"
  })
}

# --- Module: VNet ---
# Provisions the Virtual Network, subnets, and NSGs
# The AKS subnet ID is passed down to the AKS module below
module "vnet" {
  source = "../../modules/vnet"

  vnet_name           = var.vnet_name
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  address_space       = var.vnet_address_space

  subnets = {
    # AKS nodes and pods get IPs from this subnet (Azure CNI)
    "snet-aks" = {
      cidr              = "10.0.1.0/24"
      service_endpoints = ["Microsoft.KeyVault"]
      nsg_rules = [
        # Allow HTTPS inbound — kubectl access and AKS API communication
        {
          name                       = "allow-https-inbound"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "*"
          destination_address_prefix = "VirtualNetwork"
        },
        # Allow internal VNet traffic — pod to pod, node to node
        {
          name                       = "allow-vnet-inbound"
          priority                   = 200
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        },
        # Allow Azure Load Balancer health probes — required for AKS
        {
          name                       = "allow-load-balancer-inbound"
          priority                   = 300
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "AzureLoadBalancer"
          destination_address_prefix = "*"
        },
        # Deny everything else inbound
        {
          name                       = "deny-all-inbound"
          priority                   = 4096
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        },
        # Allow HTTPS outbound — pulling container images, Azure APIs
        {
          name                       = "allow-https-outbound"
          priority                   = 100
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
        },
        # Allow DNS outbound — name resolution
        {
          name                       = "allow-dns-outbound"
          priority                   = 200
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "Udp"
          source_port_range          = "*"
          destination_port_range     = "53"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
        },
        # Allow internal VNet outbound — pod to pod communication
        {
          name                       = "allow-vnet-outbound"
          priority                   = 300
          direction                  = "Outbound"
          access                     = "Allow"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        }
      ]
    }
  }

  tags = local.tags
}

# --- Module: Key Vault ---
# Provisions Key Vault, locked down to the AKS subnet via service endpoint
module "keyvault" {
  source = "../../modules/keyvault"

  keyvault_name       = var.keyvault_name
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  sku_name            = var.keyvault_sku

  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = false  # Disabled in dev for easy cleanup

  enable_rbac_authorization = true
  network_default_action    = "Deny"

  # Only allow traffic from the AKS subnet
  allowed_subnet_ids = [module.vnet.subnet_ids["snet-aks"]]

  tags = local.tags

  # Key Vault can only be configured after the VNet/subnet exists
  depends_on = [module.vnet]
}

# --- Module: AKS ---
# Provisions the AKS cluster, wired into the VNet subnet above
module "aks" {
  source = "../../modules/aks"

  cluster_name        = var.aks_cluster_name
  location            = azurerm_resource_group.dev.location
  resource_group_name = azurerm_resource_group.dev.name
  environment         = var.environment
  kubernetes_version  = var.kubernetes_version

  # Wire the AKS subnet output from the VNet module directly in
  subnet_id = module.vnet.subnet_ids["snet-aks"]

  # Dev: single node, small VM, no autoscaling
  system_node_count  = var.system_node_count
  system_vm_size     = var.system_vm_size
  enable_autoscaling = var.enable_autoscaling

  enable_azure_rbac      = true
  admin_group_object_ids = var.admin_group_object_ids

  tags = local.tags

  depends_on = [module.vnet]
}
# triggered
