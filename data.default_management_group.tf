########################################################
# The data resource for azurerm_management_group is used
# when a custom "default_management_group" value is
# specified to determine whether any new Subscriptions
# have been added to the Tenant, allowing dynamic
# management of Subscriptions associated with the
# default Management Group.
#
# For more information about default Management Groups
# please refer to: https://bit.ly/39unZCy
#
# Setting a default Management Group is important if
# there are users eligible for MSDN or Visual Studio
# benefits and subscriptions, but also to catch Pay As
# You Go (PAYG) Subscriptions created by users within
# your Tenant.
#
########################################################

locals {
  default_management_group_specified = local.default_management_group == "" ? 0 : 1
  default_management_group_in_module = contains(keys(local.es_landing_zones_merge), local.default_management_group)
}

data "azurerm_management_group" "default" {
  count = local.default_management_group == "" ? 0 : 1

  name = local.default_management_group
}

locals {
  default_management_group_current_subscriptions       = try(data.azurerm_management_group.default.subscription_ids, local.empty_list)
  default_management_group_current_subscriptions_count = length(local.default_management_group_current_subscriptions)

}