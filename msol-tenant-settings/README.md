# MSOnline Tenant and Domain Settings

This folder captures **legacy MSOnline** command examples for managing tenant-wide company settings, custom domains, and Azure AD federation settings.

> The `MSOnline` module is in legacy/deprecation path. Prefer Microsoft Graph PowerShell for new automation, but keep these examples for environments that still require MSOL cmdlets.

## Scope

This documentation covers the command area you asked about:

- `Set-MsolCompanySettings`
- `Set-MsolDomainFederationSettings`
- `Update-MsolFederatedDomain`
- `Set-MsolDomain`

and the related commands commonly used together during domain/federation lifecycle operations.

## Related Command Inventory

### Session and tenant context

| Command | Purpose |
|---------|---------|
| `Connect-MsolService` | Authenticate to the tenant before running MSOL cmdlets |
| `Get-MsolCompanyInformation` | Read current tenant/company information |
| `Set-MsolCompanySettings` | Configure company-level settings (for example, self-service sign-up and notification controls) |

### Custom domain lifecycle

| Command | Purpose |
|---------|---------|
| `Get-MsolDomain` | List and inspect domain objects |
| `New-MsolDomain` | Add a new custom domain |
| `Get-MsolDomainVerificationDns` | Get DNS verification record requirements |
| `Confirm-MsolDomain` | Verify/prove domain ownership |
| `Set-MsolDomain` | Update domain properties (for example, default/authentication behavior) |
| `Remove-MsolDomain` | Remove a domain when it is no longer in use |

### Federation lifecycle

| Command | Purpose |
|---------|---------|
| `Get-MsolDomainFederationSettings` | Read federation configuration for a domain |
| `Set-MsolDomainFederationSettings` | Set or modify federation settings directly |
| `New-MsolFederatedDomain` | Configure a managed domain as federated |
| `Update-MsolFederatedDomain` | Refresh federation metadata and trust settings |
| `Convert-MsolDomainToFederated` | Convert a managed domain to federated authentication |
| `Convert-MsolDomainToStandard` | Convert a federated domain back to managed authentication |
| `Get-MsolFederationProperty` | Compare AD FS and Microsoft Entra federation metadata |

## Example Files

- [`examples/01-company-and-domain-baseline.ps1`](examples/01-company-and-domain-baseline.ps1)
- [`examples/02-federation-lifecycle.ps1`](examples/02-federation-lifecycle.ps1)

## Usage

1. Install/import `MSOnline` in a PowerShell session.
2. Copy the example script that matches your scenario.
3. Replace placeholder values (`contoso.com`, URLs, certificates, and signing details) with tenant-specific values.
4. Run in a non-production tenant first and validate sign-in/domain behavior.
5. Promote to production only after successful validation and rollback readiness.

## References

- [MSOnline module reference](https://learn.microsoft.com/powershell/module/msonline/)
- [Migrate from MSOnline and AzureAD PowerShell to Microsoft Graph PowerShell](https://learn.microsoft.com/powershell/microsoftgraph/migration-steps)
