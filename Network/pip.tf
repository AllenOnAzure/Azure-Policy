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

variable "subscription_id_full" {
  description = "Azure Subscription ID"
  type        = string
}
##################   POLICY DEFINITION TAG   ###########################################

resource "azurerm_policy_definition" "deny_public_ip_nics" {
  name         = "deny-public-ip-nics"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Network interfaces should not have public IPs"
  description  = "This policy denies the network interfaces which are configured with any public IP. Public IP addresses allow internet resources to communicate inbound to Azure resources, and Azure resources to communicate outbound to the internet. This should be reviewed by the network security team."

  metadata = jsonencode({
    version  = "1.0.0"
    category = "Network"
  })

  policy_rule = jsonencode({
    "if" = {
      "allOf" = [
        {
          "field"  = "type"
          "equals" = "Microsoft.Network/networkInterfaces"
        },
        {
          "not" = {
            "field"   = "Microsoft.Network/networkInterfaces/ipconfigurations[*].publicIpAddress.id"
            "notLike" = "*"
          }
        }
      ]
    },
    "then" = {
      "effect" = "deny"
    }
  })
}

#################### POLICY ASSIGNMENT AT SUBSCRIPTION SCOPE ######################

resource "azurerm_subscription_policy_assignment" "deny_public_ip_nics" {
  name                 = "deny-public-ip-nics-assignment"
  policy_definition_id = azurerm_policy_definition.deny_public_ip_nics.id
  subscription_id      = var.subscription_id_full

  description  = "Assignment of the 'Network interfaces should not have public IPs' policy"
  display_name = "Network interfaces should not have public IPs"
}
################################################################################