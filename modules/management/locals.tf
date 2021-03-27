# The following block of locals are used to avoid using
# empty object types in the code.
locals {
  empty_list   = []
  empty_map    = {}
  empty_string = ""
}

# Convert the input vars to locals, applying any required
# logic needed before they are used in the module.
# No vars should be referenced elsewhere in the module.
# NOTE: Need to catch error for resource_suffix when
# no value for subscription_id is provided.
locals {
  enabled                                      = var.enabled
  root_id                                      = var.root_id
  subscription_id                              = var.subscription_id
  location                                     = var.location
  tags                                         = var.tags
  resource_prefix                              = coalesce(var.resource_prefix, var.root_id)
  resource_suffix                              = try(coalesce(var.resource_suffix, var.subscription_id), local.empty_string)
  existing_resource_group_name                 = var.existing_resource_group_name
  existing_log_analytics_workspace_resource_id = var.existing_log_analytics_workspace_resource_id
  existing_automation_account_resource_id      = var.existing_automation_account_resource_id
  link_log_analytics_to_automation_account     = var.link_log_analytics_to_automation_account
  custom_settings_by_resource_type             = var.custom_settings_by_resource_type
  settings = {
    log_analytics   = var.settings_log_analytics
    security_center = var.settings_security_center
  }
}

# Extract individual custom settings blocks from
# the custom_settings_by_resource_type variable.
locals {
  custom_settings_rsg               = try(local.custom_settings_by_resource_type.azurerm_resource_group, null)
  custom_settings_la_workspace      = try(local.custom_settings_by_resource_type.azurerm_log_analytics_workspace, null)
  custom_settings_la_solution       = try(local.custom_settings_by_resource_type.azurerm_log_analytics_solution, null)
  custom_settings_aa                = try(local.custom_settings_by_resource_type.azurerm_automation_account, null)
  custom_settings_la_linked_service = try(local.custom_settings_by_resource_type.azurerm_log_analytics_linked_service, null)
}

# Logic to determine whether specific resources
# should be created by this module
locals {
  deploy_monitoring                   = local.enabled && local.settings.log_analytics.enabled
  deploy_resource_group               = local.deploy_monitoring && local.existing_resource_group_name == local.empty_string
  deploy_log_analytics_workspace      = local.deploy_monitoring && local.existing_log_analytics_workspace_resource_id == local.empty_string
  deploy_log_analytics_linked_service = local.deploy_monitoring && local.link_log_analytics_to_automation_account == local.empty_string
  deploy_automation_account           = local.deploy_monitoring && local.existing_automation_account_resource_id == local.empty_string
  deploy_azure_monitor_solutions = {
    AgentHealthAssessment = local.deploy_monitoring && local.settings.log_analytics.config.enable_solution_for_AgentHealthAssessment
    AntiMalware           = local.deploy_monitoring && local.settings.log_analytics.config.enable_solution_for_AntiMalware
    AzureActivity         = local.deploy_monitoring && local.settings.log_analytics.config.enable_solution_for_AzureActivity
    ChangeTracking        = local.deploy_monitoring && local.settings.log_analytics.config.enable_solution_for_ChangeTracking
    Security              = local.deploy_monitoring && local.settings.log_analytics.config.enable_sentinel
    SecurityInsights      = local.deploy_monitoring && local.settings.log_analytics.config.enable_sentinel
    ServiceMap            = local.deploy_monitoring && local.settings.log_analytics.config.enable_solution_for_ServiceMap
    SQLAssessment         = local.deploy_monitoring && local.settings.log_analytics.config.enable_solution_for_SQLAssessment
    Updates               = local.deploy_monitoring && local.settings.log_analytics.config.enable_solution_for_Updates
    VMInsights            = local.deploy_monitoring && local.settings.log_analytics.config.enable_solution_for_VMInsights
  }
  deploy_security             = local.enabled && local.settings.security_center.enabled
  deploy_asc_for_acr          = local.deploy_security && local.settings.security_center.config.enable_asc_for_acr
  deploy_asc_for_app_services = local.deploy_security && local.settings.security_center.config.enable_asc_for_app_services
  deploy_asc_for_arm          = local.deploy_security && local.settings.security_center.config.enable_asc_for_arm
  deploy_asc_for_dns          = local.deploy_security && local.settings.security_center.config.enable_asc_for_dns
  deploy_asc_for_key_vault    = local.deploy_security && local.settings.security_center.config.enable_asc_for_key_vault
  deploy_asc_for_kubernetes   = local.deploy_security && local.settings.security_center.config.enable_asc_for_kubernetes
  deploy_asc_for_servers      = local.deploy_security && local.settings.security_center.config.enable_asc_for_servers
  deploy_asc_for_sql          = local.deploy_security && local.settings.security_center.config.enable_asc_for_sql
  deploy_asc_for_storage      = local.deploy_security && local.settings.security_center.config.enable_asc_for_storage
}

# Configuration settings for resource type:
#  - Azure Security Center Standard


# Configuration settings for resource type:
#  - azurerm_resource_group
locals {
  resource_group_name = coalesce(
    local.existing_resource_group_name,
    try(local.custom_settings_rsg.name, null),
    "${local.resource_prefix}-mgmt",
  )
  resource_group_resource_id = "/subscriptions/${local.subscription_id}/resourceGroups/${local.resource_group_name}"
  azurerm_resource_group = {
    name     = local.resource_group_name,
    location = try(local.custom_settings_rsg.location, local.location)
    tags     = try(local.custom_settings_rsg.tags, local.tags)
  }
}


# Configuration settings for resource type:
#  - azurerm_log_analytics_workspace
locals {
  log_analytics_workspace_resource_id = coalesce(
    local.existing_log_analytics_workspace_resource_id,
    "${local.resource_group_resource_id}/providers/Microsoft.OperationalInsights/workspaces/${local.azurerm_log_analytics_workspace.name}"
  )
  azurerm_log_analytics_workspace = {
    name                              = try(local.custom_settings_la_workspace.name, "${local.resource_prefix}-la-${local.resource_suffix}")
    location                          = try(local.custom_settings_la_workspace.location, local.location)
    sku                               = try(local.custom_settings_la_workspace.sku, "PerGB2018")
    retention_in_days                 = try(local.custom_settings_la_workspace.retention_in_days, 30)
    daily_quota_gb                    = try(local.custom_settings_la_workspace.daily_quota_gb, null)
    internet_ingestion_enabled        = try(local.custom_settings_la_workspace.internet_ingestion_enabled, true)
    internet_query_enabled            = try(local.custom_settings_la_workspace.internet_query_enabled, true)
    reservation_capcity_in_gb_per_day = try(local.custom_settings_la_workspace.reservation_capcity_in_gb_per_day, null)
    tags                              = try(local.custom_settings_la_workspace.tags, local.tags)
    resource_group_name = coalesce(
      try(local.custom_settings_la_workspace.resource_group_name, null),
      local.resource_group_name,
    )
  }
}

# Configuration settings for resource type:
#  - azurerm_log_analytics_solution
locals {
  log_analytics_solution_resource_id = {
    for resource in local.azurerm_log_analytics_solution :
    resource.solution_name => "${local.resource_group_resource_id}/providers/Microsoft.OperationsManagement/solutions/${resource.solution_name}"
  }
  azurerm_log_analytics_solution = [
    for solution_name, solution_enabled in local.deploy_azure_monitor_solutions :
    {
      solution_name         = "${solution_name}(${local.resource_suffix})"
      location              = try(local.custom_settings_la_solution.location, local.location)
      workspace_resource_id = local.log_analytics_workspace_resource_id
      workspace_name        = basename(local.log_analytics_workspace_resource_id)
      tags                  = try(local.custom_settings_la_solution.tags, local.tags)
      plan = {
        publisher = "Microsoft"
        product   = "OMSGallery/${solution_name}"
      }
      resource_group_name = coalesce(
        try(local.custom_settings_la_solution.resource_group_name, null),
        local.resource_group_name,
      )
    }
    if(solution_name != "disable_all") && (solution_enabled == true) && !(try(local.deploy_azure_monitor_solutions.disable_all, false))
  ]
}

# Configuration settings for resource type:
#  - azurerm_automation_account
locals {
  automation_account_resource_id = coalesce(
    local.existing_automation_account_resource_id,
    "${local.resource_group_resource_id}/providers/Microsoft.Automation/automationAccounts/${local.azurerm_automation_account.name}"
  )
  azurerm_automation_account = {
    name     = try(local.custom_settings_aa.name, "${local.resource_prefix}-a-${local.resource_suffix}")
    location = try(local.custom_settings_aa.location, local.location)
    sku_name = try(local.custom_settings_aa.sku_name, "Basic")
    tags     = try(local.custom_settings_aa.tags, local.tags)
    resource_group_name = coalesce(
      try(local.custom_settings_aa.resource_group_name, null),
      local.resource_group_name,
    )
  }
}

# Configuration settings for resource type:
#  - azurerm_log_analytics_linked_service
locals {
  log_analytics_linked_service_resource_id = "${local.log_analytics_workspace_resource_id}/linkedServices/Automation"
  azurerm_log_analytics_linked_service = {
    workspace_id    = try(local.custom_settings_la_linked_service.workspace_id, local.log_analytics_workspace_resource_id)
    read_access_id  = try(local.custom_settings_la_linked_service.read_access_id, local.automation_account_resource_id) # This should be used for linking to an Automation Account resource.
    write_access_id = null                                                                                              # DO NOT USE. This should be used for linking to a Log Analytics Cluster resource
    resource_group_name = coalesce(
      try(local.custom_settings_la_linked_service.resource_group_name, null),
      local.resource_group_name,
    )
  }
}

# Generate the configuration output object for the management module
locals {
  resources_output = {
    azurerm_resource_group = [
      {
        resource_id   = local.resource_group_resource_id
        resource_name = basename(local.resource_group_resource_id)
        template = {
          for key, value in local.azurerm_resource_group :
          key => value
          if local.deploy_resource_group
        }
        managed_by_module = local.deploy_resource_group
      },
    ]
    azurerm_log_analytics_workspace = [
      {
        resource_id   = local.log_analytics_workspace_resource_id
        resource_name = basename(local.log_analytics_workspace_resource_id)
        template = {
          for key, value in local.azurerm_log_analytics_workspace :
          key => value
          if local.deploy_log_analytics_workspace
        }
        managed_by_module = local.deploy_log_analytics_workspace
      },
    ]
    azurerm_log_analytics_solution = [
      for resource in local.azurerm_log_analytics_solution :
      {
        resource_id       = local.log_analytics_solution_resource_id[resource.solution_name]
        resource_name     = basename(local.log_analytics_solution_resource_id[resource.solution_name])
        template          = resource
        managed_by_module = true
      }
    ]
    azurerm_automation_account = [
      {
        resource_id   = local.automation_account_resource_id
        resource_name = basename(local.automation_account_resource_id)
        template = {
          for key, value in local.azurerm_automation_account :
          key => value
          if local.deploy_automation_account
        }
        managed_by_module = local.deploy_automation_account
      },
    ]
    azurerm_log_analytics_linked_service = [
      {
        resource_id   = local.log_analytics_linked_service_resource_id
        resource_name = basename(local.log_analytics_linked_service_resource_id)
        template = {
          for key, value in local.azurerm_log_analytics_linked_service :
          key => value
          if local.deploy_log_analytics_linked_service
        }
        managed_by_module = local.deploy_log_analytics_linked_service
      },
    ]
  }
}
