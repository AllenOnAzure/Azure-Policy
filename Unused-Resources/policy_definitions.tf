
####################### Azure Provider #############################

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "<subscriptionID>"
}

########################## VARIABLES ##############################
# variables.tf - Variable definitions for cost optimization policies

variable "subscription_id" {
  description = "The Azure subscription ID"
  type        = string
  default     = "<subscriptionID>"
}


variable "location" {
  description = "The Azure region for resources"
  type        = string
  default     = "UK South"
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "orphan-costmonitoring-rg"
}

variable "user_assigned_identity_name" {
  description = "The name of the user assigned managed identity"
  type        = string
  default     = "orphaned-cost-policy-uami"
}

variable "user_assigned_identity_rg" {
  description = "The resource group for user assigned managed identity"
  type        = string
  default     = "orphan-costmonitoring-rg"
}

variable "webhook_url" {
  description = "The webhook URL for policy event notifications and Event Grid integration"
  type        = string
  default     = "https://defaultddd1fcab.1f.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/564a41f9b/triggers/manual/paths/invoke/?api-version=1&sp=%2FtrOu5eHibJ4"
}


# Optional: Microsoft Teams URL
variable "teams_webhook_url" {
  description = "The Microsoft Teams webhook URL for notifications"
  type        = string
  default     = "https://defaultddd1fcab.1f.environment.api.powerplatform.com:443/powerautomate/automations/direct/workflows/564a41f9b/triggers/manual/paths/invoke/?api-version=1&sp=%2FtrOu5eHibJ4
}

variable "slack_webhook_url" {
  description = "The Slack webhook URL for notifications"
  type        = string
  default     = ""
}

variable "log_analytis_workspace" {
  description = "Log Analytics workspace configuration"
  type        = any
  default     = null
}

variable "data_collection_rule" {
  description = "Data Collection Rule configuration"
  type        = any
  default     = null
}

variable "azurerm_log_analytics_workspace" {
  description = "Log Analytics workspace resource"
  type        = any
  default     = null
}

########################## RESOURCES ##############################
####### Create Resource Group
resource "azurerm_resource_group" "monitoring" {
  name     = var.resource_group_name
  location = var.location
}

###### Create log analytics workspace 
resource "azurerm_log_analytics_workspace" "unusedresourcescostoptimization" {
  name                = "unusedresourcescostoptimization"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = var.location
  # location            = data.azurerm_resource_group.cost_monitoring.location
  # resource_group_name = data.azurerm_resource_group.cost_monitoring.name

  sku               = "PerGB2018"
  retention_in_days = 30
  tags = {
    purpose = "cost optimization"
    type    = "unused resources"
  }
}

/*
###### Create Logic App Workflow for Unused Resources Cost Optimization  
resource "azurerm_logic_app_workflow" "unusedresourcescostoptimization" {
  name                = "unusedresourcescostoptimization"
  resource_group_name = azurerm_resource_group.monitoring.name
  location            = var.location
  #  location            = data.azurerm_resource_group.cost_monitoring.location
  #  resource_group_name = data.azurerm_resource_group.cost_monitoring.name
  tags = {
    purpose = "cost optimization"
    type    = "unused resources"
  }
}

*/
###### Create User Assigned Managed Identity
resource "azurerm_user_assigned_identity" "uami1" {
  name                = var.user_assigned_identity_name
  resource_group_name = var.resource_group_name
  location            = var.location
}

###### List of roles to assign
locals {
  roles = [
    "Contributor",
    #"User Access Administrator",
    #"Monitoring Contributor",
    #"Virtual Machine Contributor",
    #"Monitoring Metrics Publisher",
    #"Log Analytics Contributor"
  ]
}

###### Assign each role to the UAMI at the subscription scope
resource "azurerm_role_assignment" "uami_roles" {
  for_each             = toset(local.roles)
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = each.key
  principal_id         = azurerm_user_assigned_identity.uami1.principal_id
}


########################## POLICY DIAGNOSTIC SETTINGS ##############################

# Send subscription-level policy compliance logs to Log Analytics
resource "azurerm_monitor_diagnostic_setting" "subscription_policy_logs" {
  name                       = "subscription-policy-logs"
  target_resource_id         = "/subscriptions/${var.subscription_id}" # Target the subscription
  log_analytics_workspace_id = azurerm_log_analytics_workspace.unusedresourcescostoptimization.id

  enabled_log {
    category = "Policy" # Captures policy compliance state changes
  }

  enabled_log {
    category = "Administrative" # Captures policy assignment/definition operations
  }

  # Optional: Enable Azure Policy metrics
  enabled_metric {
    category = "AllMetrics"
  }
}

################## POLICY DEFINITION : AUDIT DISKS #############################

# Policy Definition: Audit Unattached Disks
resource "azurerm_policy_definition" "audit_disks_unused_resources_cost_optimization" {
  name         = "Audit-Disks-UnusedResourcesCostOptimization"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Audit unused disks for cost optimization"
  description  = "Audits Microsoft.Compute/disks that are not attached to any virtual machine and may be incurring unnecessary costs."
  metadata = jsonencode({
    category = "Cost Optimization"
    version  = "1.0.0"
  })
  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Disabled"]
      defaultValue  = "Audit"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
    }
  })
  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Compute/disks"
        },
        {
          field  = "Microsoft.Compute/disks/diskState"
          equals = "Unattached"
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

################## POLICY DEFINITION : AUDIT PUBLIC IPs #############################

# Policy Definition: Audit Unused Public IPs
resource "azurerm_policy_definition" "audit_public_ip_unused_resources_cost_optimization" {
  name         = "Audit-PublicIpAddresses-UnusedResourcesCostOptimization"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Audit unused public IP addresses for cost optimization"
  description  = "Audits Microsoft.Network/publicIPAddresses that are not associated with any network interface or load balancer."
  metadata = jsonencode({
    category = "Cost Optimization"
    version  = "1.0.0"
  })
  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Disabled"]
      defaultValue  = "Audit"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
    }
  })
  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Network/publicIPAddresses"
        },
        {
          field  = "Microsoft.Network/publicIPAddresses/ipConfiguration.id"
          exists = false
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

################## POLICY DEFINITION : APP SERVICE PLANS #############################

# Policy Definition: Audit Unused App Service Plans
resource "azurerm_policy_definition" "audit_serverfarms_unused_resources_cost_optimization" {
  name         = "Audit-ServerFarms-UnusedResourcesCostOptimization"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Audit unused App Service Plans for cost optimization"
  description  = "Audits Microsoft.Web/serverfarms that are not hosting any active web apps."
  metadata = jsonencode({
    category = "Cost Optimization"
    version  = "1.0.0"
  })
  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Disabled"]
      defaultValue  = "Audit"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
    }
  })
  policy_rule = jsonencode({
    if = {
      allOf = [
        {
          field  = "type"
          equals = "Microsoft.Web/serverfarms"
        },
        {
          field  = "Microsoft.Web/serverfarms/numberOfSites"
          equals = 0
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}

################## POLICY DEFINITION : AZURE HYBRID BENEFIT LICENSES #############################

# Policy Definition: Audit Azure Hybrid Benefit Usage
resource "azurerm_policy_definition" "audit_azure_hybrid_benefit" {
  name         = "Audit-AzureHybridBenefit"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Audit Azure Hybrid Benefit usage"
  description  = "Audits virtual machines that are not using Azure Hybrid Benefit where eligible."
  metadata = jsonencode({
    category = "Cost Optimization"
    version  = "1.0.0"
  })
  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Disabled"]
      defaultValue  = "Audit"
      metadata = {
        displayName = "Effect"
        description = "Enable or disable the execution of the policy"
      }
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
          field     = "Microsoft.Compute/virtualMachines/licenseType"
          notEquals = "Windows_Server"
        }
      ]
    }
    then = {
      effect = "[parameters('effect')]"
    }
  })
}
#############################################################################