output "private_ip" { value = azurerm_firewall.this.ip_configuration[0].private_ip_address }
output "id" { value = azurerm_firewall.this.id }
