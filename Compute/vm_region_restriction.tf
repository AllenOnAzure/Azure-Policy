# Terraform configuration to restrict VM creation to UK South only
/*
This Terraform script requires the Azure provider to be configured with appropriate credentials.
The policy uses a "deny" effect, which will prevent VM creation in any region other than UK South.
The policy is assigned at the subscription level, affecting all resources within the subscription.
The depends_on clause ensures the policy definition is created before the assignment.
To modify the allowed region, change the "equals": "uksouth" value in the policy rule.
*/

######################## PROVIDER ########################
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

######################## POLICY DEFINITION ########################

# Policy definition to restrict VM creation to UK South only
resource "azurerm_policy_definition" "vm_uk_south_only" {
  name         = "Allowed-VM-UKSouth-Only"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Allowed virtual machine regions - UK South only"
  description  = "Restricts VM deployments to only the UK South region"

  metadata = <<METADATA
    {
      "category": "Compute"
    }
METADATA

  policy_rule = <<POLICY_RULE
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Compute/virtualMachines"
      },
      {
        "not": {
          "field": "location",
          "equals": "uksouth"
        }
      }
    ]
  },
  "then": {
    "effect": "deny"
  }
}
POLICY_RULE
}

######################## POLICY ASSIGNMENT @ SUBSCRIPTION LEVEL ########################

resource "azurerm_subscription_policy_assignment" "vm_uk_south_assignment" {
  name                 = "Allowed-VM-UKSouth-Only"
  policy_definition_id = azurerm_policy_definition.vm_uk_south_only.id
  display_name         = "Allowed-VM-UKSouth-Only"
  description          = "Restricts VM deployments to only the UK South region"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  depends_on = [azurerm_policy_definition.vm_uk_south_only]
}

# Output the policy definition ID
output "policy_definition_id" {
  value = azurerm_policy_definition.vm_uk_south_only.id
}

# Output the policy assignment ID
output "policy_assignment_id" {
  value = azurerm_subscription_policy_assignment.vm_uk_south_assignment.id
}