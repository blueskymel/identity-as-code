variable "block_legacy_auth_display_name" {
  description = "Display name for the Conditional Access policy that blocks legacy authentication."
  type        = string
  default     = "CA001-Block-Legacy-Authentication"
}

variable "block_legacy_auth_state" {
  description = "State for the legacy authentication Conditional Access policy."
  type        = string
  default     = "enabled"
}

data "azuread_group" "block_legacy_auth_break_glass" {
  display_name = "grp-ca-exclusion-emergency"
}

resource "azuread_conditional_access_policy" "block_legacy_auth" {
  display_name = var.block_legacy_auth_display_name
  state        = var.block_legacy_auth_state

  conditions {
    client_app_types = [
      "exchangeActiveSync",
      "other"
    ]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = ["All"]
      excluded_groups = [data.azuread_group.block_legacy_auth_break_glass.object_id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}
