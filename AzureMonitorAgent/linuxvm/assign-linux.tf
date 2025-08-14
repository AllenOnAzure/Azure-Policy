# Data sources to reference existing resources
data "azurerm_subscription" "current" {
  subscription_id = var.subscription_id
}

# Assign the Linux AMA policy initiative at subscription level
resource "azurerm_subscription_policy_assignment" "linux_ama_agent_deployment" {
  name                 = "LINUX-Assign-Linux-Azure-Monitor-Agent"
  display_name         = "Deploy Linux Azure Monitor Agent with user-assigned managed identity-based auth and associate with Data Collection Rule"
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/babf8e94-780b-4b4d-abaa-4830136a8725" # Linux policy set definition ID
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
      "value" : azurerm_monitor_data_collection_rule.ama_linux.id # Reference to Linux DCR
    },
    "bringYourOwnUserAssignedManagedIdentity" = {
      "value" : true
    },
    "userAssignedManagedIdentityName" = {
      "value" : azurerm_user_assigned_identity.ama_uami.name
    },
    "userAssignedManagedIdentityResourceGroup" = {
      "value" : azurerm_resource_group.ama.name
    },
    "scopeToSupportedImages" = {
      "value" : true
    },
    "builtInIdentityResourceGroupLocation" = {
      "value" : "uksouth" # Match your default location
    }
  })
}

# Output the assignment ID
output "linux_policy_assignment_id" {
  value = azurerm_subscription_policy_assignment.linux_ama_agent_deployment.id
}