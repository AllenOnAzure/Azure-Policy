################## PROVIDER ########################################
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

################################## RESOURCES ######################

variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

##################   POLICY DEFINITION TAG   ##################

resource "azurerm_policy_definition" "require_environment_tag" {
  name         = "Resource-Groups-require-environment-tag"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Require environment tag on resource groups"
  description  = "Enforces resource groups with 'environment' tag with allowed values."
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
