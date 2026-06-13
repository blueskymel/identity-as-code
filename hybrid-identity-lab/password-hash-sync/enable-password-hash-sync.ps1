# Enable Password Hash Synchronization
# This script enables PHS on an existing Azure AD Connect instance

param(
    [Parameter(Mandatory=$true)]
    [string]$ADConnectServer,
    
    [Parameter(Mandatory=$true)]
    [string]$AADCredential
)

# Connect to ADSync server
$session = New-PSSession -ComputerName $ADConnectServer
Invoke-Command -Session $session -ScriptBlock {
    # Import ADSync module
    Import-Module AdSync
    
    # Get current sync configuration
    $config = Get-ADSyncConnector | Where-Object { $_.ConnectorTypeName -eq "AD" }
    
    # Enable password hash synchronization
    Set-ADSyncAADPasswordSyncConfiguration -SourceConnector $config[0].Identifier -TargetConnector (Get-ADSyncConnector | Where-Object { $_.ConnectorTypeName -eq "AzureAD" }).Identifier -Enable $true
    
    # Trigger sync
    Start-ADSyncSyncCycle -PolicyType Delta
    
    Write-Host "Password Hash Sync enabled and initial delta sync triggered"
}

Remove-PSSession -Session $session
