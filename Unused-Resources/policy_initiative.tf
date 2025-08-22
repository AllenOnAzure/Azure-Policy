# Policy Initiative: Cost Optimization for Unused Resources
resource "azurerm_policy_set_definition" "audit_unused_resources_cost_optimization" {
  name         = "Audit-UnusedResourcesCostOptimization"
  policy_type  = "Custom"
  display_name = "Unused resources driving cost should be avoided"
  description  = "Optimize cost by detecting unused but chargeable resources including disks, public IPs, and app service plans."
  metadata = jsonencode({
    version              = "2.1.0"
    category             = "Cost Optimization"
    source               = "https://github.com/Azure/Enterprise-Scale/"
    alzCloudEnvironments = ["AzureCloud"]
  })
  parameters = jsonencode({
    effectDisks = {
      type = "String"
      metadata = {
        displayName = "Disks Effect"
        description = "Enable or disable the execution of the policy for Microsoft.Compute/disks"
      }
      allowedValues = ["Audit", "Disabled"]
      defaultValue  = "Audit"
    }
    effectPublicIpAddresses = {
      type = "String"
      metadata = {
        displayName = "Public IPs Effect"
        description = "Enable or disable the execution of the policy for Microsoft.Network/publicIPAddresses"
      }
      allowedValues = ["Audit", "Disabled"]
      defaultValue  = "Audit"
    }
    effectServerFarms = {
      type = "String"
      metadata = {
        displayName = "App Service Plans Effect"
        description = "Enable or disable the execution of the policy for Microsoft.Web/serverfarms"
      }
      allowedValues = ["Audit", "Disabled"]
      defaultValue  = "Audit"
    }
    effectAzureHybridBenefit = {
      type = "String"
      metadata = {
        displayName = "Azure Hybrid Benefit Effect"
        description = "Enable or disable the execution of the policy for Azure Hybrid Benefit"
      }
      allowedValues = ["Audit", "Disabled"]
      defaultValue  = "Audit"
    }
  })

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.audit_disks_unused_resources_cost_optimization.id
    parameter_values = jsonencode({
      "effect" = {
        "value" = "[parameters('effectDisks')]"
      }
    })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.audit_public_ip_unused_resources_cost_optimization.id
    parameter_values = jsonencode({
      "effect" = {
        "value" = "[parameters('effectPublicIpAddresses')]"
      }
    })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.audit_serverfarms_unused_resources_cost_optimization.id
    parameter_values = jsonencode({
      "effect" = {
        "value" = "[parameters('effectServerFarms')]"
      }
    })
  }

  policy_definition_reference {
    policy_definition_id = azurerm_policy_definition.audit_azure_hybrid_benefit.id
    parameter_values = jsonencode({
      "effect" = {
        "value" = "[parameters('effectAzureHybridBenefit')]"
      }
    })
  }
}