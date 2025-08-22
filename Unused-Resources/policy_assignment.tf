

####################### ASSIGN INITIATIVE ######################################
# Assign the custom policy initiative at subscription level using a system assigned managed identity

resource "azurerm_subscription_policy_assignment" "cost_optimization" {
  name         = "Cost-Optimization-Unused-Resources"
  display_name = "Cost Optimization: Audit Unused Resources"
  # Use your custom initiative instead of the built-in one
  policy_definition_id = azurerm_policy_set_definition.audit_unused_resources_cost_optimization.id
  subscription_id      = "/subscriptions/${var.subscription_id}"
  location             = var.location

  # No identity needed since your custom policies use "Audit" effect only
  # identity {
  #   type = "SystemAssigned"
  # }

  parameters = jsonencode({
    effectDisks = {
      value = "Audit"
    },
    effectPublicIpAddresses = {
      value = "Audit"
    },
    effectServerFarms = {
      value = "Audit"
    },
    effectAzureHybridBenefit = {
      value = "Audit"
    }
  })
}