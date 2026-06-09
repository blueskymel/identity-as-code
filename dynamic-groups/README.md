# Dynamic Groups

This directory contains Microsoft Entra ID (Azure AD) dynamic and assigned group definitions managed as code.

## Group Inventory

| Group Name | Type | Purpose |
|------------|------|---------|
| `grp-all-employees` | Dynamic | All enabled member users (employees) |
| `grp-all-guests` | Dynamic | All B2B guest users |
| `grp-licensed-m365-e3` | Dynamic | Users with M365 E3 license |
| `grp-dept-it` | Dynamic | IT department users |
| `grp-dept-finance` | Dynamic | Finance department users |
| `grp-dept-hr` | Dynamic | HR department users |
| `grp-privileged-users` | Assigned | Users with any directory role (synced by script) |
| `grp-ca-exclusion-emergency` | Assigned | Break-glass accounts excluded from CA policies |

## Group Schema

```json
{
  "groupName": "grp-name",
  "description": "Human-readable description",
  "version": "1.0.0",
  "group": {
    "displayName": "grp-name",
    "groupTypes": ["DynamicMembership"],
    "securityEnabled": true,
    "membershipRule": "...",
    "membershipRuleProcessingState": "On"
  },
  "tags": ["..."],
  "notes": "..."
}
```

## Dynamic Membership Rules

Dynamic groups use the [Entra ID dynamic membership rules syntax](https://learn.microsoft.com/en-us/entra/identity/users/groups-dynamic-membership).

### Common Rule Patterns

```
# All members (employees)
(user.userType -eq "Member") and (user.accountEnabled -eq true)

# All guests
(user.userType -eq "Guest") and (user.accountEnabled -eq true)

# Department-based
(user.department -eq "Finance") and (user.accountEnabled -eq true)

# Location-based
(user.usageLocation -eq "US") and (user.accountEnabled -eq true)

# License-based (service plan GUID)
(user.assignedPlans -any (assignedPlan.servicePlanId -eq "<GUID>" -and assignedPlan.capabilityStatus -eq "Enabled"))
```

## Prerequisites

- **Entra ID P1** license for dynamic group membership
- HR system syncing `department`, `jobTitle`, `usageLocation` attributes via Microsoft Entra Connect or HR-driven provisioning

## Deploying

```bash
pwsh scripts/deploy-dynamic-groups.ps1 -Environment prod -WhatIf
pwsh scripts/deploy-dynamic-groups.ps1 -Environment prod
```

## Rollback

```bash
pwsh rollback/scripts/rollback-groups.ps1 -GroupName grp-all-employees
```

## References

- [Dynamic membership rules for groups in Entra ID](https://learn.microsoft.com/en-us/entra/identity/users/groups-dynamic-membership)
- [Manage groups with Microsoft Graph](https://learn.microsoft.com/en-us/graph/api/resources/group)
