# Example: federated domain lifecycle operations with MSOnline

Connect-MsolService

$domainName = "contoso.com"

# Inspect current domain and federation settings
Get-MsolDomain -DomainName $domainName
Get-MsolDomainFederationSettings -DomainName $domainName
Get-MsolFederationProperty -DomainName $domainName

# Convert managed domain to federated
Convert-MsolDomainToFederated `
  -DomainName $domainName `
  -SupportMultipleDomain `
  -SkipUserConversion $true

# Update federation settings / metadata
Set-MsolDomainFederationSettings `
  -DomainName $domainName `
  -IssuerUri "urn:contoso:adfs" `
  -PassiveLogOnUri "https://sts.contoso.com/adfs/ls/" `
  -ActiveLogOnUri "https://sts.contoso.com/adfs/services/trust/2005/usernamemixed" `
  -LogOffUri "https://sts.contoso.com/adfs/ls/" `
  -MetadataExchangeUri "https://sts.contoso.com/adfs/services/trust/mex"

Update-MsolFederatedDomain -DomainName $domainName

# If needed, roll back to managed authentication
# Convert-MsolDomainToStandard -DomainName $domainName -SkipUserConversion $true -PasswordFile "C:\\temp\\passwords.csv"
