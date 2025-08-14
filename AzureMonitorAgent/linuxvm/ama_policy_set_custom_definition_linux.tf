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
  default     = "14643a1d-597b-4575-8c72-5ed4d18bfa82"
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

# Create Linux Data Collection Rule (DCR)
resource "azurerm_monitor_data_collection_rule" "ama_linux" {
  name                = "AMA-Linux-DCR"
  location            = azurerm_resource_group.ama.location
  resource_group_name = azurerm_resource_group.ama.name

  data_flow {
    streams      = ["Microsoft-Syslog", "Microsoft-InsightsMetrics"]
    destinations = ["example-loganalytics"]
  }

  destinations {
    log_analytics {
      name                  = "example-loganalytics"
      workspace_resource_id = azurerm_log_analytics_workspace.ama.id
    }
  }

  data_sources {
    syslog {
      name    = "syslogBasic"
      streams = ["Microsoft-Syslog"]
      facility_names = [
        "auth",
        "authpriv",
        "cron",
        "daemon",
        "mark",
        "kern",
        "mail",
        "news",
        "syslog",
        "user",
        "uucp"
      ]
      log_levels = [
        "Debug",
        "Info",
        "Notice",
        "Warning",
        "Error",
        "Critical",
        "Alert",
        "Emergency"
      ]
    }

    performance_counter {
      name                          = "linuxPerfCounters"
      streams                       = ["Microsoft-InsightsMetrics"]
      sampling_frequency_in_seconds = 60
      counter_specifiers = [
        "/proc/meminfo/available_memory",
        "/proc/meminfo/mem_available_percent",
        "/proc/stat/cpu_usage",
        "/proc/stat/cpu_utilization",
        "/proc/diskstats/disk_throughput",
        "/proc/diskstats/disk_read_throughput",
        "/proc/diskstats/disk_write_throughput",
        "/proc/diskstats/disk_read_iops",
        "/proc/diskstats/disk_write_iops",
        "/proc/net/dev/net_bytes_per_second",
        "/proc/net/dev/net_packets_per_second",
        "/proc/net/dev/net_dropped_packets",
        "/proc/net/dev/net_errors"
      ]
    }

    extension {
      name           = "LinuxExtension"
      streams        = ["Microsoft-InsightsMetrics"]
      extension_name = "AzureMonitorLinuxAgent"
      extension_json = jsonencode({
        "metrics" : {
          "interval" : "PT1M",
          "namespace" : "LinuxAgent"
        }
      })
    }
  }

  description = "DCR for Azure Monitor Agent on Linux systems"
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
    "Contributor",                        # IAM to assign UAMI onto vms
    "User Access Administrator",          # IAM to assign UAMI onto vms
    "Monitoring Contributor",             # IAM to assign UAMI onto vms
    "Virtual Machine Contributor",        # IAM to assign UAMI onto vms
    "Monitoring Metrics Publisher",       # IAM to assign AMA onto vms
    "Log Analytics Contributor",          # IAM to assign AMA onto vms
    "Virtual Machine Administrator Login" # For extension management on Linux
  ]
}

# Assign each role to the UAMI at the subscription scope
resource "azurerm_role_assignment" "uami_linux_roles" {
  for_each             = toset(local.roles)
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = each.key
  principal_id         = azurerm_user_assigned_identity.ama_uami.principal_id
}

######################POLICY SET / INITIATIVE############################
# Create Linux Policy Set Definition
resource "azurerm_policy_set_definition" "linux_ama_policy_set" {
  name         = "LINUX-Deploy-Linux-Azure-Monitor-Agent"
  policy_type  = "Custom"
  display_name = "Deploy Linux Azure Monitor Agent with user-assigned managed identity-based auth and associate with Data Collection Rule"
  description  = "Monitor your Linux virtual machines and virtual machine scale sets by deploying the Azure Monitor Agent extension with user-assigned managed identity authentication and associating with specified Data Collection Rule."

  metadata = jsonencode({
    version  = "2.3.0"
    category = "Monitoring"
  })

  parameters = jsonencode({
    effect = {
      type = "String"
      metadata = {
        displayName = "Effect for all constituent policies"
        description = "Enable or disable the execution of each of the constituent policies in the initiative."
      }
      allowedValues = ["DeployIfNotExists", "Disabled"]
      defaultValue  = "DeployIfNotExists"
    }
    scopeToSupportedImages = {
      type = "Boolean"
      metadata = {
        displayName = "Scope Policy to Azure Monitor Agent-Supported Operating Systems"
        description = "If set to true, the policy will apply only to machines with supported operating systems."
      }
      allowedValues = [true, false]
      defaultValue  = true
    }
    listOfLinuxImageIdToInclude = {
      type = "Array"
      metadata = {
        displayName = "Additional Virtual Machine Images"
        description = "List of virtual machine images that have supported Linux OS to add to scope."
      }
      defaultValue = []
    }
    dcrResourceId = {
      type = "String"
      metadata = {
        displayName  = "Data Collection Rule Resource Id"
        description  = "Resource Id of the Data Collection Rule that the virtual machines in scope should point to."
        portalReview = "true"
      }
    }
    bringYourOwnUserAssignedManagedIdentity = {
      type = "Boolean"
      metadata = {
        displayName = "Bring Your Own User-Assigned Managed Identity"
        description = "If set to true, Azure Monitor Agent will use the user-assigned managed identity specified."
      }
      allowedValues = [false, true]
      defaultValue  = true
    }
    userAssignedManagedIdentityName = {
      type = "String"
      metadata = {
        displayName = "User-Assigned Managed Identity Name"
        description = "The name of the user-assigned managed identity."
      }
      defaultValue = var.user_assigned_identity_name
    }
    userAssignedManagedIdentityResourceGroup = {
      type = "String"
      metadata = {
        displayName = "User-Assigned Managed Identity Resource Group"
        description = "The resource group of the user-assigned managed identity."
      }
      defaultValue = var.user_assigned_identity_rg
    }
    builtInIdentityResourceGroupLocation = {
      type = "String"
      metadata = {
        displayName = "Built-In-Identity-RG Location"
        description = "The location of the resource group 'Built-In-Identity-RG'."
      }
      defaultValue = "uksouth"
    }
  })

  # Policy Definition References for Linux

  # 1. Add UAMI to Linux VMs
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/d367bd60-64ca-4364-98ea-276775bddd94"
    reference_id         = "addUserAssignedManagedIdentityVM"
    parameter_values = jsonencode({
      effect = {
        value = "[parameters('effect')]"
      }
      bringYourOwnUserAssignedManagedIdentity = {
        value = "[parameters('bringYourOwnUserAssignedManagedIdentity')]"
      }
      userAssignedIdentityName = {
        value = "[parameters('userAssignedManagedIdentityName')]"
      }
      identityResourceGroup = {
        value = "[parameters('userAssignedManagedIdentityResourceGroup')]"
      }
      builtInIdentityResourceGroupLocation = {
        value = "[parameters('builtInIdentityResourceGroupLocation')]"
      }
    })
  }

  # 2. Add UAMI to Linux VM Scale Sets
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/516187d4-ef64-4a1b-ad6b-a7348502976c"
    reference_id         = "addUserAssignedManagedIdentityVMSS"
    parameter_values = jsonencode({
      effect = {
        value = "[parameters('effect')]"
      }
      bringYourOwnUserAssignedManagedIdentity = {
        value = "[parameters('bringYourOwnUserAssignedManagedIdentity')]"
      }
      userAssignedIdentityName = {
        value = "[parameters('userAssignedManagedIdentityName')]"
      }
      identityResourceGroup = {
        value = "[parameters('userAssignedManagedIdentityResourceGroup')]"
      }
      builtInIdentityResourceGroupLocation = {
        value = "[parameters('builtInIdentityResourceGroupLocation')]"
      }
    })
  }

  # 3. Deploy AMA to Linux VMs
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/ae8a10e6-19d6-44a3-a02d-a2bdfc707742"
    reference_id         = "deployAzureMonitoringAgentLinuxVMWithUAI"
    parameter_values = jsonencode({
      effect = {
        value = "[parameters('effect')]"
      }
      bringYourOwnUserAssignedManagedIdentity = {
        value = "[parameters('bringYourOwnUserAssignedManagedIdentity')]"
      }
      userAssignedManagedIdentityName = {
        value = "[parameters('userAssignedManagedIdentityName')]"
      }
      userAssignedManagedIdentityResourceGroup = {
        value = "[parameters('userAssignedManagedIdentityResourceGroup')]"
      }
      scopeToSupportedImages = {
        value = "[parameters('scopeToSupportedImages')]"
      }
      listOfLinuxImageIdToInclude = {
        value = "[parameters('listOfLinuxImageIdToInclude')]"
      }
    })
  }

  # 4. Deploy AMA to Linux VM Scale Sets
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/59c3d93f-900b-4827-a8bd-562e7b956e7c"
    reference_id         = "deployAzureMonitorAgentLinuxVMSSWithUAI"
    parameter_values = jsonencode({
      effect = {
        value = "[parameters('effect')]"
      }
      bringYourOwnUserAssignedManagedIdentity = {
        value = "[parameters('bringYourOwnUserAssignedManagedIdentity')]"
      }
      userAssignedManagedIdentityName = {
        value = "[parameters('userAssignedManagedIdentityName')]"
      }
      userAssignedManagedIdentityResourceGroup = {
        value = "[parameters('userAssignedManagedIdentityResourceGroup')]"
      }
      scopeToSupportedImages = {
        value = "[parameters('scopeToSupportedImages')]"
      }
      listOfLinuxImageIdToInclude = {
        value = "[parameters('listOfLinuxImageIdToInclude')]"
      }
    })
  }

  # 5. Associate DCR with Linux resources
  policy_definition_reference {
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/2ea82cdd-f2e8-4500-af75-67a2e084ca74"
    reference_id         = "associateDataCollectionRuleLinuxWithUAI"
    parameter_values = jsonencode({
      effect = {
        value = "[parameters('effect')]"
      }
      scopeToSupportedImages = {
        value = "[parameters('scopeToSupportedImages')]"
      }
      listOfLinuxImageIdToInclude = {
        value = "[parameters('listOfLinuxImageIdToInclude')]"
      }
      dcrResourceId = {
        value = "[parameters('dcrResourceId')]"
      }
      resourceType = {
        value = "Microsoft.Insights/dataCollectionRules"
      }
    })
  }
}