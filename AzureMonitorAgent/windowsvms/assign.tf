# Data sources to reference existing resources
data "azurerm_subscription" "current" {
  subscription_id = var.subscription_id
}

# Assign the built-in policy initiative at subscription level
resource "azurerm_subscription_policy_assignment" "ama_agent_deployment" {
  name                 = "Assign-ama-policy-initiative"
  display_name         = "Assign AMA Policy Initiative"
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/0d1b56c6-6d1f-4a5d-8695-b15efbea6b49"
  subscription_id      = data.azurerm_subscription.current.id
  location             = "UK South"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.ama_uami.id]
  }



  parameters = jsonencode({
    "effect" = {
      "value" : "DeployIfNotExists"
    },

    "dcrResourceId" = {
      "value" = azurerm_monitor_data_collection_rule.ama.id
    },

    "bringYourOwnUserAssignedManagedIdentity" = {
      "value" : true
    },
    "userAssignedManagedIdentityName" = {
      "value" : azurerm_user_assigned_identity.ama_uami.name
    },
    "userAssignedManagedIdentityResourceGroup" = {
      "value" : azurerm_resource_group.ama.name
    }
    "scopeToSupportedImages" = {
      "value" : true
    }
  })
}

# Output the assignment ID
output "policy_assignment_id" {
  value = azurerm_subscription_policy_assignment.ama_agent_deployment.id
}
