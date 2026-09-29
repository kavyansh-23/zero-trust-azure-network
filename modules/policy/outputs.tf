output "assignment_ids" { value = { for k, a in azurerm_subscription_policy_assignment.this : k => a.id } }
