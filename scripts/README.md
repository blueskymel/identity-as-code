# Scripts

This directory contains PowerShell deployment and validation scripts for managing Entra ID identity configuration.

## Script Inventory

| Script | Purpose |
|--------|---------|
| `deploy-ca-policies.ps1` | Deploy Conditional Access policies from JSON templates |
| `deploy-dynamic-groups.ps1` | Deploy dynamic and assigned group definitions |
| `deploy-administrative-units.ps1` | Deploy Administrative Units and scoped role assignments |
| `deploy-role-assignments.ps1` | Deploy tenant-wide and scoped role assignments (including PIM) |
| `validate.ps1` | Validate all JSON template files before deployment |

## Prerequisites

All scripts require:

- **PowerShell 7.x** (`pwsh`)
- **Microsoft Graph PowerShell SDK** modules:
  ```powershell
  Install-Module Microsoft.Graph.Authentication          -Scope CurrentUser
  Install-Module Microsoft.Graph.Identity.SignIns        -Scope CurrentUser
  Install-Module Microsoft.Graph.Groups                  -Scope CurrentUser
  Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
  Install-Module Microsoft.Graph.Identity.Governance     -Scope CurrentUser
  ```
- **Entra ID App Registration or Managed Identity** with the permissions listed below

## Required Graph API Permissions

| Permission | Type | Used By |
|-----------|------|---------|
| `Policy.ReadWrite.ConditionalAccess` | Application | deploy-ca-policies.ps1 |
| `Policy.Read.All` | Application | deploy-ca-policies.ps1 |
| `Group.ReadWrite.All` | Application | deploy-dynamic-groups.ps1 |
| `AdministrativeUnit.ReadWrite.All` | Application | deploy-administrative-units.ps1 |
| `RoleManagement.ReadWrite.Directory` | Application | deploy-role-assignments.ps1 |
| `PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup` | Application | deploy-role-assignments.ps1 |

> **Important:** Use **Managed Identity** for automated pipeline runs. Never store credentials in the pipeline.

## Authentication

All deploy scripts currently authenticate with:

```powershell
Connect-MgGraph -Identity -NoWelcome
```

That means the deploy scripts are intended for pipeline jobs or other managed/federated identity execution contexts.
They do not currently prompt for interactive sign-in.

For local workstation work, use:

- `pwsh scripts/validate.ps1` to validate repository JSON
- the `Invoke-*Template.ps1` loader scripts in the top-level scaffolding folders to inspect baseline templates
- a managed-identity-capable host if you want to execute the deploy scripts without changing them

For placeholder values and pipeline setup, see [`../pipelines/README.md`](../pipelines/README.md).

## Template Handling

- JSON templates are static and are not tokenized during deployment
- Deploy behavior is driven by script parameters and pipeline inputs
- Conditional Access deployments can override state with `-StateOverride`
- Non-prod Conditional Access deployments default to `enabledForReportingButNotEnforced` when no state override is provided

## Local Validation / Template Inspection

```powershell
pwsh scripts/validate.ps1
pwsh ../ConditionalAccess/scripts/Invoke-ConditionalAccessTemplate.ps1
```

## Common Flags

All deploy scripts support:

| Flag | Description |
|------|-------------|
| `-Environment <dev\|staging\|prod>` | Target environment (required) |
| `-WhatIf` | Preview changes without applying them |
| `-PolicyFile/-GroupFile/-AUFile/-AssignmentFile` | Deploy a single file only |

## Managed-Identity Deployment Examples

```bash
# Validate all templates
pwsh scripts/validate.ps1

# Deploy CA policies in report-only mode to dev
pwsh scripts/deploy-ca-policies.ps1 -Environment dev -StateOverride enabledForReportingButNotEnforced -WhatIf

# Deploy everything to dev
pwsh scripts/deploy-ca-policies.ps1           -Environment dev
pwsh scripts/deploy-dynamic-groups.ps1        -Environment dev
pwsh scripts/deploy-administrative-units.ps1  -Environment dev
pwsh scripts/deploy-role-assignments.ps1      -Environment dev
```
