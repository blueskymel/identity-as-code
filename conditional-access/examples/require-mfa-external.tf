variable "external_mfa_display_name" {
  description = "Display name for the Conditional Access policy that requires MFA for external users."
  type        = string
  default     = "CA-Require-MFA-External-Users"
}

variable "external_mfa_state" {
  description = "State for the external user MFA Conditional Access policy."
  type        = string
  default     = "enabledForReportingButNotEnforced"
}

variable "external_mfa_guest_or_external_user_types" {
  description = "External identity types in scope for the policy."
  type        = list(string)
  default = [
    "b2bCollaborationGuest",
    "b2bCollaborationMember",
    "internalGuest",
    "otherExternalUser",
    "serviceProvider"
  ]
}

data "azuread_group" "require_mfa_external_break_glass" {
  display_name = "grp-ca-exclusion-emergency"
}

resource "azuread_conditional_access_policy" "require_mfa_external" {
  display_name = var.external_mfa_display_name
  state        = var.external_mfa_state

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      excluded_groups = [data.azuread_group.require_mfa_external_break_glass.object_id]

      included_guests_or_external_users {
        guest_or_external_user_types = var.external_mfa_guest_or_external_user_types

        external_tenants {
          membership_kind = "all"
        }
      }
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}
