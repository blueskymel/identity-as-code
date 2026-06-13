variable "eligible_admin_principal_upn" {
  description = "User principal name of the admin who should receive an eligible assignment."
  type        = string
}

variable "eligible_admin_role_display_name" {
  description = "Display name of the built-in Entra ID directory role to make eligible."
  type        = string
  default     = "Global Reader"
}

variable "eligible_admin_directory_scope_id" {
  description = "Directory scope for the assignment. Use / for tenant-wide scope or an administrative unit object ID."
  type        = string
  default     = "/"
}

variable "eligible_admin_justification" {
  description = "Business justification recorded on the eligibility schedule request."
  type        = string
  default     = "PIM eligible admin assignment managed as code."
}

data "azuread_user" "eligible_admin_principal" {
  user_principal_name = var.eligible_admin_principal_upn
}

resource "azuread_directory_role" "eligible_admin_role" {
  display_name = var.eligible_admin_role_display_name
}

resource "azuread_directory_role_eligibility_schedule_request" "eligible_admin" {
  role_definition_id = azuread_directory_role.eligible_admin_role.template_id
  principal_id       = data.azuread_user.eligible_admin_principal.object_id
  directory_scope_id = var.eligible_admin_directory_scope_id
  justification      = var.eligible_admin_justification
}
