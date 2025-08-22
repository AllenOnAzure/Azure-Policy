# Required parameters
resource_group_name         = "orphan-costmonitoring-rg"
location                    = "UK South"
subscription_id             = "<subscriptionID>"
log_analytis_workspace      = "unusedresourcescostoptimization"
data_collection_rule        = "cost-optimization-policy-dcr"
webhook_url                 = "<yourTeamsChannelWebHook>"
user_assigned_identity_name = "orphaned-cost-policy-uami"

