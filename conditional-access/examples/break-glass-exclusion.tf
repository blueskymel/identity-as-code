variable "break_glass_group_display_name" {
  description = "Display name of the emergency access group excluded from Conditional Access policies."
  type        = string
  default     = "grp-ca-exclusion-emergency"
}

variable "additional_excluded_group_ids" {
  description = "Additional group object IDs to exclude alongside the emergency access group, such as service accounts or BYOD exceptions."
  type        = list(string)
  default     = []
}

data "azuread_group" "conditional_access_break_glass" {
  display_name = var.break_glass_group_display_name
}

locals {
  conditional_access_standard_excluded_group_ids = distinct(concat(
    [data.azuread_group.conditional_access_break_glass.object_id],
    var.additional_excluded_group_ids
  ))
}
