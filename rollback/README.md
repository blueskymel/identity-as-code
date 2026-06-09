# Rollback Scripts

This directory contains scripts for safely reverting changes made by the identity-as-code pipeline.

## Available Rollback Scripts

| Script | Purpose |
|--------|---------|
| `scripts/rollback-ca-policies.ps1` | Disable or restore CA policies to a previous state |
| `scripts/rollback-groups.ps1` | Restore group membership rules or delete groups |
| `scripts/rollback-role-assignments.ps1` | Remove active and PIM eligible role assignments |
| `scripts/rollback-administrative-units.ps1` | Remove Administrative Units |

## Rollback Strategy

All deploy scripts should save a **backup snapshot** before making changes.
Backups are stored in `rollback/backups/<resource-type>/<timestamp>/`.

### Backup Directory Structure

```
rollback/
└── backups/
    ├── ca-policies/
    │   └── 2024-01-15T10-00-00/
    │       ├── CA001-Block-Legacy-Authentication.json
    │       └── ...
    ├── groups/
    │   └── 2024-01-15T10-00-00/
    └── administrative-units/
        └── 2024-01-15T10-00-00/
```

> **Note:** The `rollback/backups/` directory is git-ignored to prevent sensitive policy state from being committed to source control. Back up to a secure location (e.g., Azure Key Vault or a storage account) for production use.

## Usage

### Rollback CA Policies

```bash
# Disable a single policy
pwsh rollback/scripts/rollback-ca-policies.ps1 -PolicyName CA001-Block-Legacy-Authentication -DisableOnly

# Disable all policies
pwsh rollback/scripts/rollback-ca-policies.ps1 -DisableOnly

# Restore from backup
pwsh rollback/scripts/rollback-ca-policies.ps1 \
  -BackupPath rollback/backups/ca-policies/2024-01-15T10-00-00
```

### Rollback Groups

```bash
# Restore a single group's membership rule from backup
pwsh rollback/scripts/rollback-groups.ps1 \
  -GroupName grp-all-employees \
  -BackupPath rollback/backups/groups/2024-01-15T10-00-00

# Delete a group entirely (destructive — use with caution)
pwsh rollback/scripts/rollback-groups.ps1 -GroupName grp-dept-it -DeleteGroup
```

### Rollback Role Assignments

```bash
# Remove active assignments for a specific set
pwsh rollback/scripts/rollback-role-assignments.ps1 -AssignmentName helpdesk-admins

# Remove all assignments including PIM eligible
pwsh rollback/scripts/rollback-role-assignments.ps1 -RemoveEligible
```

### Rollback Administrative Units

```bash
# Remove a specific AU
pwsh rollback/scripts/rollback-administrative-units.ps1 -AUName au-helpdesk

# Remove all AUs
pwsh rollback/scripts/rollback-administrative-units.ps1
```

## Triggering Rollback from the Pipeline

The GitHub Actions workflow includes a manual rollback trigger:

```bash
# From GitHub Actions UI — trigger rollback workflow
# Or via GitHub CLI:
gh workflow run rollback.yml -f environment=prod -f resource=ca-policies
```

## Important Notes

- **Always use `-WhatIf`** first to preview changes.
- **Break-glass accounts** (`grp-ca-exclusion-emergency`) should NEVER be removed — deleting the exclusion group or its members can lock all users out of the tenant.
- Rollbacks of CA policies do not delete policies — they set state to `disabled`. This preserves audit history.
- PIM eligible assignment removal (`-RemoveEligible`) requires that there are no active activations in progress.
