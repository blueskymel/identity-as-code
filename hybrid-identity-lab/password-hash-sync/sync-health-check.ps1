# Password Hash Sync Health Check
# Monitors sync status, health, and performance

param(
    [Parameter(Mandatory=$true)]
    [string]$ADConnectServer
)

$session = New-PSSession -ComputerName $ADConnectServer

$result = Invoke-Command -Session $session -ScriptBlock {
    Import-Module AdSync
    
    # Get sync status
    $syncStatus = Get-ADSyncSyncCycleStatus
    
    # Get connector run stats
    $connectors = Get-ADSyncConnector
    
    # Get object sync statistics
    $syncStats = @()
    foreach ($connector in $connectors) {
        $run = Get-ADSyncConnectorRunStatus -ConnectorName $connector.Name | Select-Object -Last 1
        $syncStats += [PSCustomObject]@{
            Connector = $connector.Name
            LastSync = $run.BeginTime
            ObjectsAdded = $run.ConnectorStatistics.Add
            ObjectsUpdated = $run.ConnectorStatistics.Update
            ObjectsDeleted = $run.ConnectorStatistics.Delete
            Errors = $run.ConnectorStatistics.Error
        }
    }
    
    @{
        Status = $syncStatus
        Stats = $syncStats
    }
}

Remove-PSSession -Session $session

Write-Host "=== Password Hash Sync Health ===" -ForegroundColor Cyan
$result.Stats | Format-Table -AutoSize
