
#################### PROVIDER ####################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75"
    }
  }

  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}
}
##################### VARIABLES #####################
variable "subscription_id" {
  description = "The ID of the Azure subscription to apply the policy to (just the GUID, not the full path)."
  type        = string
}
##################### RESOURCES #####################
resource "azurerm_policy_definition" "hotpatch_enabled" {
  name         = "Hotpatch should be enabled for Windows Server Azure Edition VMs"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Hotpatch should be enabled for Windows Server Azure Edition VMs"
  description  = "Minimize reboots and install updates quickly with hotpatch. Learn more at https://docs.microsoft.com/azure/automanage/automanage-hotpatch"
  metadata = jsonencode({
    version  = "1.0.0"
    category = "Automanage"
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/virtualMachines"
        },
        {
          field = "Microsoft.Compute/virtualMachines/storageProfile.imageReference.sku"
          in = [
            "2022-datacenter-azure-edition",
            "2022-datacenter-azure-edition-core",
            "2022-datacenter-azure-edition-core-smalldisk",
            "2022-datacenter-azure-edition-smalldisk"
          ]
        },
        {
          not = {
            field  = "Microsoft.Compute/virtualMachines/osProfile.windowsConfiguration.patchSettings.enableHotpatching"
            equals = "true"
          }
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}
#################### POLICY ASSIGNMENT ####################

resource "azurerm_subscription_policy_assignment" "assignment" {
  name                 = "Hotpatch should be enabled for Windows Server Azure Edition VMs"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/6d02d2f7-e38b-4bdc-96f3-adc0a8726abc"
  subscription_id      = "/subscriptions/${var.subscription_id}"

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}
############################################################