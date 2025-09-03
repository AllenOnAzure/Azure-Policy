#Enforces required tags and their values on resource groups
    /*These are compulsory values that must be present and cannot be renamed:
    createdByAllowedValues 
    multicloudAllowedValues
    platformAllowedValues
    roleAllowedValues
   */
   
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

resource "azurerm_policy_definition" "require_multiple_tags" {
  name         = "Enforces required tags and their values on resource groups"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Enforces required tags and their values on resource groups"
  description  = "Enforces required tags and their values on resource groups"
  metadata = jsonencode({
    version  = "1.0.0"
    category = "Tags"
  })

  parameters = jsonencode({

    platformAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Department' tag"
      }
      defaultValue = []
    }


    costcenterAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Cost_Centre_Code' tag"
      }
      defaultValue = []
    }


    BCAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Business_Criticality' tag"
      }
      defaultValue = []
    }

    replicationAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Replication' tag"
      }
      defaultValue = []
    }

    environmentAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Environment' tag"
      }
      defaultValue = []
    }

    roleAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'BU_Technical_Owner' tag"
      }
      defaultValue = []
    }

    snoozingAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Auto_Shutdown_Schedule' tag"
      }
      defaultValue = []
    }

    createdByAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Deployed_By' tag"
      }
      defaultValue = []
    }
    ApplicationNameValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Application_Name' tag"
      }
      defaultValue = []
    }
    multicloudAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Cloud_Platform' tag"
      }
      defaultValue = []
    }
    applicationOwnerAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Application_Owner' tag"
      }
      defaultValue = []
    }
    changeControlAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Change_Control_ID' tag"
      }
      defaultValue = []
    }
    vendorsupportAllowedValues = {
      type = "Array"
      metadata = {
        description = "Allowed values for the 'Vendor_Support' tag"
      }
      defaultValue = []
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
          anyOf = [

            {
              field = "tags['Department']"
              notIn = "[parameters('platformAllowedValues')]"
            },

            {
              field = "tags['Cost_Centre_Code']"
              notIn = "[parameters('costcenterAllowedValues')]"
            },

            {
              field = "tags['Business_Criticality']"
              notIn = "[parameters('BCAllowedValues')]"
            },

            {
              field = "tags['Replication']"
              notIn = "[parameters('replicationAllowedValues')]"
            },

            {
              field = "tags['Auto_Shutdown_Schedule']"
              notIn = "[parameters('snoozingAllowedValues')]"
            },


            {
              field = "tags['Environment']"
              notIn = "[parameters('environmentAllowedValues')]"
            },
            {
              field = "tags['BU_Technical_Owner']"
              notIn = "[parameters('roleAllowedValues')]"
            },
            {
              field = "tags['Deployed_By']"
              notIn = "[parameters('createdByAllowedValues')]"
            },
            {
              field = "tags['Application_Name']"
              notIn = "[parameters('ApplicationNameValues')]"
            },
            {
              field = "tags['Cloud_Platform']"
              notIn = "[parameters('multicloudAllowedValues')]"
            },
            {
              field = "tags['Application_Owner']"
              notIn = "[parameters('applicationOwnerAllowedValues')]"
            },
            {
              field = "tags['Change_Control_ID']"
              notIn = "[parameters('changeControlAllowedValues')]"
            },
            {
              field = "tags['Vendor_Support']"
              notIn = "[parameters('vendorsupportAllowedValues')]"
            }
          ]
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
  name                 = "Enforces required tags and their values on resource groups"
  policy_definition_id = azurerm_policy_definition.require_multiple_tags.id
  subscription_id      = "/subscriptions/${var.subscription_id}"

  parameters = jsonencode({

    platformAllowedValues = {
      value = ["Finance", "IT", "Sales", "Marketing"]
    }

    costcenterAllowedValues = {
      value = ["9800", "5566", "3012", "4512"]
    }

    BCAllowedValues = {
      value = ["Tier 0 - Mission-Critical", "Tier 1 - Business-Critical", "Tier 2 - Business-Operational", "Tier 3 - Dev/Test/Low Priority"]
    }

    replicationAllowedValues = {
      value = ["Geo-redundant storage (GRS)", "Zone-redundant storage (ZRS)", "Locally redundant storage (LRS)"]
    }

    snoozingAllowedValues = {
      value = ["None", "BusinessHours-8x5", "Off Hours-Weekends"]
    }

    environmentAllowedValues = {
      value = ["Development", "Test", "Production", "Sandbox", "Staging", "UAT"]
    }

    roleAllowedValues = {
      value = ["Allen Visser", "Bruce Wayne", "Clark Kent", "Barry Allen", "Dick Grayson", "Jason Todd"]
    }

    createdByAllowedValues = {
      value = ["Allen Visser", "Bruce Wayne", "Clark Kent", "Barry Allen", "Dick Grayson", "Jason Todd"]
    }
    ApplicationNameValues = {
      value = ["Application1", "Application2", "Application3", "Application4"]
    }
    multicloudAllowedValues = {
      value = ["Azure", "AWS", "GCP"]
    }
    applicationOwnerAllowedValues = {
      value = ["Allen Visser", "Bruce Wayne", "Clark Kent", "Barry Allen", "Dick Grayson", "Jason Todd"]
    }
    changeControlAllowedValues = {
      value = ["None", "CAB-20231025", "CAB-x"]
    }
    vendorsupportAllowedValues = {
      value = ["External_Vendor1", "External_Vendor2", "External_Vendor3"]
    }
  })
}      