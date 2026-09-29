locals {
  prefix = "${var.project}-${var.environment}"
  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

# ---------------- Resource groups ----------------
resource "azurerm_resource_group" "hub" {
  name     = "rg-${local.prefix}-hub"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "spoke" {
  for_each = var.spokes
  name     = "rg-${local.prefix}-${each.key}"
  location = var.location
  tags     = local.tags
}

# ---------------- Hub ----------------
module "monitoring" {
  source              = "../../modules/monitoring"
  name                = local.prefix
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  tags                = local.tags
}

module "hub" {
  source                 = "../../modules/hub-network"
  name                   = local.prefix
  location               = var.location
  resource_group_name    = azurerm_resource_group.hub.name
  address_space          = var.hub.address_space
  firewall_subnet_prefix = var.hub.firewall_subnet_prefix
  bastion_subnet_prefix  = var.hub.bastion_subnet_prefix
  tags                   = local.tags
}

module "firewall" {
  count                      = var.enable_firewall ? 1 : 0
  source                     = "../../modules/firewall"
  name                       = local.prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.hub.name
  subnet_id                  = module.hub.firewall_subnet_id
  log_analytics_workspace_id = module.monitoring.workspace_id
  spoke_address_spaces       = flatten([for s in var.spokes : s.address_space])
  allowed_fqdns              = var.firewall_allowed_fqdns
  tags                       = local.tags
}

module "bastion" {
  count                      = var.enable_bastion ? 1 : 0
  source                     = "../../modules/bastion"
  name                       = local.prefix
  location                   = var.location
  resource_group_name        = azurerm_resource_group.hub.name
  subnet_id                  = module.hub.bastion_subnet_id
  log_analytics_workspace_id = module.monitoring.workspace_id
  tags                       = local.tags
}

# ---------------- Spokes ----------------
module "spoke" {
  for_each                   = var.spokes
  source                     = "../../modules/spoke-network"
  name                       = "${local.prefix}-${each.key}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.spoke[each.key].name
  address_space              = each.value.address_space
  subnets                    = each.value.subnets
  nsg_rules                  = each.value.nsg_rules
  hub_vnet_id                = module.hub.vnet_id
  hub_vnet_name              = module.hub.vnet_name
  hub_resource_group_name    = azurerm_resource_group.hub.name
  route_via_firewall_enabled = var.enable_firewall
  firewall_private_ip        = var.enable_firewall ? module.firewall[0].private_ip : null
  tags                       = local.tags
}

module "workload_vm" {
  for_each            = { for k, v in var.spokes : k => v if v.deploy_workload }
  source              = "../../modules/workload-vm"
  name                = "${local.prefix}-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke[each.key].name
  subnet_id           = module.spoke[each.key].subnet_ids["app"]
  ssh_public_key      = var.ssh_public_key
  tags                = local.tags
}

module "database" {
  for_each            = { for k, v in var.spokes : k => v if v.deploy_database }
  source              = "../../modules/postgres"
  name                = "${var.project}-${each.key}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke[each.key].name
  subnet_id           = module.spoke[each.key].subnet_ids["data"]
  vnet_id             = module.spoke[each.key].vnet_id
  tags                = local.tags
}

# ---------------- Governance ----------------
module "policy" {
  source          = "../../modules/policy"
  subscription_id = var.subscription_id
  enforce         = var.enforce_policies

  policies = {
    "no-nic-public-ip" = {
      display_name = "Network interfaces should not have public IPs"
    }
    "allowed-locations" = {
      display_name = "Allowed locations"
      parameters   = jsonencode({ listOfAllowedLocations = { value = [var.location] } })
    }
    "pg-no-public-access" = {
      display_name = "Public network access should be disabled for PostgreSQL flexible servers"
    }
    "subnet-requires-nsg" = {
      display_name = "Subnets should be associated with a Network Security Group"
    }
  }
}
