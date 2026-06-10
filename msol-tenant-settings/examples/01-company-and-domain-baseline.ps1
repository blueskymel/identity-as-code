# Example: company and custom domain baseline operations with MSOnline

Connect-MsolService

# Inspect current company-level settings
Get-MsolCompanyInformation

# Example company configuration
Set-MsolCompanySettings `
  -AllowAdHocSubscriptions $false `
  -AllowEmailVerifiedUsers $false

# Add and verify a new custom domain
New-MsolDomain -Name "contoso.com"
Get-MsolDomainVerificationDns -DomainName "contoso.com" -Mode DnsTxtRecord
Confirm-MsolDomain -DomainName "contoso.com"

# Review and update domain behavior
Get-MsolDomain -DomainName "contoso.com"
Set-MsolDomain -Name "contoso.com" -IsDefault
