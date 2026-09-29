resource "random_string" "suffix" {
  length  = 5
  upper   = false
  special = false
}

resource "random_password" "admin" {
  length           = 24
  special          = true
  override_special = "!#%*-_"
}

resource "azurerm_private_dns_zone" "this" {
  name                = "${var.name}.private.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  name                  = "link-${var.name}"
  private_dns_zone_name = azurerm_private_dns_zone.this.name
  resource_group_name   = var.resource_group_name
  virtual_network_id    = var.vnet_id
  tags                  = var.tags
}

# VNet-integrated (private access) server: lives in a delegated subnet, no public endpoint.
resource "azurerm_postgresql_flexible_server" "this" {
  name                          = "psql-${var.name}-${random_string.suffix.result}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  version                       = "16"
  sku_name                      = var.sku_name
  storage_mb                    = 32768
  backup_retention_days         = 7
  delegated_subnet_id           = var.subnet_id
  private_dns_zone_id           = azurerm_private_dns_zone.this.id
  public_network_access_enabled = false
  administrator_login           = "pgadmin"
  administrator_password        = random_password.admin.result
  tags                          = var.tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.this]

  lifecycle {
    ignore_changes = [zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "appdb"
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
