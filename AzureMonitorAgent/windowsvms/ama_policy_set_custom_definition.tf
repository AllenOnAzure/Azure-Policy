##################PROVIDER########################################
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

  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}



##################VARIABLES########################################
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  default     = "<subscriptionID>"
}

variable "user_assigned_identity_name" {
  description = "Name of the user-assigned managed identity"
  type        = string
  default     = "AMA-deploying-UAMI" # Matching your existing UAMI name
}

variable "user_assigned_identity_rg" {
  description = "Resource group name for the user-assigned managed identity"
  type        = string
  default     = "AMA-monitoring-rg" # Matching your existing RG name
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "UK South" # Matching your existing location
}
##################RESOURCES########################################
# Create Resource Group
resource "azurerm_resource_group" "ama" {
  name     = "AMA-monitoring-rg"
  location = "UK South"
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "ama" {
  name                = "amadeployment"
  location            = azurerm_resource_group.ama.location
  resource_group_name = azurerm_resource_group.ama.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Create Data Collection Rule (DCR)
resource "azurerm_monitor_data_collection_rule" "ama" {
  name                = "AMA-deployment-DCR"
  location            = azurerm_resource_group.ama.location
  resource_group_name = azurerm_resource_group.ama.name

  data_flow {
    streams      = ["Microsoft-InsightsMetrics"]
    destinations = ["example-loganalytics"]
  }

  destinations {
    log_analytics {
      name                  = "example-loganalytics"
      workspace_resource_id = azurerm_log_analytics_workspace.ama.id
    }
  }

  data_sources {
    performance_counter {
      name                          = "default-perf"
      streams                       = ["Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available MBytes"
      ]
    }
  }

  description = "DCR for Azure Monitor Agent"
}
#########################UAMI#####################################
# Create User Assigned Managed Identity
resource "azurerm_user_assigned_identity" "ama_uami" {
  name                = "AMA-deploying-UAMI"
  location            = azurerm_resource_group.ama.location
  resource_group_name = azurerm_resource_group.ama.name
}
##################ASSIGN IAM ROLES TO UAMI#####################
# List of roles to assign
locals {
  roles = [
    "Contributor",                  # IAM to assign UAMI onto vms
    "User Access Administrator",    # IAM to assign UAMI onto vms
    "Monitoring Contributor",       # IAM to assign UAMI onto vms
    "Virtual Machine Contributor",  # IAM to assign UAMI onto vms
    "Monitoring Metrics Publisher", # IAM to assign AMA onto vms
    "Log Analytics Contributor"     # IAM to assign AMA onto vms
  ]
}

# Assign each role to the UAMI at the subscription scope
resource "azurerm_role_assignment" "uami_roles" {
  for_each             = toset(local.roles)
  scope                = "/subscriptions/${var.subscription_id}" # Use variable instead of hardcoded value
  role_definition_name = each.key
  principal_id         = azurerm_user_assigned_identity.ama_uami.principal_id # Fixed reference
}
######################POLICY SET / INITIATIVE############################
# Create Policy Set Definition
resource "azurerm_policy_set_definition" "example" {
  name         = "Allen-ama-policy-set-custom" # Changed from built-in GUID to custom name
  policy_type  = "Custom"                           # Changed from "BuiltIn" since you're customizing
  display_name = "Allen-Deploy Windows Azure Monitor Agent with user-assigned managed identity-based auth and associate with Data Collection Rule"
  description  = "Monitor your Windows virtual machines and virtual machine scale sets by deploying the Azure Monitor Agent extension with user-assigned managed identity authentication and associating with specified Data Collection Rule."

  metadata = jsonencode({
    "version"  = "2.3.0"
    "category" = "Monitoring"
  })

  parameters = jsonencode({
    "effect" = {
      "type" = "String",
      "metadata" = {
        "displayName" = "Effect",
        "description" = "Enable or disable the execution of the policy."
      },
      "allowedValues" = ["DeployIfNotExists", "Disabled"],
      "defaultValue"  = "DeployIfNotExists"
    },
    "scopeToSupportedImages" = {
      "type" = "Boolean",
      "metadata" = {
        "displayName" = "Scope Policy to Azure Monitor Agent-Supported Operating Systems",
        "description" = "If set to true, the policy will apply only to machines with supported operating systems."
      },
      "allowedValues" = [true, false],
      "defaultValue"  = true
    },
    "listOfWindowsImageIdToInclude" = {
      "type" = "Array",
      "metadata" = {
        "displayName" = "Additional Virtual Machine Images",
        "description" = "List of virtual machine images that have supported Windows OS to add to scope."
      },
      "defaultValue" = []
    },
    "dcrResourceId" = {
      "type" = "String",
      "metadata" = {
        "displayName"  = "Data Collection Rule Resource Id",
        "description"  = "Resource Id of the Data Collection Rule that the virtual machines in scope should point to.",
        "portalReview" = "true"
      },
      defaultValue = azurerm_monitor_data_collection_rule.ama.id
    },

    "bringYourOwnUserAssignedManagedIdentity" = {
      "type" = "Boolean",
      "metadata" = {
        "displayName" = "Bring Your Own User-Assigned Managed Identity",
        "description" = "If set to true, Azure Monitor Agent will use the user-assigned managed identity specified."
      },
      "allowedValues" = [false, true]
      "defaultValue"  = true
    },
    "userAssignedManagedIdentityName" = {
      "type" = "String",
      "metadata" = {
        "displayName" = "User-Assigned Managed Identity Name",
        "description" = "The name of the user-assigned managed identity."
      },
      #      "defaultValue" = ""
      "defaultValue" = var.user_assigned_identity_name
    },
    "userAssignedManagedIdentityResourceGroup" = {
      "type" = "String",
      "metadata" = {
        "displayName" = "User-Assigned Managed Identity Resource Group",
        "description" = "The resource group of the user-assigned managed identity."
      },
      #"defaultValue" = ""
      "defaultValue" = var.user_assigned_identity_rg
    },
    "builtInIdentityResourceGroupLocation" = {
      "type" = "String",
      "metadata" = {
        "displayName" = "Built-In-Identity-RG Location",
        "description" = "The location of the resource group 'Built-In-Identity-RG'."
      },
      "defaultValue" = "uksouth" #If this value is not hard set, and is set via a variable, then the assignment defaults to east US for some reason??
    }
  })





  # Policy Definition References
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/d367bd60-64ca-4364-98ea-276775bddd94"
    reference_id         = "addUserAssignedManagedIdentityVM"
    parameter_values = jsonencode({
      effect = {
        value = "[parameters('effect')]"
      },
      bringYourOwnUserAssignedManagedIdentity = {
        value = "[parameters('bringYourOwnUserAssignedManagedIdentity')]"
      },
      userAssignedIdentityName = {
        value = "[parameters('userAssignedManagedIdentityName')]"
      },
      identityResourceGroup = {
        value = "[parameters('userAssignedManagedIdentityResourceGroup')]"
      },
      builtInIdentityResourceGroupLocation = {
        value = "[parameters('builtInIdentityResourceGroupLocation')]"
      }
    })
  }

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/516187d4-ef64-4a1b-ad6b-a7348502976c"
    reference_id         = "addUserAssignedManagedIdentityVMSS"
    parameter_values = jsonencode({
      effect = {
        value = "[parameters('effect')]"
      },
      bringYourOwnUserAssignedManagedIdentity = {
        value = "[parameters('bringYourOwnUserAssignedManagedIdentity')]"
      },
      userAssignedIdentityName = {
        value = "[parameters('userAssignedManagedIdentityName')]"
      },
      identityResourceGroup = {
        value = "[parameters('userAssignedManagedIdentityResourceGroup')]"
      },
      builtInIdentityResourceGroupLocation = {
        value = "[parameters('builtInIdentityResourceGroupLocation')]"
      }
    })
  }

  #SINGLE VM:
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/637125fd-7c39-4b94-bb0a-d331faf333a9"
    reference_id         = "deployAzureMonitoringAgentWindowsVMWithUAI"
    parameter_values = jsonencode({
      effect = {
        value = "[parameters('effect')]"
      },
      bringYourOwnUserAssignedManagedIdentity = {
        value = "[parameters('bringYourOwnUserAssignedManagedIdentity')]"
      },
      userAssignedManagedIdentityName = {
        value = "[parameters('userAssignedManagedIdentityName')]"
      },
      userAssignedManagedIdentityResourceGroup = {
        value = "[parameters('userAssignedManagedIdentityResourceGroup')]"
      },
      scopeToSupportedImages = {
        value = "[parameters('scopeToSupportedImages')]"
      },
      listOfWindowsImageIdToInclude = {
        value = "[parameters('listOfWindowsImageIdToInclude')]"
      }
    })
  }

  #VM SCALE SET:
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/98569e20-8f32-4f31-bf34-0e91590ae9d3"
    reference_id         = "deployAzureMonitorAgentWindowsVMSSWithUAI"
    parameter_values = jsonencode({
      effect = {
        value = "[parameters('effect')]"
      },
      bringYourOwnUserAssignedManagedIdentity = {
        value = "[parameters('bringYourOwnUserAssignedManagedIdentity')]"
      },
      userAssignedManagedIdentityName = {
        value = "[parameters('userAssignedManagedIdentityName')]"
      },
      userAssignedManagedIdentityResourceGroup = {
        value = "[parameters('userAssignedManagedIdentityResourceGroup')]"
      },
      scopeToSupportedImages = {
        value = "[parameters('scopeToSupportedImages')]"
      },
      listOfWindowsImageIdToInclude = {
        value = "[parameters('listOfWindowsImageIdToInclude')]"
      }
    })
  }

  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/eab1f514-22e3-42e3-9a1f-e1dc9199355c"
    reference_id         = "associateDataCollectionRuleWindowsWithUAI"
    parameter_values = jsonencode({
      effect = {
        value = "[parameters('effect')]"
      },
      scopeToSupportedImages = {
        value = "[parameters('scopeToSupportedImages')]"
      },
      listOfWindowsImageIdToInclude = {
        value = "[parameters('listOfWindowsImageIdToInclude')]"
      },
      dcrResourceId = {
        value = "[parameters('dcrResourceId')]"
      },
      resourceType = {
        value = "Microsoft.Insights/dataCollectionRules"
      }
    })
  }
}