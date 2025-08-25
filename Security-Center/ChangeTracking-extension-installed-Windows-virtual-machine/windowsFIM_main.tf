/*
[Preview]: ChangeTracking extension should be installed on your Windows virtual machine

"Checks if a Windows VM meets the criteria. If it does, then looks for a related resource (the ChangeTracking extension). 
If that related resource does not exist, marks the VM as non-compliant in an audit log, but do NOT automatically install the extension or change the VM." Hence Read Only.
*/
#################### PROVIDER ####################

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
##################### RESOURCES #####################
resource "azurerm_policy_definition" "windows_fim" {
  name         = "ChangeTracking extension should be installed on your Windows VM"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "[Preview]: ChangeTracking extension should be installed on your Windows virtual machine"
  description  = "Install ChangeTracking Extension on Windows virtual machines to enable File Integrity Monitoring(FIM) in Azure Security Center. FIM examines operating system files, Windows registries, application software, Linux system files, and more, for changes that might indicate an attack. The extension can be installed in virtual machines and locations supported by Azure Monitoring Agent."

  metadata = jsonencode({
    "version"  = "2.0.0-preview"
    "category" = "Security Center"
    "preview"  = true
  })

  parameters = jsonencode({
    "effect" = {
      "type" = "String"
      "metadata" = {
        "displayName" = "Effect"
        "description" = "Enable or disable the execution of the policy"
      }
      "allowedValues" = ["AuditIfNotExists", "Disabled"]
      "defaultValue"  = "AuditIfNotExists"
    },
    "listOfApplicableLocations" = {
      "type" = "Array"
      "metadata" = {
        "displayName" = "Applicable Locations"
        "description" = "The list of locations where the policy should be applied."
        "strongType"  = "location"
      }
      "allowedValues" = ["australiasoutheast", "australiaeast", "brazilsouth", "canadacentral", "centralindia", "centralus", "eastasia", "eastus2euap", "eastus", "eastus2", "francecentral", "japaneast", "koreacentral", "northcentralus", "northeurope", "norwayeast", "southcentralus", "southeastasia", "switzerlandnorth", "uaenorth", "uksouth", "westcentralus", "westeurope", "westus", "westus2"]
      "defaultValue"  = ["australiasoutheast", "australiaeast", "brazilsouth", "canadacentral", "centralindia", "centralus", "eastasia", "eastus2euap", "eastus", "eastus2", "francecentral", "japaneast", "koreacentral", "northcentralus", "northeurope", "norwayeast", "southcentralus", "southeastasia", "switzerlandnorth", "uaenorth", "uksouth", "westcentralus", "westeurope", "westus", "westus2"]
    },
  })

  policy_rule = jsonencode(
    {
      "if" : {
        "allOf" : [
          {
            "field" : "type",
            "equals" : "Microsoft.Compute/virtualMachines"
          },
          {
            "field" : "location",
            "in" : "[parameters('listOfApplicableLocations')]"
          },
          {
            "anyOf" : [
              {
                "allOf" : [
                  {
                    "field" : "Microsoft.Compute/imagePublisher",
                    "equals" : "MicrosoftWindowsServer"
                  },
                  {
                    "field" : "Microsoft.Compute/imageOffer",
                    "equals" : "WindowsServer"
                  },
                  {
                    "anyOf" : [
                      {
                        "field" : "Microsoft.Compute/imageSku",
                        "like" : "2008-R2-SP1*"
                      },
                      {
                        "field" : "Microsoft.Compute/imageSku",
                        "like" : "2012-*"
                      },
                      {
                        "field" : "Microsoft.Compute/imageSku",
                        "like" : "2016-*"
                      },
                      {
                        "field" : "Microsoft.Compute/imageSku",
                        "like" : "2019-*"
                      },
                      {
                        "field" : "Microsoft.Compute/imageSku",
                        "like" : "2022-*"
                      }
                    ]
                  }
                ]
              },
              {
                "allOf" : [
                  {
                    "field" : "Microsoft.Compute/imagePublisher",
                    "equals" : "MicrosoftWindowsServer"
                  },
                  {
                    "field" : "Microsoft.Compute/imageOffer",
                    "equals" : "WindowsServerSemiAnnual"
                  },
                  {
                    "field" : "Microsoft.Compute/imageSKU",
                    "in" : [
                      "Datacenter-Core-1709-smalldisk",
                      "Datacenter-Core-1709-with-Containers-smalldisk",
                      "Datacenter-Core-1803-with-Containers-smalldisk"
                    ]
                  }
                ]
              },
              {
                "allOf" : [
                  {
                    "field" : "Microsoft.Compute/imagePublisher",
                    "equals" : "MicrosoftWindowsServerHPCPack"
                  },
                  {
                    "field" : "Microsoft.Compute/imageOffer",
                    "equals" : "WindowsServerHPCPack"
                  }
                ]
              },
              {
                "allOf" : [
                  {
                    "field" : "Microsoft.Compute/imagePublisher",
                    "equals" : "MicrosoftSQLServer"
                  },
                  {
                    "anyOf" : [
                      {
                        "field" : "Microsoft.Compute/imageOffer",
                        "like" : "*-WS2022"
                      },
                      {
                        "field" : "Microsoft.Compute/imageOffer",
                        "like" : "*-WS2022-BYOL"
                      },
                      {
                        "field" : "Microsoft.Compute/imageOffer",
                        "like" : "*-WS2019"
                      },
                      {
                        "field" : "Microsoft.Compute/imageOffer",
                        "like" : "*-WS2019-BYOL"
                      },
                      {
                        "field" : "Microsoft.Compute/imageOffer",
                        "like" : "*-WS2016"
                      },
                      {
                        "field" : "Microsoft.Compute/imageOffer",
                        "like" : "*-WS2016-BYOL"
                      },
                      {
                        "field" : "Microsoft.Compute/imageOffer",
                        "like" : "*-WS2012R2"
                      },
                      {
                        "field" : "Microsoft.Compute/imageOffer",
                        "like" : "*-WS2012R2-BYOL"
                      }
                    ]
                  }
                ]
              },
              {
                "allOf" : [
                  {
                    "field" : "Microsoft.Compute/imagePublisher",
                    "equals" : "MicrosoftRServer"
                  },
                  {
                    "field" : "Microsoft.Compute/imageOffer",
                    "equals" : "MLServer-WS2016"
                  }
                ]
              },
              {
                "allOf" : [
                  {
                    "field" : "Microsoft.Compute/imagePublisher",
                    "equals" : "MicrosoftVisualStudio"
                  },
                  {
                    "field" : "Microsoft.Compute/imageOffer",
                    "in" : [
                      "VisualStudio",
                      "Windows"
                    ]
                  }
                ]
              },
              {
                "allOf" : [
                  {
                    "field" : "Microsoft.Compute/imagePublisher",
                    "equals" : "MicrosoftDynamicsAX"
                  },
                  {
                    "field" : "Microsoft.Compute/imageOffer",
                    "equals" : "Dynamics"
                  },
                  {
                    "field" : "Microsoft.Compute/imageSKU",
                    "equals" : "Pre-Req-AX7-Onebox-U8"
                  }
                ]
              },
              {
                "allOf" : [
                  {
                    "field" : "Microsoft.Compute/imagePublisher",
                    "equals" : "microsoft-ads"
                  },
                  {
                    "field" : "Microsoft.Compute/imageOffer",
                    "equals" : "windows-data-science-vm"
                  }
                ]
              },
              {
                "allOf" : [
                  {
                    "field" : "Microsoft.Compute/imagePublisher",
                    "equals" : "MicrosoftWindowsDesktop"
                  },
                  {
                    "field" : "Microsoft.Compute/imageOffer",
                    "equals" : "Windows-10"
                  }
                ]
              }
            ]
          }
        ]
      },
      "then" : {
        "effect" : "[parameters('effect')]",
        "details" : {
          "type" : "Microsoft.Compute/virtualMachines/extensions",
          "existenceCondition" : {
            "allOf" : [
              {
                "field" : "Microsoft.Compute/virtualMachines/extensions/type",
                "equals" : "ChangeTracking-Windows"
              },
              {
                "field" : "Microsoft.Compute/virtualMachines/extensions/Publisher",
                "equals" : "Microsoft.Azure.ChangeTrackingAndInventory"
              },
              {
                "field" : "Microsoft.Compute/virtualMachines/extensions/provisioningState",
                "equals" : "Succeeded"
              }
            ]
          }
        }
      }
    }
  )
}


#################### POLICY ASSIGNMENT ####################

resource "azurerm_subscription_policy_assignment" "assign_system_updates_required" {
  name                 = "ChangeTracking extension should be installed on your Windows VM"
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/f85bf3e0-d513-442e-89c3-1784ad63382b"
  subscription_id      = "/subscriptions/${var.subscription_id}"

  parameters = jsonencode({
    effect = {
      value = "AuditIfNotExists"
    }
  })
}