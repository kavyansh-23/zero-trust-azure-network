resource "azurerm_public_ip" "this" {
  name                = "pip-${var.name}-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# Standard SKU: native-client tunneling (az network bastion ssh/tunnel) and peered-VNet reach.
resource "azurerm_bastion_host" "this" {
  name                   = "bas-${var.name}"
  location               = var.location
  resource_group_name    = var.resource_group_name
  sku                    = "Standard"
  tunneling_enabled      = true
  copy_paste_enabled     = true
  file_copy_enabled      = false
  ip_connect_enabled     = false
  shareable_link_enabled = false
  tags                   = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = var.subnet_id
    public_ip_address_id = azurerm_public_ip.this.id
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "diag-bastion"
  target_resource_id         = azurerm_bastion_host.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}
