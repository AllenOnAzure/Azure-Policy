
################## DECLARE VARIABLES ##################
/*
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for the resource group"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group for monitoring resources"
  type        = string
}

variable "action_group_name" {
  description = "Name of the Action Group"
  type        = string
}

variable "alert_rule_name" {
  description = "Name of the Activity Log Alert Rule"
  type        = string
}

variable "email_address" {
  description = "Email address to receive service health notifications"
  type        = string
}
*/
################################## RESOURCES ######################

# Create a Resource Group to hold our monitoring resources
resource "azurerm_resource_group" "monitoring" {
  name     = var.resource_group_name
  location = var.location
}

# 1. Create an Action Group to define WHO to notify
resource "azurerm_monitor_action_group" "service_health" {
  name                = var.newActionGroupName
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "SvHealth" # Max 12 chars, displayed in notifications

  # Email Receiver - This is the most common. You can add more (SMS, Webhook, etc.)
  email_receiver {
    name                    = "SendEmailToAdmin"
    email_address           = var.email_address
    use_common_alert_schema = true
  }

  tags = {
    createdBy = "Terraform"
  }
}

# 2. Create the Service Health Activity Log Alert
resource "azurerm_monitor_activity_log_alert" "service_health" {
  name                = var.alertRuleName
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = ["/subscriptions/${var.subscription_id}"] # Monitor this subscription
  description         = "Service Health Alert for all incident types."
  location            = "global"

  # Criteria: Trigger when a Service Health event occurs
  criteria {
    category = "ServiceHealth"
    /*
    # This is the key part. This filter ensures it matches ALL service health incidents.
    # The policy's complex 'existenceCondition' is checking for this exact structure.
    service_health {
      events    = ["Incident", "Maintenance", "Security", "Informational", "ActionRequired", "Retirement"]
      services  = [] # Empty array means "all services"
      locations = [] # Empty array means "all locations"
    }
*/
  }

  # Action: Send the notification to the Action Group we created
  action {
    action_group_id = azurerm_monitor_action_group.service_health.id
  }

  tags = {
    createdBy = "Terraform"
  }

  depends_on = [azurerm_monitor_action_group.service_health]
}