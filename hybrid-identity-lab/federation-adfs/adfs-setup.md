# ADFS Setup and Configuration

## Overview
Active Directory Federation Services (ADFS) is a Windows Server role that provides federated authentication. It acts as an identity provider that securely passes authentication assertions to cloud services.

## System Requirements
- Windows Server 2016 or later
- .NET Framework 4.5 or later
- SSL certificate for ADFS service
- SQL Server (can be co-located or remote)

## Installation Steps

### 1. Install ADFS Role
```powershell
Install-WindowsFeature ADFS-Federation -IncludeManagementTools -IncludeAllSubFeatures
```

### 2. Create ADFS Farm
```powershell
# On primary server
$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=adfs.contoso.com" }

$cred = Get-Credential

$params = @{
    CertificateThumbprint = $cert.Thumbprint
    FederationServiceName = "adfs.contoso.com"
    FederationServiceDisplayName = "Contoso ADFS"
    ServiceAccountCredential = $cred
    OverwriteConfiguration = $true
}

New-AdfsFarmConfiguration @params
```

### 3. Configure Claims Rules
```powershell
# Configure relying party trust claims rules
# Map on-premises groups to cloud roles
```

## Post-Installation
- Configure certificates
- Set up claims rules
- Test federation flow
- Configure redundancy with secondary ADFS servers
