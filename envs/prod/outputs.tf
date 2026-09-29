output "hub_resource_group" { value = azurerm_resource_group.hub.name }
output "bastion_name" { value = try(module.bastion[0].name, null) }
output "firewall_private_ip" { value = try(module.firewall[0].private_ip, null) }
output "vm_ids" { value = { for k, m in module.workload_vm : k => m.id } }
output "database_fqdns" { value = { for k, m in module.database : k => m.fqdn } }
output "database_admin_password" {
  value     = { for k, m in module.database : k => m.admin_password }
  sensitive = true
}
