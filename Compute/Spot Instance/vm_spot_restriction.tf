# Terraform configuration to enforce Spot Instances on all VMs
/*
This Terraform script creates a policy that DENY'S VMs not using Spot instances.
The policy is assigned at the subscription level and affects all resources within the subscription.
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
resource "azurerm_policy_definition" "force_spot_instances" {
  name         = "Force-Spot-Instances"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Allen - Force Spot Instances on all virtual machines in this subscription"
  description  = "Audits virtual machines that are not configured to use Spot instances"

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
        "field": "Microsoft.Compute/virtualMachines/priority",
        "notEquals": "Spot"
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
resource "azurerm_subscription_policy_assignment" "force_spot_instances_assignment" {
  name                 = "Force-Spot-Instances"
  policy_definition_id = azurerm_policy_definition.force_spot_instances.id
  display_name         = "Allen - Force Spot Instances on all virtual machines in this subscription"
  description          = "Audits virtual machines that are not configured to use Spot instances"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  depends_on           = [azurerm_policy_definition.force_spot_instances]
}

# Output the policy definition ID
output "policy_definition_id" {
  value = azurerm_policy_definition.force_spot_instances.id
}

# Output the policy assignment ID
output "policy_assignment_id" {
  value = azurerm_subscription_policy_assignment.force_spot_instances_assignment.id
}