# Pass-Through Authentication (PTA) Agent Installation

## Overview
PTA Agent is a lightweight component installed on-premises that validates user credentials against your on-premises Active Directory without synchronizing password hashes to the cloud.

## System Requirements
- Windows Server 2012 R2 or later
- .NET Framework 4.5 or later
- 1GB RAM minimum
- Network connectivity to Azure AD

## Installation Steps

### 1. Download PTA Agent
```powershell
# Download from Azure AD Connect
# Or directly from Microsoft website
```

### 2. Install the Agent
```powershell
# Run installer
.\AADConnectAuthAgentSetup.exe

# Follow wizard:
# - Accept license
# - Configure proxy if needed
# - Complete installation
```

### 3. Register with Azure AD
```powershell
# After installation, register agent
# Navigate to: Settings > Azure AD > Manage Azure AD Connect > Pass-through authentication
# Enable PTA and register agents
```

## High Availability
- Deploy multiple agents (minimum 3 for production)
- Agents load-balance authentication requests
- Automatic failover if agent becomes unavailable

## Post-Installation
- Monitor agent health
- Configure server certificates
- Test authentication flow
