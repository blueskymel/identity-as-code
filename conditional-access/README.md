# Conditional Access Policies

This directory contains Conditional Access (CA) policy templates in JSON format, targeting Microsoft Entra ID (Azure AD).
Policies are managed as code and deployed via the automated pipeline.

## Policy Inventory

| # | Policy Name | Description | State | License |
|---|-------------|-------------|-------|---------|
| 001 | Block-Legacy-Authentication | Blocks all legacy auth protocols (EAS, IMAP, POP3, SMTP Auth, etc.) | Enabled | P1 |
| 002 | Require-MFA-All-Users | Enforces MFA for every user sign-in to any cloud app | Enabled | P1 |
| 003 | Require-MFA-Admins | Enforces phishing-resistant MFA for all privileged roles | Enabled | P1 |
| 004 | Require-Compliant-Device | Blocks unmanaged devices from accessing corporate apps | Report-Only → Enabled | P1 |
| 005 | Block-Risky-Sign-Ins | Blocks sign-ins rated High risk by Identity Protection | Enabled | P2 |
| 006 | Require-MFA-Azure-Management | Enforces MFA for Azure portal, CLI, and PowerShell | Enabled | P1 |
| 007 | Session-Controls | Sets sign-in frequency and disables persistent browser sessions | Enabled | P1 |
| 008 | Require-MFA-Risky-Users | Requires MFA + password change for medium/high-risk users | Enabled | P2 |

## Exclusion Groups

Every policy excludes the following groups to prevent lockouts:

| Group Name | Purpose |
|------------|---------|
| `grp-ca-exclusion-emergency` | Break-glass / emergency access accounts — see [NIST SP 800-53 IA-2](https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final) |
| `grp-ca-exclusion-service-accounts` | Cloud-only service accounts using certificate-based auth |
| `grp-ca-exclusion-byod` | BYOD users pending device enrollment (policy 004 only) |

> **Important:** Emergency access accounts must be cloud-only, password-based,
> documented, monitored, and tested quarterly per Microsoft best practices.

## Deployment Order

Policies must be deployed in order to avoid conflicting states:
1. Deploy `001-block-legacy-auth` first (lowest risk)
2. Deploy `002-require-mfa-all-users` (validate with report-only first)
3. Deploy `003-require-mfa-admins`
4. Deploy `006-require-mfa-azure-management`
5. Deploy `007-session-controls`
6. Deploy `004-require-compliant-device` (start in report-only mode)
7. Deploy `005-block-risky-sign-ins` (requires P2)
8. Deploy `008-require-mfa-risky-users` (requires P2)

## Policy Schema

Each policy file follows this structure:

```json
{
  "policyName": "CA00X-Policy-Name",
  "description": "Human-readable description",
  "version": "1.0.0",
  "policy": { ... },       // Microsoft Graph API ConditionalAccessPolicy body
  "rollback": { ... }      // Rollback metadata
}
```

## Deploying

```bash
# Deploy all policies
pwsh scripts/deploy-ca-policies.ps1 -Environment prod -WhatIf

# Deploy single policy
pwsh scripts/deploy-ca-policies.ps1 -Environment prod -PolicyFile conditional-access/policies/001-block-legacy-auth.json
```

## Rollback

```bash
pwsh rollback/scripts/rollback-ca-policies.ps1 -PolicyName CA001-Block-Legacy-Authentication
```

## Terraform Automation Examples

- `examples/require-mfa-external.tf`
- `examples/block-legacy-auth.tf`
- `examples/break-glass-exclusion.tf`
- `examples/admin-risk-policy.tf`

Notes:
- The examples are intended to be copied into a Terraform module that already has provider configuration and Microsoft Graph authentication in place.
- `break-glass-exclusion.tf` centralizes the standard emergency access exclusion so policy examples can reuse the same group ID list.
- `admin-risk-policy.tf` demonstrates a P2-only high-risk admin control by combining the repository's privileged role scope with sign-in risk conditions.

## References

- [Microsoft Conditional Access documentation](https://learn.microsoft.com/en-us/entra/identity/conditional-access/)
- [Microsoft Graph API – Conditional Access Policies](https://learn.microsoft.com/en-us/graph/api/resources/conditionalaccesspolicy)
- [Microsoft Zero Trust Guidance](https://learn.microsoft.com/en-us/security/zero-trust/)
