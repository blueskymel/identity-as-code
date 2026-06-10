# Example: federated domain lifecycle operations with MSOnline

Connect-MsolService

$domainName = "contoso.com"

# Inspect current domain and federation settings
Get-MsolDomain -DomainName $domainName
Get-MsolDomainFederationSettings -DomainName $domainName
Get-MsolFederationProperty -DomainName $domainName

# Convert managed domain to federated
# SkipUserConversion avoids forcing immediate UPN/password conversion for existing users during cutover.
# Use it only when your migration plan handles user conversion separately.
Convert-MsolDomainToFederated `
  -DomainName $domainName `
  -SupportMultipleDomain `
  -SkipUserConversion

# Update federation settings / metadata
Set-MsolDomainFederationSettings `
  -DomainName $domainName `
  -IssuerUri "http://sts.contoso.com/adfs/services/trust" `
  -PassiveLogOnUri "https://sts.contoso.com/adfs/ls/" `
  -ActiveLogOnUri "https://sts.contoso.com/adfs/services/trust/2005/usernamemixed" `
  -LogOffUri "https://sts.contoso.com/adfs/ls/" `
  -MetadataExchangeUri "https://sts.contoso.com/adfs/services/trust/mex"

Update-MsolFederatedDomain -DomainName $domainName

# If needed, roll back to managed authentication
# PasswordFile should point to a secured CSV generated per Microsoft guidance for conversion rollback
# (typically containing UserPrincipalName and NewPassword columns).
# Convert-MsolDomainToStandard -DomainName $domainName -SkipUserConversion -PasswordFile '<secure-password-file-path>'
