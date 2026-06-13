# PTA Troubleshooting Guide

## Common Issues and Solutions

### Issue: Agent Not Connecting
**Symptoms**: Agent appears offline in Azure AD settings

**Causes**:
- Network connectivity issue
- Azure Service endpoints blocked
- Certificate issues
- Agent service not running

**Solutions**:
```powershell
# Check agent service status
Get-Service AadAuthenticationAgentService | Select-Object Status, StartType

# Restart agent service
Restart-Service AadAuthenticationAgentService

# Check network connectivity to Azure
Test-NetConnection -ComputerName "autologon.microsoftonline.com" -Port 443
```

### Issue: Authentication Timeouts
**Symptoms**: Users experience slow login or timeout errors

**Causes**:
- High load on agent
- Network latency
- AD query performance

**Solutions**:
- Deploy additional agents for load balancing
- Check AD query performance
- Monitor network latency
- Verify agent resource usage

### Issue: Certificate Errors
**Symptoms**: SSL/TLS certificate errors in logs

**Causes**:
- Expired agent certificate
- Misconfigured certificates
- Clock skew

**Solutions**:
```powershell
# Renew agent certificates
# Re-register agent in Azure AD
# Verify server time synchronization
```

### Issue: Some Users Cannot Authenticate
**Symptoms**: Specific users fail PTA but others succeed

**Causes**:
- User account issues in AD
- Permission problems
- Group Policy restrictions

**Solutions**:
- Verify user account is enabled
- Check group memberships
- Review AD permissions
- Check Group Policy settings
