################## PROVIDER ############################################################
# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}

################################## RESOURCES ##########################################

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

##################   POLICY DEFINITION TAG   ###########################################

resource "azurerm_policy_definition" "require_environment_tag" {
  name         = "Enforces a required tag and its value on resource groups"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Enforces a required tag and its value on resource groups"
  description  = "Enforces resource groups with 'environment' tag with allowed values"
  metadata = jsonencode({
    version  = "1.0.0"
    category = "Tags"
  })

  parameters = jsonencode({
    allowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the environment tag"
      }
      defaultValue = ["dev", "test", "prod"]
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Resources/subscriptions/resourceGroups"
        },
        {
          not = {
            field = "tags['environment']"
            in    = "[parameters('allowedValues')]"
          }
        }
      ]
    }
    then = {
      effect = "deny"
    }
  })
}

#################### POLICY ASSIGNMENT ########################################

resource "azurerm_subscription_policy_assignment" "assignment" {
  name                 = "Enforces a required tag and its value on resource groups"
  policy_definition_id = azurerm_policy_definition.require_environment_tag.id
  subscription_id      = "/subscriptions/${var.subscription_id}"

  parameters = jsonencode({
    allowedValues = {
      value = ["dev", "test", "prod"]
    }
  })
}