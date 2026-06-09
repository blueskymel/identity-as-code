# Role Assignments

This directory contains Entra ID role assignment definitions managed as code.
Role assignments are expressed as JSON and deployed via Microsoft Graph API using PowerShell scripts.

## Design Principles

1. **Zero Permanent Privileged Assignments** – All privileged roles use PIM (eligible assignments). Only break-glass accounts have permanent active assignments.
2. **Least Privilege** – Use the most specific role available (e.g., Conditional Access Administrator instead of Security Administrator).
3. **Scoped Delegation** – Use Administrative Units to scope helpdesk and regional admin roles.
4. **Group-Based PIM** – Assign eligibility to groups rather than individuals for easier lifecycle management.

## Assignment Inventory

| File | Role | Mode | Scope |
|------|------|------|-------|
| `global-admins.json` | Global Administrator | Active (break-glass only) + PIM eligible | Tenant |
| `security-admins.json` | Security Administrator | PIM eligible | Tenant |
| `conditional-access-admins.json` | Conditional Access Administrator | PIM eligible | Tenant |
| `helpdesk-admins.json` | Helpdesk Administrator | Active | au-helpdesk |
| `user-admins.json` | User Administrator | Active | au-regional-emea, au-regional-amer |

## Role Reference (Well-Known Role Template IDs)

| Role Name | Template ID |
|-----------|-------------|
| Global Administrator | `62e90394-69f5-4237-9190-012177145e10` |
| Security Administrator | `194ae4cb-b126-40b2-bd5b-6091b380977d` |
| Compliance Administrator | `17315797-102d-40b4-93e0-432062caca18` |
| Conditional Access Administrator | `b1be1c3e-b65d-4f19-8427-f6fa0d97feb9` |
| User Administrator | `fe930be7-5e62-47db-91af-98c3a49a38b1` |
| Helpdesk Administrator | `729827e3-9c14-49f7-bb1b-9608f156bbb8` |
| Privileged Role Administrator | `e8611ab8-c189-46e8-94e1-60213ab1f814` |
| Security Reader | `5d6b6bb7-de71-4623-b4af-96380a352509` |
| Global Reader | `f2ef992c-3afb-46b9-b7cf-a126ee74c451` |

## Assignment Schema

```json
{
  "assignmentName": "role-name",
  "description": "...",
  "version": "1.0.0",
  "role": {
    "displayName": "Role Display Name",
    "templateId": "GUID"
  },
  "assignments": [ ... ],          // Permanent active (break-glass only)
  "eligibleAssignments": [ ... ],  // PIM eligible
  "scopedAssignments": [ ... ],    // AU-scoped active assignments
  "pimSettings": { ... }           // PIM policy settings
}
```

## Deploying

```bash
# Preview (WhatIf)
pwsh scripts/deploy-role-assignments.ps1 -Environment prod -WhatIf

# Deploy
pwsh scripts/deploy-role-assignments.ps1 -Environment prod

# Deploy single assignment file
pwsh scripts/deploy-role-assignments.ps1 -Environment prod \
  -AssignmentFile role-assignments/assignments/helpdesk-admins.json
```

## Rollback

```bash
pwsh rollback/scripts/rollback-role-assignments.ps1 -AssignmentName helpdesk-admins
pwsh rollback/scripts/rollback-role-assignments.ps1 -RemoveEligible  # Also remove PIM eligible
```

## PIM Governance Requirements

| Role Tier | Approval Required | MFA Required | Max Duration | Alert on Activation |
|-----------|-----------------|--------------|--------------|-------------------|
| Global Admin | Yes | Yes (phishing-resistant) | 8 hours | Yes |
| Security Admin | Yes | Yes | 4 hours | Yes |
| CA Admin | No | Yes | 4 hours | Yes |
| User Admin (scoped) | No | Yes | 8 hours | Yes |
| Helpdesk Admin (scoped) | No | Yes | 8 hours | No |

## References

- [Entra ID built-in roles](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference)
- [Privileged Identity Management](https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/)
- [Microsoft security best practices for privileged access](https://learn.microsoft.com/en-us/security/privileged-access-workstations/privileged-access-strategy)
