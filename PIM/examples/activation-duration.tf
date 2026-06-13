variable "activation_duration_role_template_id" {
  description = "Template ID of the Entra ID directory role policy to update."
  type        = string
}

variable "activation_duration_maximum_duration" {
  description = "ISO 8601 duration for the maximum activation duration, for example PT8H."
  type        = string
  default     = "PT8H"
}

locals {
  activation_duration_rule_payload = jsonencode({
    rules = [
      {
        "@odata.type"        = "#microsoft.graph.unifiedRoleManagementPolicyExpirationRule"
        id                   = "Expiration_EndUser_Assignment"
        isExpirationRequired = true
        maximumDuration      = var.activation_duration_maximum_duration
      }
    ]
  })
}

resource "terraform_data" "activation_duration" {
  triggers_replace = [
    var.activation_duration_role_template_id,
    var.activation_duration_maximum_duration
  ]

  provisioner "local-exec" {
    interpreter = ["pwsh", "-Command"]
    command     = <<-PWSH
      $ErrorActionPreference = "Stop"

      $policyId = az rest `
        --method GET `
        --url "https://graph.microsoft.com/v1.0/policies/roleManagementPolicies?`$filter=scopeId eq '/' and scopeType eq 'DirectoryRole'" `
        --query "value[?contains(id, '${var.activation_duration_role_template_id}')].id | [0]" `
        --output tsv

      if ($LASTEXITCODE -ne 0) {
        throw "Failed to query the directory role management policy for template ID ${var.activation_duration_role_template_id}."
      }

      if (-not $policyId) {
        throw "No directory role management policy found for template ID ${var.activation_duration_role_template_id}."
      }

      $payload = @'
${local.activation_duration_rule_payload}
'@

      az rest `
        --method PATCH `
        --url "https://graph.microsoft.com/v1.0/policies/roleManagementPolicies/$policyId" `
        --headers "Content-Type=application/json" `
        --body $payload

      if ($LASTEXITCODE -ne 0) {
        throw "Failed to update the activation duration policy on directory role management policy $policyId."
      }
    PWSH
  }
}
