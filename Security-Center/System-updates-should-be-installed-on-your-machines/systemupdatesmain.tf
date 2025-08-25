#################### PROVIDER ####################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.75" # Updated to a version that supports policy assignments
    }
  }

  required_version = ">= 1.3.0"
}

provider "azurerm" {
  features {}
}

##################### VARIABLES #####################

variable "resource_group_name" {
  description = "The name of the resource group to use."
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
}

variable "subscription_id" {
  description = "The ID of the Azure subscription to apply the policy to (just the GUID, not the full path)."
  type        = string
}

##################### DATA SOURCE #####################

# Retrieves current subscription info
data "azurerm_subscription" "current" {}

#################### POLICY DEFINITION ####################

resource "azurerm_policy_definition" "system_updates_required" {
  name         = "System updates should be installed on your machines"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "System updates should be installed on your machines (powered by Update Center)"
  description  = "Your machines are missing system, security, and critical updates. Software updates often include critical patches to security holes. Such holes are frequently exploited in malware attacks so it's vital to keep your software updated. To install all outstanding patches and secure your machines, follow the remediation steps."

  metadata = jsonencode({
    version  = "1.0.1"
    category = "Security Center"
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
      allowedValues = [
        "AuditIfNotExists",
        "Disabled"
      ]
      defaultValue = "AuditIfNotExists"
    }
  })

  policy_rule = jsonencode({
    if = {
      field = "type"
      in = [
        "Microsoft.Compute/virtualMachines",
        "Microsoft.HybridCompute/machines"
      ]
    }
    then = {
      effect = "[parameters('effect')]"
      details = {
        type = "Microsoft.Security/assessments"
        name = "e1145ab1-eb4f-43d8-911b-36ddf771d13f"
        existenceCondition = {
          field = "Microsoft.Security/assessments/status.code"
          in = [
            "NotApplicable",
            "Healthy"
          ]
        }
      }
    }
  })
}

#################### POLICY ASSIGNMENT ####################

resource "azurerm_subscription_policy_assignment" "assign_system_updates_required" {
  name                 = "System updates should be installed on your machines"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/f85bf3e0-d513-442e-89c3-1784ad63382b"
  subscription_id      = "/subscriptions/${var.subscription_id}"

  parameters = jsonencode({
    effect = {
      value = "AuditIfNotExists"
    }
  })
}