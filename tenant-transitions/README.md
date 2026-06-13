# TenantTransitions

Implementation assets for **identity consolidation** and **separation (divestiture)** projects.

## Included Assets

- `templates/tenant-transition-plan.template.json` - consolidated planning template
- `templates/sso-test-plan.template.json` - SSO validation input template (OIDC/OAuth/SAML)
- `templates/separation-plan.template.json` - separation execution input template
- `scripts/Invoke-TenantTransitionTemplate.ps1` - template loader for quick inspection
- `scripts/invoke-tenant-transition-project.ps1` - executable transition workflow script

## Consolidation Workflow Implementation

1. Review tenant structure:
   ```powershell
   pwsh scripts/invoke-tenant-transition-project.ps1 -Action ReviewTenantStructure -OutputPath ./tenant-transitions/output
   ```
2. Export group memberships:
   ```powershell
   pwsh scripts/invoke-tenant-transition-project.ps1 -Action ExportGroupMemberships -OutputPath ./tenant-transitions/output
   ```
3. Map identities:
   ```powershell
   pwsh scripts/invoke-tenant-transition-project.ps1 -Action MapIdentities `
     -SourceUsersCsv ./tenant-transitions/output/source-users.csv `
     -TargetUsersCsv ./tenant-transitions/output/target-users.csv `
     -OutputPath ./tenant-transitions/output
   ```
4. Migrate identities and memberships:
   ```powershell
   pwsh scripts/invoke-tenant-transition-project.ps1 -Action MigrateIdentities `
     -MappingFile ./tenant-transitions/output/identity-mapping.csv `
     -GroupMembershipCsv ./tenant-transitions/output/source-group-memberships.csv `
     -CreateMissingUsers -WhatIf
   ```
5. Test SSO applications:
   ```powershell
   pwsh scripts/invoke-tenant-transition-project.ps1 -Action TestSsoApplications `
     -SsoPlanFile ./tenant-transitions/templates/sso-test-plan.template.json `
     -OutputPath ./tenant-transitions/output
   ```

## Separation Workflow Implementation

```powershell
pwsh scripts/invoke-tenant-transition-project.ps1 -Action RunSeparationProject `
  -SeparationPlanFile ./tenant-transitions/templates/separation-plan.template.json `
  -WhatIf
```

> Use `-UseManagedIdentity` in pipeline contexts. Omit it for delegated interactive sign-in.
