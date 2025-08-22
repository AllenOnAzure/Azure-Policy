##################### PROVIDER #####################
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

##################### DATA #####################

# Get current subscription details
data "azurerm_subscription" "current" {}

##################### VARIABLES #################

variable "resource_group_name" {
  description = "The name of the resource group to use."
  type        = string
}

variable "subscription_id" {
  description = "The ID of the Azure subscription to apply the policy to (just the GUID, not the full path)."
  type        = string
}

variable "location" {
  description = "The Azure region where resources will be deployed."
  type        = string
}

##################### RESOURCES #####################
# Optional: Resource group for context
resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name
  location = var.location
  
  tags = {
    # Required tags
    Environment     = "example" # Should match your policy's expected tag name
    CreatedBy       = "terraform"
    CreationDate    = formatdate("YYYY-MM-DD", timestamp())
	Environment		= "Subscription-01"
    
    # Optional descriptive tags
    Project         = "azure-policy-demo"
    Owner           = "allens"
    CostCenter      = "IT-123"
    Department      = "Cloud-Engineering"
    
    # Compliance tags
    Compliance      = "internal"
    DataClassification = "public"
    
    # Operational tags
    AutoShutdown    = "false"
    BackupEnabled   = "true"
    Criticality     = "low"
  }
  
  # Lifecycle policy to prevent accidental deletion
  lifecycle {
    prevent_destroy = false # Set to true in production to prevent accidental deletion
  }
}

# Azure Policy Definition
resource "azurerm_policy_definition" "inherit_tag_from_rg" {
  name         = "Allens-Inherit a tag from the resource group if missing"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Allens-Inherit a tag from the resource group if missing"
  description  = "Adds the specified tag with its value from the parent resource group when any resource missing this tag is created or updated. Existing resources can be remediated by triggering a remediation task. If the tag exists with a different value it will not be changed."

  metadata = jsonencode({
    version  = "1.0.0"
    category = "Tags"
  })

  parameters = jsonencode({
    tagName = {
      type = "String"
      metadata = {
        displayName = "Tag Name"
        description = "Name of the tag, such as 'environment'"
      }
    }
  })

  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "[concat('tags[', parameters('tagName'), ']')]"
          exists = "false"
        },
        {
          value     = "[resourceGroup().tags[parameters('tagName')]]"
          notEquals = ""
        }
      ]
    }
    then = {
      effect = "modify"
      details = {
        roleDefinitionIds = [
          "/providers/microsoft.authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
        ]
        operations = [
          {
            operation = "add"
            field     = "[concat('tags[', parameters('tagName'), ']')]"
            value     = "[resourceGroup().tags[parameters('tagName')]]"
          }
        ]
      }
    }
  })
}

# Policy Assignment using azurerm_subscription_policy_assignment
resource "azurerm_subscription_policy_assignment" "assign_inherit_tag" {
  name                 = "Allens-Assign-Inherit-tag-from-rg"
  display_name         = "Allens-Inherit tag from resource group"
  description          = "Assigns the policy to inherit tags from resource group"
  subscription_id      = "/subscriptions/${var.subscription_id}" # Fixed: Added the full path
  policy_definition_id = azurerm_policy_definition.inherit_tag_from_rg.id
  location             = var.location

  parameters = jsonencode({
    tagName = {
      value = "environment"
    }
  })

  identity {
    type = "SystemAssigned"
  }
}

# Output the policy assignment ID for potential manual remediation
output "policy_assignment_id" {
  description = "The ID of the policy assignment for manual remediation"
  value       = azurerm_subscription_policy_assignment.assign_inherit_tag.id
}

# Output the subscription ID in the correct format for reference
output "subscription_id_full_path" {
  description = "The subscription ID in the full Azure Resource Manager format"
  value       = "/subscriptions/${var.subscription_id}"
}