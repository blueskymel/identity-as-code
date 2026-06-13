# Tenant Separation Migration Checklist

Use this checklist to track progress through a tenant separation (divestiture) engagement.
Work through each phase in order; check off items as they are completed.

---

## Phase 1 – Pre-Separation Planning

- [ ] Identify the scope: which business unit / subsidiary is separating
- [ ] Name the source tenant and target (new) tenant
- [ ] Confirm target tenant has been provisioned and licensed
- [ ] Obtain Global Administrator or required delegated permissions in both tenants
- [ ] Schedule a maintenance / migration window with stakeholders
- [ ] Notify affected users of upcoming changes (UPN changes, password resets, etc.)
- [ ] Back up existing conditional access policies, named locations, and authentication methods

---

## Phase 2 – Source Tenant Inventory

- [ ] Run `inventory.ps1` against source tenant
  ```powershell
  pwsh tenant-separation/inventory.ps1 -OutputPath ./tenant-separation/output
  ```
- [ ] Verify output files exist:
  - `output/inventory-users.csv`
  - `output/inventory-groups.csv`
  - `output/inventory-app-registrations.csv`
  - `output/inventory-enterprise-apps.csv`
  - `output/inventory-role-assignments.csv`
- [ ] Review user count and validate against HR roster
- [ ] Flag any service accounts, break-glass accounts, or shared mailboxes for special handling

---

## Phase 3 – User Export

- [ ] Run `export-users.ps1` against source tenant
  ```powershell
  pwsh tenant-separation/export-users.ps1 -OutputPath ./tenant-separation/output
  ```
- [ ] Verify output files:
  - `output/users.csv`
  - `output/user-managers.csv`
  - `output/user-licenses.csv`
- [ ] Review on-premises sync status (`OnPremisesSyncEnabled`) — synced users require AD DS actions
- [ ] Confirm license SKUs available in target tenant match source requirements

---

## Phase 4 – Group Export

- [ ] Run `export-groups.ps1` against source tenant
  ```powershell
  pwsh tenant-separation/export-groups.ps1 -OutputPath ./tenant-separation/output
  ```
- [ ] Verify output files:
  - `output/groups.csv`
  - `output/group-memberships.csv`
  - `output/group-owners.csv`
- [ ] Identify dynamic groups — review membership rules for compatibility in target tenant
- [ ] Identify mail-enabled groups that may require Exchange Online re-creation

---

## Phase 5 – Role Mapping

- [ ] Run `role-mapping.ps1` to generate the role mapping spreadsheet
  ```powershell
  pwsh tenant-separation/role-mapping.ps1 `
      -SourceExportPath ./tenant-separation/output `
      -OutputPath ./tenant-separation/output
  ```
- [ ] Open `output/role-mapping.csv` and populate:
  - `TargetRoleDefinitionId` for any roles that differ in the target tenant
  - `TargetPrincipalUPN` for users whose UPN will change
  - `MigrationNotes` for exceptions or deferred assignments
- [ ] Review privileged roles (Global Admin, Privileged Role Admin) — confirm least-privilege in target
- [ ] Confirm PIM-eligible vs active assignments are preserved as intended

---

## Phase 6 – Application Migration

- [ ] List apps in scope from `output/inventory-app-registrations.csv`
- [ ] For each in-scope app:
  - [ ] Re-register in target tenant (or use [App migration tool](https://learn.microsoft.com/en-us/azure/active-directory/manage-apps/migrate-adfs-apps-to-azure))
  - [ ] Update redirect URIs and client secrets / certificates
  - [ ] Reconfigure API permissions and admin consent
  - [ ] Update application owner(s)
- [ ] Re-configure enterprise app (service principal) SSO settings in target tenant
- [ ] Update any hard-coded tenant IDs in application configurations

---

## Phase 7 – Target Tenant Provisioning

- [ ] Create users in target tenant (or configure inbound provisioning / cross-tenant sync)
- [ ] Assign licenses to users
- [ ] Recreate groups and restore memberships
- [ ] Apply role assignments from `output/role-mapping.csv`
- [ ] Configure authentication methods (MFA, passwordless, SSPR)
- [ ] Import / recreate conditional access policies
- [ ] Validate named locations and compliance policies

---

## Phase 8 – Validation

- [ ] Test user sign-in for at least one representative from each department
- [ ] Validate MFA prompts and authentication strengths
- [ ] Confirm group-based access (SharePoint, Teams, apps) is functional
- [ ] Verify PIM role activation works for privileged accounts
- [ ] Run access reviews on migrated privileged roles
- [ ] Confirm no unexpected guest accounts remain active post-migration

---

## Phase 9 – Cutover and Cleanup

- [ ] Update DNS / UPN suffixes if domain ownership is transferring
- [ ] Disable (do **not** immediately delete) migrated user accounts in source tenant
- [ ] Remove application registrations from source tenant after grace period
- [ ] Revoke outstanding OAuth tokens in source tenant
- [ ] Remove the separating entity's data from source tenant (groups, policies, named locations)
- [ ] Cancel licenses no longer needed in source tenant
- [ ] Document final state in `tenant-transitions/` runbook

---

## Notes

| Date | Owner | Note |
|------|-------|------|
|      |       |      |
