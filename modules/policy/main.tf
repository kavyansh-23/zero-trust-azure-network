data "azurerm_policy_definition" "this" {
  for_each     = var.policies
  display_name = each.value.display_name
}

resource "azurerm_subscription_policy_assignment" "this" {
  for_each             = var.policies
  name                 = each.key
  display_name         = each.value.display_name
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = data.azurerm_policy_definition.this[each.key].id
  enforce              = var.enforce
  parameters           = each.value.parameters
}
