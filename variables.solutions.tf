# The following variables are used to configure the bundled
# Enterprise-scale Solutions.
#
# Further information provided within the description block
# for each variable

variable "management_config" {
  type = map(
    object({
      subscription_id = string
      log_analytics_workspace = object({
        name                     = string
        resource_group           = string
        is_existing              = bool
        log_retention_in_days    = number
        enable_agent_health      = bool
        enable_change_tracking   = bool
        enable_update_management = bool
        enable_activity_log      = bool
        enable_vm_insights       = bool
        enable_antimalware       = bool
        enable_service_map       = bool
        enable_sql_assessment    = bool
        enable_security_center   = bool
        enable_azure_defender    = bool
        enable_azure_sentinel    = bool
      })
    })
  )
  description = "OPTIONAL: If specified, used to control deployment and configuration of Enterprise-scale management resources."
  default     = {}
}
