# identity-as-code

Identity-as-code repository for Microsoft Entra ID governance and access management configurations.

## Coverage

The following areas are now explicitly covered in this repository:

- ConditionalAccess
- AppRegistrations
- EnterpriseApps
- PIM
- AccessReviews
- LifecycleWorkflows

Each area includes:
- `templates/` for baseline JSON templates
- `scripts/` for local PowerShell processing helpers

## Validate templates

Run:

`pwsh ./scripts/validate.ps1`
