resource "azurerm_public_ip" "this" {
  name                = "pip-${var.name}-fw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  name                     = "afwp-${var.name}"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  sku                      = "Standard"
  threat_intelligence_mode = "Deny"
  tags                     = var.tags

  dns {
    proxy_enabled = true
  }
}

# Everything not explicitly allowed here is denied by the firewall (default deny).
resource "azurerm_firewall_policy_rule_collection_group" "baseline" {
  name               = "rcg-baseline"
  firewall_policy_id = azurerm_firewall_policy.this.id
  priority           = 200

  application_rule_collection {
    name     = "allow-egress-fqdns"
    priority = 200
    action   = "Allow"

    rule {
      name              = "allowed-fqdns"
      source_addresses  = var.spoke_address_spaces
      destination_fqdns = var.allowed_fqdns

      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }
  }
}

resource "azurerm_firewall" "this" {
  name                = "afw-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this.id
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.this.id
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "diag-firewall"
  target_resource_id             = azurerm_firewall.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "AllMetrics"
  }
}
