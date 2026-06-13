# identity-as-code

> **Enterprise Microsoft Entra ID (Azure AD) configuration managed as code.**
> Treat your identity security posture the same way you treat infrastructure — version-controlled, peer-reviewed, automatically deployed, and always rollback-able.

---

## Overview

This repository implements a full **Identity-as-Code** pattern for Microsoft Entra ID. Every security control, group, and role assignment is defined in JSON, deployed by an automated pipeline, and can be rolled back within minutes.

### What's in this repo?

| Module | Description |
|--------|-------------|
| [`conditional-access/`](conditional-access/README.md) | Conditional Access policy templates (8 policies covering Zero Trust fundamentals) |
| [`dynamic-groups/`](dynamic-groups/README.md) | Dynamic and assigned group definitions |
| [`administrative-units/`](administrative-units/README.md) | Administrative Unit definitions for scoped delegation |
| [`role-assignments/`](role-assignments/README.md) | Directory role assignments including PIM eligible assignments |
| [`terraform/`](terraform/README.md) | Terraform foundation for declarative identity and platform controls |
| [`scripts/`](scripts/README.md) | PowerShell deployment and validation scripts |
| [`rollback/`](rollback/README.md) | Rollback scripts and instructions |
| [`ConditionalAccess/`](ConditionalAccess/README.md) | Baseline template + script scaffolding for Conditional Access automation |
| [`AppRegistrations/`](AppRegistrations/README.md) | Baseline app registration template and loader script |
| [`EnterpriseApps/`](EnterpriseApps/README.md) | Baseline enterprise app assignment template and loader script |
| [`PIM/`](PIM/README.md) | Baseline PIM role policy template and loader script |
| [`AccessReviews/`](AccessReviews/README.md) | Baseline access review template and loader script |
| [`LifecycleWorkflows/`](LifecycleWorkflows/README.md) | Baseline lifecycle workflow template and loader script |
| [`tenant-transitions/`](tenant-transitions/README.md) | Identity consolidation/separation templates and transition workflow guidance |
| [`identity-testing/`](identity-testing/) | Playwright-based sign-in, SSO, RBAC, and MFA validation assets |
| [`msol-tenant-settings/`](msol-tenant-settings/README.md) | Legacy MSOnline tenant/domain/federation settings command examples |
| [`.github/workflows/`](.github/workflows/) | GitHub Actions CI/CD pipelines |
| [`pipelines/`](pipelines/) | Azure DevOps pipeline YAML |

---

## Security Architecture

This repo follows the **Microsoft Zero Trust** and **NIST SP 800-207** principles:

```
Verify explicitly → Use least privilege → Assume breach
```

### Conditional Access Coverage

```
┌─────────────────────────────────────────────────────────────┐
│                      All Sign-Ins                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Block legacy auth (CA001)                           │  │
│  │  Require MFA — all users (CA002)                     │  │
│  │  Require MFA — admins, phishing-resistant (CA003)    │  │
│  │  Require compliant device (CA004)                    │  │
│  │  Block high-risk sign-ins (CA005)                    │  │
│  │  Require MFA — Azure Management (CA006)              │  │
│  │  Session controls: frequency + no persistent (CA007) │  │
│  │  Require MFA + pwd change for risky users (CA008)    │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Privileged Access Architecture

```
Global Admin (PIM eligible, approval required)
├── Security Admin (PIM eligible, approval required)
│   └── CA Admin (PIM eligible, self-approve)
└── User Admin (scoped to regional AU, permanent)
    ├── au-regional-emea  → grp-regional-it-emea
    └── au-regional-amer  → grp-regional-it-amer

Helpdesk Admin (scoped to au-helpdesk, permanent)
└── au-helpdesk  → grp-helpdesk-tier1
```

---

## Getting Started

### Prerequisites

- PowerShell 7.x (`pwsh`)
- Microsoft Graph PowerShell SDK
- Azure CLI (for OIDC authentication in pipelines)
- Entra ID tenant with P1 (minimum) or P2 (for Identity Protection policies) licensing

### Install PowerShell Modules

```powershell
Install-Module Microsoft.Graph.Authentication               -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.SignIns             -Scope CurrentUser
Install-Module Microsoft.Graph.Groups                       -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.Governance          -Scope CurrentUser
```

### Quick Start — Validate Templates Locally

```bash
git clone https://github.com/blueskymel/identity-as-code
cd identity-as-code
pwsh scripts/validate.ps1
```

### Inspect Baseline Templates Locally

```bash
# Load the baseline template scaffolding files
pwsh ConditionalAccess/scripts/Invoke-ConditionalAccessTemplate.ps1
pwsh AppRegistrations/scripts/Invoke-AppRegistrationTemplate.ps1
pwsh EnterpriseApps/scripts/Invoke-EnterpriseAppTemplate.ps1
pwsh PIM/scripts/Invoke-PimTemplate.ps1
pwsh AccessReviews/scripts/Invoke-AccessReviewTemplate.ps1
pwsh LifecycleWorkflows/scripts/Invoke-LifecycleWorkflowTemplate.ps1
pwsh tenant-transitions/scripts/Invoke-TenantTransitionTemplate.ps1
```

### Deploy from a Managed Identity / Pipeline Context

The deploy scripts in [`scripts/`](scripts/README.md) are pipeline-oriented and authenticate with `Connect-MgGraph -Identity`.
Run them from a GitHub Actions job, Azure DevOps job, or another host that has the required managed or federated identity context.

```bash
# Validate all templates
pwsh scripts/validate.ps1

# Deploy CA policies to dev in report-only mode
pwsh scripts/deploy-ca-policies.ps1 -Environment dev -StateOverride enabledForReportingButNotEnforced -WhatIf

# Deploy the remaining resource types
pwsh scripts/deploy-dynamic-groups.ps1 -Environment dev -WhatIf
pwsh scripts/deploy-administrative-units.ps1 -Environment dev -WhatIf
pwsh scripts/deploy-role-assignments.ps1 -Environment dev -WhatIf
```

---

## Pipeline

### GitHub Actions

Three workflows are provided:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| [`validate.yml`](.github/workflows/validate.yml) | PR / push | Validates all JSON templates |
| [`deploy.yml`](.github/workflows/deploy.yml) | Push to `main` / manual | Deploys via dev → staging → prod with approval gates |
| [`rollback.yml`](.github/workflows/rollback.yml) | Manual only | Rolls back any resource in any environment |

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AZURE_TENANT_ID` | Entra ID tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |
| `AZURE_CLIENT_ID_DEV` | Managed Identity / App Registration client ID for dev |
| `AZURE_CLIENT_ID_STAGING` | Client ID for staging |
| `AZURE_CLIENT_ID_PROD` | Client ID for prod |

> Configure OIDC workload identity federation — never store client secrets in GitHub.

Use [`pipelines/github-actions.secrets.example.env`](pipelines/github-actions.secrets.example.env) as a placeholder checklist for the values you still need to fill in.

### Azure DevOps

An equivalent pipeline is available at [`pipelines/azure-devops.yml`](pipelines/azure-devops.yml).
The current YAML expects:

- Azure DevOps environments named `dev`, `staging`, and `prod`
- service connections named `identity-as-code-dev`, `identity-as-code-staging`, and `identity-as-code-prod`
- variable groups named `identity-as-code-dev`, `identity-as-code-staging`, and `identity-as-code-prod`

Use [`pipelines/azure-devops.variable-group.example.env`](pipelines/azure-devops.variable-group.example.env) as a placeholder template for the variable groups.

### Full Pipeline Setup Reference

For end-to-end documentation of:

- required GitHub secrets
- Azure DevOps service connections and variable groups
- workflow inputs (`environment`, `resource`, `whatif`)
- how templates are loaded and deployed
- which scripts are loader utilities versus deploy entrypoints

see [`pipelines/README.md`](pipelines/README.md).

### How Templates and Scripts Handle Variables

- JSON templates in this repository are **static files**. They do not use token replacement, environment-variable substitution, or placeholder expansion during deployment.
- Runtime behavior is controlled by **pipeline inputs** and **script parameters**, especially `-Environment`, `-WhatIf`, and the CA-specific `-StateOverride`.
- For Conditional Access, non-production deployments default to `enabledForReportingButNotEnforced` unless you explicitly override the state.
- The `Invoke-*Template.ps1` scripts in the top-level scaffolding folders load and echo template JSON for inspection; they are not the main deployment entrypoints used by the pipelines.

### Hybrid Delivery Model
 
This repository is evolving toward a hybrid model:
 
- **Terraform** for declarative identity/platform controls where provider support is strong.
- **Graph PowerShell** for operational identity workflows (for example PIM operations and emergency tasks).
- **Pipelines** enforce JSON + Terraform validation before deployment.
 
---
 
## Identity Consolidation and Separation Projects
 
This repository also fits **tenant-to-tenant transition work** during mergers, acquisitions, and divestitures.
 
### Identity consolidation
 
When companies merge, start by inventorying the current tenant and mapping what must move without breaking access:
 
1. **Review current tenant structure** to inventory users, groups, and applications.
  ```powershell
  Get-MgUser -All | Export-Csv .\users.csv -NoTypeInformation
  Get-MgGroup -All | Export-Csv .\groups.csv -NoTypeInformation
  Get-MgApplication -All | Export-Csv .\applications.csv -NoTypeInformation
  ```
2. **Export group memberships** so you know who currently has access.
  ```powershell
  Get-MgGroup -All | ForEach-Object {
    $group = $_
    Get-MgGroupMember -GroupId $group.Id -All |
      Select-Object @{Name='GroupId';Expression={$group.Id}},
                    @{Name='GroupDisplayName';Expression={$group.DisplayName}},
                    Id
  } | Export-Csv .\group-memberships.csv -NoTypeInformation
  ```
3. **Map identities** where the same person may exist in both tenants. Preserve mailbox access, Teams access, SharePoint access, app permissions, and group memberships.
4. **Migrate identities safely** by creating the user in the target tenant and reapplying equivalent access with Terraform or Graph API.
  ```hcl
  data "azuread_group" "target_group" {
    display_name = "grp-example"
  }
   
  data "azuread_user" "target_user" {
    user_principal_name = "user@contoso.com"
  }
   
  resource "azuread_group_member" {
   group_id         = data.azuread_group.target_group.id
   member_object_id = data.azuread_user.target_user.id
  }
  ```
5. **Test SSO applications** end to end, including login flows plus SAML, OAuth, and OpenID Connect integrations.
 
### Separation project
 
When a business unit is sold or carved out, the goal is to move identities **out of the current tenant** without leaving residual access behind.
 
1. **Remove access** from the source tenant.
2. **Create the new tenant landing zone** for the divested business unit.
3. **Migrate applications** and enterprise app assignments.
4. **Migrate permissions** and group memberships.
5. **Validate security boundaries** so no access leaks remain.
 
These projects usually combine the repository's declarative controls with Graph-driven discovery and validation so access can be re-created consistently and reviewed before cutover.
 
---
 
## Emergency Procedures

### Break-Glass Accounts

Break-glass accounts are excluded from ALL Conditional Access policies via `grp-ca-exclusion-emergency`.

| Requirement | Detail |
|-------------|--------|
| Account type | Cloud-only (not synced from on-prem AD) |
| Password | 60+ character random string, stored in a separate vault |
| MFA | Not enrolled (would defeat the break-glass purpose) |
| Monitoring | Alert on any sign-in from these accounts |
| Testing | Verify access quarterly (don't wait for an emergency) |
| Count | Minimum 2, maximum 4 |

### Emergency Rollback

```bash
# Disable all CA policies immediately
pwsh rollback/scripts/rollback-ca-policies.ps1 -DisableOnly

# Or trigger from GitHub Actions (no local access needed)
gh workflow run rollback.yml \
  -f environment=prod \
  -f resource=ca-policies \
  -f reason="Emergency: tenant lockout detected" \
  -f whatif=false
```

---

## Contributing

1. Fork or branch from `main`
2. Make changes to JSON templates or scripts
3. Run `pwsh scripts/validate.ps1` locally — must pass before opening a PR
4. Open a PR — the validation workflow runs automatically
5. Get peer review from at least one other identity team member
6. Merge to `main` — deployment starts automatically

### Naming Conventions

| Resource | Convention | Example |
|----------|------------|---------|
| CA policies | `CA<NNN>-Description` | `CA001-Block-Legacy-Authentication` |
| Groups | `grp-<purpose>-<scope>` | `grp-dept-finance` |
| Admin Units | `au-<purpose>` | `au-regional-emea` |
| Policy files | `<NNN>-kebab-case.json` | `001-block-legacy-auth.json` |

---

## License

MIT — see [LICENSE](LICENSE).

## References

- [Microsoft Zero Trust Guidance](https://learn.microsoft.com/en-us/security/zero-trust/)
- [Conditional Access: Policies and concepts](https://learn.microsoft.com/en-us/entra/identity/conditional-access/)
- [Privileged Identity Management](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/)
- [Microsoft Entra ID security operations guide](https://learn.microsoft.com/en-us/entra/architecture/security-operations-introduction)
- [Administrative Units in Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/administrative-units)
- [NIST SP 800-207 Zero Trust Architecture](https://csrc.nist.gov/publications/detail/sp/800-207/final)
