# PTA Agent Health Check
# Monitor PTA agent status and authentication performance

param(
    [Parameter(Mandatory=$true)]
    [string]$AADCredential
)

# Connect to Azure AD
Connect-AzureAD -Credential $AADCredential

# Get PTA configuration
$ptaConfig = Get-AzureADPassthroughAuthenticationConfiguration

Write-Host "=== Pass-Through Authentication Status ===" -ForegroundColor Cyan
Write-Host "PTA Enabled: $($ptaConfig.PassthroughAuthenticationEnabled)"
Write-Host ""

# Get connected agents
Write-Host "=== Connected PTA Agents ===" -ForegroundColor Cyan
$agents = Get-AzureADConnectorHealthStatus -ConnectorName "Connector_*" | Where-Object { $_.ConnectorType -eq "PassthroughAuthenticationAgent" }

foreach ($agent in $agents) {
    Write-Host "Agent: $($agent.ConnectorName)"
    Write-Host "  Status: $($agent.Status)"
    Write-Host "  Last Update: $($agent.LastUpdate)"
    Write-Host "  Available: $($agent.Available)"
    Write-Host ""
}

Write-Host "=== Agent Statistics ===" -ForegroundColor Cyan
$stats = Get-AzureADAuthenticationMethodStatistics
$stats | Format-Table -AutoSize

Disconnect-AzureAD
