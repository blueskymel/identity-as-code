# ADFS Certificate Rotation and Renewal

## Certificate Types in ADFS

1. **Signing Certificate**: Signs SAML tokens
2. **SSL/TLS Certificate**: HTTPS for ADFS service
3. **Token Decryption Certificate**: Decrypts encrypted tokens

## Certificate Renewal Process

### Automatic Renewal
```powershell
# Enable automatic certificate renewal (recommended)
Set-AdfsProperties -AutoCertificateRollover $true
```

### Manual Certificate Renewal

#### Step 1: Obtain New Certificate
```powershell
$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=fs.contoso.com" }
```

#### Step 2: Set New Certificate
```powershell
# Set new signing certificate
Set-AdfsCertificate -CertificateType Token-Signing -Thumbprint "NewThumbprint"

# Set new SSL certificate
$newSSLCert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Thumbprint -eq "NewThumbprint" }
Set-AdfsSslCertificate -Thumbprint $newSSLCert.Thumbprint
```

#### Step 3: Update Azure AD Trust
```powershell
# Update Azure AD with new certificate
# Use Azure AD Connect or Azure AD PowerShell
Update-MsolFederatedDomain -DomainName "contoso.com"
```

## Certificate Lifecycle Management

- **Monitor Expiration**: Set alerts 60/30 days before expiration
- **Auto-Renewal**: Enable automatic rollover for seamless renewal
- **Testing**: Test with pilot users before production rollout
- **Documentation**: Maintain certificate inventory and renewal history
