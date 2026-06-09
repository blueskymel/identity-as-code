# Administrative Units (AUs)

Administrative Units (AUs) in Microsoft Entra ID enable **scoped delegation** — restricting what users or groups an administrator can manage, rather than giving them tenant-wide privileges.

## AU Inventory

| AU Name | Scope | Roles Scoped |
|---------|-------|--------------|
| `au-helpdesk` | IT Support tier-1 users | Helpdesk Administrator |
| `au-regional-emea` | EMEA-region members | User Administrator, Helpdesk Administrator |
| `au-regional-amer` | AMER-region members | User Administrator, Helpdesk Administrator |
| `au-sensitive-data-users` | Finance, Legal, HR, Executive users | User Administrator |

## Design Principles

1. **Least Privilege** – Admins only manage users in their scope, not the entire tenant.
2. **Geographic Delegation** – Regional IT teams manage their region without cross-region access.
3. **Data Classification** – Sensitive-data users can only be managed by vetted, senior IT staff.
4. **Dynamic Membership** – AU membership mirrors authoritative HR data via attribute sync.

## AU Schema

```json
{
  "auName": "au-name",
  "description": "Human-readable description",
  "version": "1.0.0",
  "administrativeUnit": {
    "displayName": "au-name",
    "visibility": "HiddenMembership",
    "membershipType": "Dynamic",
    "membershipRule": "...",
    "membershipRuleProcessingState": "On"
  },
  "scopedRoleAssignments": [
    {
      "role": "Role Display Name",
      "roleTemplateId": "...",
      "members": [ ... ]
    }
  ]
}
```

## Membership Types

| Type | License Required | Notes |
|------|-----------------|-------|
| `Assigned` | Entra ID P1 | Manual membership management |
| `Dynamic` | Entra ID P2 | Rule-based, mirrors HR data |

## Deploying

```bash
pwsh scripts/deploy-administrative-units.ps1 -Environment prod -WhatIf
pwsh scripts/deploy-administrative-units.ps1 -Environment prod
```

## Rollback

AUs are non-destructive — removing an AU does not delete users or their data.

```bash
pwsh rollback/scripts/rollback-administrative-units.ps1 -AUName au-helpdesk
```

## References

- [Administrative Units in Entra ID](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/administrative-units)
- [Restrict role assignment scope with AUs](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/admin-units-assign-roles)
