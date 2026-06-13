variable "admin_risk_policy_display_name" {
  description = "Display name for the Conditional Access policy that targets privileged roles when sign-in risk is high."
  type        = string
  default     = "CA-Block-High-Risk-Admins"
}

variable "admin_risk_policy_state" {
  description = "State for the privileged role high-risk Conditional Access policy."
  type        = string
  default     = "enabledForReportingButNotEnforced"
}

variable "admin_risk_policy_included_role_ids" {
  description = "Built-in directory role template IDs included in the policy scope."
  type        = list(string)
  default = [
    "62e90394-69f5-4237-9190-012177145e10",
    "194ae4cb-b126-40b2-bd5b-6091b380977d",
    "f28a1f50-f6e7-4571-818b-6a12f2af6b6c",
    "29232cdf-9323-42fd-ade2-1d097af3e4de",
    "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9",
    "729827e3-9c14-49f7-bb1b-9608f156bbb8",
    "b0f54661-2d74-4c50-afa3-1ec803f12efe",
    "fe930be7-5e62-47db-91af-98c3a49a38b1",
    "c4e39bd9-1100-46d3-8c65-fb160da0071f",
    "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3",
    "158c047a-c907-4556-b7ef-446551a6b5f7",
    "966707d0-3269-4727-9be2-8c3a10f19b9d"
  ]
}

data "azuread_group" "admin_risk_policy_break_glass" {
  display_name = "grp-ca-exclusion-emergency"
}

resource "azuread_conditional_access_policy" "admin_risk_policy" {
  display_name = var.admin_risk_policy_display_name
  state        = var.admin_risk_policy_state

  conditions {
    client_app_types    = ["all"]
    sign_in_risk_levels = ["high"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_roles  = var.admin_risk_policy_included_role_ids
      excluded_groups = [data.azuread_group.admin_risk_policy_break_glass.object_id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}
