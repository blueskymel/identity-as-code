variable "approval_policy_role_template_id" {
  description = "Template ID of the Entra ID directory role policy to update."
  type        = string
}

variable "approval_policy_approver_object_id" {
  description = "Object ID of the user who must approve role activations."
  type        = string
}

variable "approval_policy_approval_required" {
  description = "Whether approval is required for end-user activation."
  type        = bool
  default     = true
}

locals {
  approval_policy_rule_payload = jsonencode({
    rules = [
      {
        "@odata.type" = "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
        id            = "Approval_EndUser_Assignment"
        setting = {
          isApprovalRequired               = var.approval_policy_approval_required
          isApprovalRequiredForExtension   = false
          isRequestorJustificationRequired = true
          approvalMode                     = "SingleStage"
          approvalStages = [
            {
              approvalStageTimeOutInDays      = 1
              isApproverJustificationRequired = true
              escalationTimeInMinutes         = 0
              isEscalationEnabled             = false
              primaryApprovers = [
                {
                  "@odata.type" = "#microsoft.graph.singleUser"
                  userId        = var.approval_policy_approver_object_id
                }
              ]
            }
          ]
        }
      }
    ]
  })
}

resource "terraform_data" "approval_policy" {
  triggers_replace = [
    var.approval_policy_role_template_id,
    tostring(var.approval_policy_approval_required),
    var.approval_policy_approver_object_id
  ]

  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
    command     = <<-PWSH
      $ErrorActionPreference = "Stop"

      $policyId = az rest `
        --method GET `
        --url "https://graph.microsoft.com/v1.0/policies/roleManagementPolicies?`$filter=scopeId eq '/' and scopeType eq 'DirectoryRole'" `
        --query "value[?contains(id, '${var.approval_policy_role_template_id}')].id | [0]" `
        --output tsv

      if ($LASTEXITCODE -ne 0) {
        throw "Failed to query the directory role management policy for template ID ${var.approval_policy_role_template_id}."
      }

      if (-not $policyId) {
        throw "No directory role management policy found for template ID ${var.approval_policy_role_template_id}."
      }

      $payload = @'
${local.approval_policy_rule_payload}
'@

      az rest `
        --method PATCH `
        --url "https://graph.microsoft.com/v1.0/policies/roleManagementPolicies/$policyId" `
        --headers "Content-Type=application/json" `
        --body $payload

      if ($LASTEXITCODE -ne 0) {
        throw "Failed to update the approval policy on directory role management policy $policyId."
      }
    PWSH
  }
}
