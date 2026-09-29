output "fqdn" { value = azurerm_postgresql_flexible_server.this.fqdn }
output "name" { value = azurerm_postgresql_flexible_server.this.name }
output "admin_username" { value = azurerm_postgresql_flexible_server.this.administrator_login }
output "admin_password" {
  value     = random_password.admin.result
  sensitive = true
}
