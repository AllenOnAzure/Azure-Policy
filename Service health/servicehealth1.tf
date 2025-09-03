# pulling the UAMI data source 
# Search the entire scripts for "defaultValue" and verify 
# Assign UAMI with RBAC role,
# DEFINITION:
#[Preview]: Configure subscriptions to enable service health alert monitoring rule
# ASSIGNMENT: 
#[Preview]: Configure Service Health Alert Monitoring
# COMPLIANCE: 
#[Preview]: Configure Service Health Alert Monitoring
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

##################   NAMING CONVENTION   ##################

/*
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4"

  prefix        = [var.prefix]      
  suffix        = [var.suffix]    
  environment   = var.environment
  location      = [var.location]
  resource_type = [var.resource_type]

}
*/

##################  VARIABLES ##################

# In your variables.tf or wherever you declare variables:
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "user_assigned_identity_name" {
  description = "Name of the user-assigned managed identity"
  type        = string
}

variable "user_assigned_identity_rg" {
  description = "Resource group name for the user-assigned managed identity"
  type        = string
}

variable "client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
}

variable "client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

variable "attempt_import" {
  description = "Flag to attempt importing existing resource group"
  type        = bool
  default     = true
}

variable "alertRuleName" {
  description = "Alert Rule name"
  type        = string
}

variable "newActionGroupName" {
  description = "Action Group name"
  type        = string
}

variable "email_address" {
  description = "Email address to receive service health notifications"
  type        = string
  sensitive   = true # Recommended since it's personal data
}

################################## RESOURCES ######################

resource "azurerm_resource_group" "ama" {
  name     = var.resource_group_name
  location = var.location
}

### USER ASSIGNED IDENTITY WITH RBAC ROLE #####
# Create User Assigned Managed Identity
resource "azurerm_user_assigned_identity" "uami" {
  name                = var.user_assigned_identity_name
  location            = var.location
  resource_group_name = var.resource_group_name
}

### List of roles to assign
locals {
  roles = [
    "Contributor",            # IAM to assign UAMI onto vms > Required for Service Health Deployment
    "Monitoring Contributor", # Required for any Azure Monitor resource creation: alerts / action groups
    #"User Access Administrator",    # IAM to assign UAMI onto vms
    #"Virtual Machine Contributor",  # IAM to assign UAMI onto vms
    #"Monitoring Metrics Publisher", # IAM to assign AMA onto vms
    #"Log Analytics Contributor"     # IAM to assign AMA onto vms
    #"Key Vault Reader"				 # If your alert rules or action groups interact with Azure Key Vault
  ]
}

resource "azurerm_role_assignment" "existing" {
  for_each             = toset(local.roles)
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = each.key
  principal_id         = azurerm_user_assigned_identity.uami.principal_id

  # This will fail silently if not found
  depends_on = [azurerm_user_assigned_identity.uami]
  lifecycle {
    #ignore_errors = true
  }
}

######################POLICY DEFINITION##########################

resource "azurerm_policy_definition" "service_health_alert" {
  name         = "ConfigureServiceHealthAlertMonitoring" #[Preview]: Configure subscriptions to enable service health alert monitoring rule
  policy_type  = "Custom"
  mode         = "All"
  display_name = "[Preview]: Configure subscriptions to enable service health alert monitoring rule"

  metadata = jsonencode({
    version  = "1.2.0-preview"
    category = "Monitoring"
    preview  = true
  })

  policy_rule = jsonencode({
    "if" : {
      "field" : "type",
      "equals" : "Microsoft.Resources/subscriptions"
    },
    "then" : {
      "effect" : "[parameters('effect')]",
      "details" : {
        "roleDefinitionIds" : [
          "/providers/Microsoft.Authorization/roleDefinitions/47be4a87-7950-4631-9daf-b664a405f074"
        ],
        "type" : "Microsoft.Insights/ActivityLogAlerts",
        "existenceScope" : "resourceGroup",
        "resourceGroupName" : "[parameters('resourceGroupName')]",
        "deploymentScope" : "subscription",
        "existenceCondition" : {
          "allOf" : [
            {
              "field" : "Microsoft.Insights/ActivityLogAlerts/enabled",
              "equals" : "[parameters('enableAlertRule')]"
            },
            {
              "count" : {
                "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*]",
                "where" : {
                  "allOf" : [
                    {
                      "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].field",
                      "equals" : "category"
                    },
                    {
                      "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].equals",
                      "equals" : "ServiceHealth"
                    }
                  ]
                }
              },
              "greaterOrEquals" : 1
            },
            {
              "count" : {
                "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].anyOf[*]",
                "where" : {
                  "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].anyOf[*].field",
                  "equals" : "properties.incidentType"
                }
              },
              "equals" : "[if(contains(parameters('eventTypes'), 'Health Advisories'), add(length(parameters('eventTypes')), 2), length(parameters('eventTypes')))]"
            },


            {
              "count" : {
                "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].anyOf[*]",
                "where" : {
                  "allOf" : [
                    {
                      "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].anyOf[*].field",
                      "equals" : "properties.incidentType"
                    },
                    {
                      "anyOf" : [
                        {
                          "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].anyOf[*].equals",
                          "in" : "[if(contains(parameters('eventTypes'), 'Service Issues'), createArray('Incident'), createArray())]"
                        },
                        {
                          "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].anyOf[*].equals",
                          "in" : "[if(contains(parameters('eventTypes'), 'Health Advisories'), createArray('Maintenance'), createArray())]"
                        },
                        {
                          "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].anyOf[*].equals",
                          "in" : "[if(contains(parameters('eventTypes'), 'Security Advisories'), createArray('Security'), createArray())]"
                        },
                        {
                          "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].anyOf[*].equals",
                          "in" : "[if(contains(parameters('eventTypes'), 'Health Advisories'), createArray('Informational'), createArray())]"
                        },
                        {
                          "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].anyOf[*].equals",
                          "in" : "[if(contains(parameters('eventTypes'), 'Health Advisories'), createArray('ActionRequired'), createArray())]"
                        },
                        {
                          "field" : "Microsoft.Insights/ActivityLogAlerts/condition.allOf[*].anyOf[*].equals",
                          "in" : "[if(contains(parameters('eventTypes'), 'Health Advisories'), createArray('Retirement'), createArray())]"
                        }
                      ]
                    }
                  ]
                }
              },
              "equals" : "[if(contains(parameters('eventTypes'), 'Health Advisories'), add(length(parameters('eventTypes')), 2), length(parameters('eventTypes')))]"
            },
            {
              "count" : {
                "field" : "Microsoft.Insights/ActivityLogAlerts/actions.actionGroups[*]"
              },
              "equals" : "[add(length(parameters('actionGroups')), if(equals(parameters('createNewActionGroup'), 'true'), 1, 0))]"
            },
            {
              "count" : {
                "field" : "Microsoft.Insights/ActivityLogAlerts/actions.actionGroups[*]",
                "where" : {
                  "anyOf" : [
                    {
                      "field" : "Microsoft.Insights/ActivityLogAlerts/actions.actionGroups[*].actionGroupId",
                      "in" : "[parameters('actionGroups')]"
                    },
                    {
                      "field" : "Microsoft.Insights/ActivityLogAlerts/actions.actionGroups[*].actionGroupId",
                      "equals" : "[format('/subscriptions/{0}/resourceGroups/{1}/providers/Microsoft.Insights/actionGroups/{2}', subscription().subscriptionId, parameters('resourceGroupName'), parameters('newActionGroupName'))]"
                    }
                  ]
                }
              },
              "equals" : "[add(length(parameters('actionGroups')), if(equals(parameters('createNewActionGroup'), 'true'), 1, 0))]"
            }
          ]
        },
        "deployment" : {
          "location" : "var.location",
          "properties" : {
            "mode" : "incremental",
            "template" : {
              "$schema" : "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
              "contentVersion" : "1.0.0.0",
              "parameters" : {
                "resourceGroupName" : {
                  "type" : "string"
                },
                "alertRuleName" : {
                  "type" : "string"
                },
                "additionalTags" : {
                  "type" : "object"
                },
                "resourceGroupLocation" : {
                  "type" : "string"
                },
                "eventTypes" : {
                  "type" : "Array"
                },
                "enableAlertRule" : {
                  "type" : "string"
                },
                "actionGroups" : {
                  "type" : "Array"
                },
                "newActionGroupName" : {
                  "type" : "String"
                },
                "createNewActionGroup" : {
                  "type" : "String"
                },
                "actionGroupRoleIds" : {
                  "type" : "Array"
                },
                "actionGroupResources" : {
                  "type" : "Object"
                }
              },
              "resources" : [
                {
                  "type" : "Microsoft.Resources/resourceGroups",
                  "apiVersion" : "2021-04-01",
                  "name" : "[parameters('resourceGroupName')]",
                  "location" : "[parameters('resourceGroupLocation')]",
                  "tags" : "[union(variables('varDefaultResourceGroupTags'),parameters('additionalTags'))]"
                },
                {
                  "dependsOn" : [
                    "[concat('Microsoft.Resources/resourceGroups/', parameters('resourceGroupName'))]"
                  ],
                  "type" : "Microsoft.Resources/deployments",
                  "apiVersion" : "2019-10-01",
                  "name" : "SH-ActionGroupDeployment",
                  "resourceGroup" : "[parameters('resourceGroupName')]",
                  "properties" : {
                    "expressionEvaluationOptions" : {
                      "scope" : "inner"
                    },
                    "mode" : "Incremental",
                    "template" : {
                      "$schema" : "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
                      "contentVersion" : "1.0.0.0",
                      "resources" : [
                        {
                          "condition" : "[equals(parameters('createNewActionGroup'), 'true')]",
                          "type" : "Microsoft.Insights/actionGroups",
                          "apiVersion" : "2023-01-01",
                          "name" : "[parameters('newActionGroupName')]",
                          "location" : "global",
                          "tags" : "[union(parameters('additionalTags'),parameters('defaultActionGroupTags'))]",
                          "properties" : {
                            "groupShortName" : "SHA-AG",
                            "enabled" : true,
                            "emailReceivers" : "[if(empty(parameters('emailReceivers')), null(), parameters('emailReceivers'))]",
                            "armRoleReceivers" : "[if(empty(parameters('armRoleReceivers')), null(), parameters('armRoleReceivers'))]",
                            "logicAppReceivers" : "[if(empty(parameters('logicAppReceivers')), null(), parameters('logicAppReceivers'))]",
                            "eventHubReceivers" : "[if(empty(parameters('eventHubReceivers')), null(), parameters('eventHubReceivers'))]",
                            "webhookReceivers" : "[if(empty(parameters('webhookReceivers')), null(), parameters('webhookReceivers'))]",
                            "azureFunctionReceivers" : "[if(empty(parameters('azureFunctionReceivers')), null(), parameters('azureFunctionReceivers'))]"
                          }
                        }
                      ]
                    }
                  }
                },
                {
                  "dependsOn" : [
                    "SH-ActionGroupDeployment"
                  ],
                  "type" : "Microsoft.Resources/deployments",
                  "apiVersion" : "2019-10-01",
                  "name" : "SH-CombinedAlertRuleDeployment",
                  "resourceGroup" : "[parameters('resourceGroupName')]",
                  "properties" : {
                    "expressionEvaluationOptions" : {
                      "scope" : "inner"
                    },
                    "mode" : "Incremental",
                    "template" : {
                      "$schema" : "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
                      "contentVersion" : "1.0.0.0",
                      "resources" : [
                        {
                          "type" : "Microsoft.Insights/activityLogAlerts",
                          "apiVersion" : "2020-10-01",
                          "location" : "global",
                          "tags" : "[union(parameters('additionalTags'),parameters('defaultAlertTag'))]",
                          "name" : "[parameters('alertRuleName')]",
                          "properties" : {
                            "enabled" : "[parameters('enableAlertRule')]",
                            "scopes" : [
                              "[subscription().id]"
                            ],
                            "condition" : {
                              "allOf" : [
                                {
                                  "field" : "category",
                                  "equals" : "ServiceHealth"
                                },
                                {
                                  "anyOf" : "[parameters('incidentConditions')]"
                                }
                              ]
                            },
                            "actions" : {
                              "actionGroups" : "[concat(if(empty(parameters('actionGroups')), createArray(), parameters('actionGroups')), if(equals(parameters('createNewActionGroup'), 'false'), createArray(), createArray(createObject('actionGroupId', resourceId('Microsoft.Insights/actionGroups', parameters('newActionGroupName')))))]"
                            }
                          }
                        }
                      ]
                    }
                  }
                }
              ]
            },
            "parameters" : {
              "resourceGroupName" : {
                "value" : "[parameters('resourceGroupName')]"
              },
              "alertRuleName" : {
                "value" : "[parameters('alertRuleName')]"
              },
              "additionalTags" : {
                "value" : "[parameters('additionalTags')]"
              },
              "resourceGroupLocation" : {
                "value" : "[parameters('resourceGroupLocation')]"
              },
              "eventTypes" : {
                "value" : "[parameters('eventTypes')]"
              },
              "enableAlertRule" : {
                "value" : "[parameters('enableAlertRule')]"
              },
              "actionGroups" : {
                "value" : "[parameters('actionGroups')]"
              },
              "createNewActionGroup" : {
                "value" : "[parameters('createNewActionGroup')]"
              },
              "newActionGroupName" : {
                "value" : "[parameters('newActionGroupName')]"
              },
              "actionGroupRoleIds" : {
                "value" : "[parameters('actionGroupRoleIds')]"
              },
              "actionGroupResources" : {
                "value" : "[parameters('actionGroupResources')]"
              }
            }
          }
        }
      }
    }
  })

  parameters = jsonencode({
    "effect" : {
      "type" : "String",
      "metadata" : {
        "displayName" : "Effect",
        "description" : "Deploy, audit, or disable this policy."
      },
      "allowedValues" : [
        "DeployIfNotExists",
        "AuditIfNotExists",
        "Disabled"
      ],
      "defaultValue" : "DeployIfNotExists"
    },
    "enableAlertRule" : {
      "type" : "String",
      "metadata" : {
        "displayName" : "Alert rule enabled",
        "description" : "The state of the alert rule(enabled or disabled) created by this policy."
      },
      "allowedValues" : [
        "true",
        "false"
      ],
      "defaultValue" : "true"
    },
    "alertRuleName" : {
      "type" : "String",
      "metadata" : {
        "displayName" : "Alert rule name",
        "description" : "The name of the alert rule created by this policy. If this is updated after the policy has created resources it can result in duplicate alerts. Please set \"Alert rule enabled\" parameter to false and remediate before updating this value"
      },
      "defaultValue" : var.alertRuleName
    },
    "eventTypes" : {
      "type" : "Array",
      "metadata" : {
        "displayName" : "Alert rule event types",
        "description" : "The alert rule will check for a service health alert for the following incident types."
      },
      "allowedValues" : [
        "Service Issues",
        "Planned Maintenance",
        "Health Advisories",
        "Security Advisories"
      ],
      "defaultValue" : [
        "Service Issues",
        "Planned Maintenance",
        "Health Advisories",
        "Security Advisories"
      ]
    },
    "actionGroups" : {
      "type" : "Array",
      "metadata" : {
        "displayName" : "Existing action group resource ids",
        "description" : "The resource ids of existing action groups in the Management Group/Subscription (depending on policy assignment scope) to be used to send alerts."
      },
      "defaultValue" : []
    },
    "createNewActionGroup" : {
      "type" : "String",
      "metadata" : {
        "displayName" : "New action group creation",
        "description" : "If set to true policy creates a new action group for alerts. If set to false, no new action group is created. This creates an action group in each subscription. Use 'Existing action group resource ids' parameter to use a single action group across subscriptions."
      },
      "allowedValues" : [
        "true",
        "false"
      ],
      "defaultValue" : "true"
    },
    "newActionGroupName" : {
      "type" : "String",
      "metadata" : {
        "displayName" : "New action group name",
        "description" : "Action group name used to create new action group. If the name is updated after the action group is created it can result in duplicate action groups. Only one 'New action group' will be assigned to the alert rule. Use 'Existing action group resource ids' parameter to assign multiple action groups."
      },
      "defaultValue" : var.newActionGroupName
    },
    "actionGroupRoleIds" : {
      "type" : "Array",
      "metadata" : {
        "displayName" : "New action group roles to email",
        "description" : "Arm built-in roles to notify using the new action group. Updates/Compliance state changes do not trigger based on this parameter. Update alert rule parameters above or action group name to trigger an update"
      },
      "allowedValues" : [
        "Contributor",
        "Owner",
        "Reader",
        "Monitoring Reader",
        "Monitoring Contributor"
      ],
      "defaultValue" : [
        "Owner"
      ]
    },
    "actionGroupResources" : {
      "type" : "Object",
      "metadata" : {
        "displayName" : "New action group resources",
        "description" : "Resources to be used by the new action group to send alerts. Resources specified must already exist. Updates/Compliance state changes do not trigger based on this parameter. Update alert rule parameters above or action group name to trigger an update"
      },
      "defaultValue" : {
        "actionGroupEmail" : [],
        "logicappResourceId" : "",
        "logicappCallbackUrl" : "",
        "eventHubResourceId" : [],
        "webhookServiceUri" : [],
        "functionResourceId" : "",
        "functionTriggerUrl" : ""
      }
    },
    "resourceGroupName" : {
      "type" : "String",
      "metadata" : {
        "displayName" : "Resource group name",
        "description" : "Resource group name used if neccesary to create the alert rule or action group. If this is updated after resources are created it can result in duplicate alert rules and action groups. Please set \"Alert rule enabled\" parameter to false and remediate before updating this value"
      },
      "defaultValue" : var.resource_group_name
    },
    "resourceGroupLocation" : {
      "type" : "String",
      "metadata" : {
        "displayName" : "Resource group location",
        "description" : "Location used to create the resource group",
        "strongType" : "location"
      },
      "defaultValue" : var.location
    },
    "additionalTags" : {
      "type" : "Object",
      "metadata" : {
        "displayName" : "Resource tags",
        "description" : "Tags on the resources created by this policy."
      },
      "defaultValue" : {
        "_created_by_policy" : true
      }
    }
  })
}

############### Policy Assignment with User-Assigned Managed Identity ###############
resource "azurerm_subscription_policy_assignment" "service_health_alert" {
  name                 = "assign-service-health-alert"
  subscription_id      = "/subscriptions/${var.subscription_id}"
  policy_definition_id = azurerm_policy_definition.service_health_alert.id
  description          = "Policy assignment for Service Health Alert monitoring"
  display_name         = "[Preview]: Configure Service Health Alert Monitoring"
  location             = var.location # Must match UAMI location

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.uami.id]
  }

  parameters = jsonencode({
    "effect" : {
      "value" : "DeployIfNotExists"
    },
    "enableAlertRule" : {
      "value" : "true"
    },
    "alertRuleName" : {
      "value" : var.alertRuleName
    },
    "eventTypes" : {
      "value" : [
        "Service Issues",
        "Planned Maintenance",
        "Health Advisories",
        "Security Advisories"
      ]
    },
    "actionGroups" : {
      "value" : []
    },
    "createNewActionGroup" : {
      "value" : "true"
    },
    "newActionGroupName" : {
      "value" : var.newActionGroupName
    },
    "actionGroupRoleIds" : {
      "value" : ["Owner"]
    },
    "actionGroupResources" : {
      "value" : {
        "actionGroupEmail" : [],
        "logicappResourceId" : "",
        "logicappCallbackUrl" : "",
        "eventHubResourceId" : [],
        "webhookServiceUri" : [],
        "functionResourceId" : "",
        "functionTriggerUrl" : ""
      }
    },
    "resourceGroupName" : {
      "value" : var.resource_group_name
    },
    "resourceGroupLocation" : {
      "value" : var.location
    },
    "additionalTags" : {
      "value" : {
        "_created_by_policy" : true
      }
    }
  })
}

# Role assignment for the UAMI to perform remediation
resource "azurerm_role_assignment" "uami_policy_role" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Resource Policy Contributor"
  principal_id         = azurerm_user_assigned_identity.uami.principal_id # Changed from data source
}

############################################################