# PIM

Baseline assets:
- `templates/pim-role-policy.template.json`
- `scripts/Invoke-PimTemplate.ps1`

Terraform automation examples:
- `examples/eligible-admin.tf`
- `examples/approval-policy.tf`
- `examples/activation-duration.tf`

Notes:
- `eligible-admin.tf` shows a native `azuread_directory_role_eligibility_schedule_request` example for an eligible Entra ID directory role assignment.
- `approval-policy.tf` and `activation-duration.tf` show `terraform_data` + `az rest` examples because the AzureAD provider does not currently expose a Terraform resource for Entra ID directory role management policy rules.
- The examples are intended to be copied into a Terraform module that already has provider configuration and Microsoft Graph / Azure CLI authentication in place.
