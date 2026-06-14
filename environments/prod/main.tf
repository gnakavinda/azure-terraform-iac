# environments/prod/main.tf
#
# Prod environment — same module calls as dev, stricter safety settings,
# larger sizing, and autoscaling enabled.
#
# Authentication:
#   Set ARM_SUBSCRIPTION_ID, ARM_TENANT_ID, ARM_CLIENT_ID
#   and ARM_USE_OIDC=true (recommended) before running terraform plan/apply.
#   Use a SEPARATE service principal scoped only to the prod subscription.
#
# Usage:
#   terraform init -backend-config="backend.conf"
#   terraform plan  -var-file="prod.tfvars"
#   terraform apply -var-file="prod.tfvars"

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

  # Backend config values supplied via backend.conf
  # Run: terraform init -backend-config="backend.conf"
  backend "azurerm" {}
}

provider "azurerm" {
  # subscription_id sourced from ARM_SUBSCRIPTION_ID env var
  # This must target the PROD subscription — never share credentials with dev
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false  # Safety: no accidental permanent deletion in prod
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true  # Hard guard against accidental teardown
    }
  }
}

# --- Resource Group ---
resource "azurerm_resource_group" "prod" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

# --- Resource Lock ---
# Prevents accidental deletion of the prod resource group entirely
resource "azurerm_management_lock" "prod_rg" {
  name       = "lock-${var.resource_group_name}"
  scope      = azurerm_resource_group.prod.id
  lock_level = "CanNotDelete"
  notes      = "Managed by Terraform. Do not delete without updating IaC first."
}

# --- Locals ---
locals {
  tags = merge(var.tags, {
    environment = var.environment
    managed-by  = "terraform"
  })
}

# --- Module: VNet ---
module "vnet" {
  source = "../../modules/vnet"

  vnet_name           = var.vnet_name
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name
  address_space       = var.vnet_address_space

  subnets = {
    # AKS nodes and pods — larger CIDR than dev to support more nodes
    "snet-aks" = {
      cidr              = "10.1.1.0/24"
      service_endpoints = ["Microsoft.KeyVault"]
      nsg_rules = [
        # Allow HTTPS inbound — locked to VNet only in prod (no public kubectl)
        {
          name                       = "allow-https-inbound"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "VirtualNetwork"  # Stricter than dev — VNet only
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
        # Deny everything else inbound — explicit deny-all in prod
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
        },
        # Deny all other outbound in prod — explicit lockdown
        {
          name                       = "deny-all-outbound"
          priority                   = 4096
          direction                  = "Outbound"
          access                     = "Deny"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
    }
    # Dedicated subnet for internal load balancers (best practice in prod)
    "snet-ilb" = {
      cidr      = "10.1.2.0/27"
      nsg_rules = []
    }
  }

  tags = local.tags
}

# --- Module: Key Vault ---
module "keyvault" {
  source = "../../modules/keyvault"

  keyvault_name       = var.keyvault_name
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name
  sku_name            = var.keyvault_sku   # premium in prod — HSM-backed keys

  soft_delete_retention_days = var.soft_delete_retention_days  # 90 days in prod
  purge_protection_enabled   = true   # Cannot be disabled once enabled — intentional in prod

  enable_rbac_authorization = true
  network_default_action    = "Deny"

  allowed_subnet_ids = [module.vnet.subnet_ids["snet-aks"]]

  tags = local.tags

  depends_on = [module.vnet]
}

# --- Module: AKS ---
module "aks" {
  source = "../../modules/aks"

  cluster_name        = var.aks_cluster_name
  location            = azurerm_resource_group.prod.location
  resource_group_name = azurerm_resource_group.prod.name
  environment         = var.environment
  kubernetes_version  = var.kubernetes_version

  subnet_id = module.vnet.subnet_ids["snet-aks"]

  # Prod: multi-node system pool with autoscaling
  system_node_count  = var.system_node_count
  system_vm_size     = var.system_vm_size
  system_min_count   = var.system_min_count
  system_max_count   = var.system_max_count
  enable_autoscaling = var.enable_autoscaling

  # Prod: separate user node pool for application workloads
  create_user_node_pool = var.create_user_node_pool
  user_vm_size          = var.user_vm_size
  user_min_count        = var.user_min_count
  user_max_count        = var.user_max_count

  enable_azure_rbac      = true
  admin_group_object_ids = var.admin_group_object_ids

  # Prod: wire up Container Insights if workspace ID is provided
  log_analytics_workspace_id = var.log_analytics_workspace_id

  tags = local.tags

  depends_on = [module.vnet]
}
