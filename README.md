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

### Deploy to Dev (Report-Only / WhatIf)

```bash
# Connect to Entra ID interactively
Connect-MgGraph -Scopes "Policy.ReadWrite.ConditionalAccess","Group.ReadWrite.All","RoleManagement.ReadWrite.Directory"

# Validate all templates
pwsh scripts/validate.ps1

# Deploy CA policies in report-only mode (safe preview)
pwsh scripts/deploy-ca-policies.ps1 -Environment dev -StateOverride enabledForReportingButNotEnforced

# Deploy dynamic groups
pwsh scripts/deploy-dynamic-groups.ps1 -Environment dev

# Deploy Administrative Units
pwsh scripts/deploy-administrative-units.ps1 -Environment dev

# Deploy role assignments
pwsh scripts/deploy-role-assignments.ps1 -Environment dev
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

### Azure DevOps

An equivalent pipeline is available at [`pipelines/azure-devops.yml`](pipelines/azure-devops.yml).

### Hybrid Delivery Model

This repository is evolving toward a hybrid model:

- **Terraform** for declarative identity/platform controls where provider support is strong.
- **Graph PowerShell** for operational identity workflows (for example PIM operations and emergency tasks).
- **Pipelines** enforce JSON + Terraform validation before deployment.

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
