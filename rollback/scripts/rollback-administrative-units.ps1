<#
.SYNOPSIS
    Rolls back Administrative Units created by the pipeline.

.DESCRIPTION
    Removes Administrative Units and their scoped role assignments.
    Backup JSON is saved before removal to support re-creation if needed.

.PARAMETER AUName
    Display name of the AU to roll back. If omitted, all AUs defined in administrative-units/units/ are processed.

.EXAMPLE
    pwsh rollback/scripts/rollback-administrative-units.ps1 -AUName au-helpdesk
    pwsh rollback/scripts/rollback-administrative-units.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$AUName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region --- Helpers ---

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $ts = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $colour = switch ($Level) {
        'INFO'    { 'Cyan' }
        'SUCCESS' { 'Green' }
        'WARN'    { 'Yellow' }
        'ERROR'   { 'Red' }
        default   { 'White' }
    }
    Write-Host "[$ts] [$Level] $Message" -ForegroundColor $colour
}

function Assert-RequiredModules {
    $required = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Identity.DirectoryManagement')
    foreach ($mod in $required) {
        if (-not (Get-Module -ListAvailable -Name $mod)) {
            throw "Required module '$mod' is not installed."
        }
    }
}

function Connect-GraphWithManagedIdentity {
    Write-Log "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome
    Write-Log "Connected." -Level 'SUCCESS'
}

function Remove-SingleAU {
    param([string]$AUDisplayName)
    $au = Get-MgDirectoryAdministrativeUnit -Filter "displayName eq '$AUDisplayName'" | Select-Object -First 1
    if (-not $au) {
        Write-Log "AU not found: $AUDisplayName" -Level 'WARN'
        return
    }

    # Save backup before removal
    $repoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $backupDir  = Join-Path $repoRoot 'rollback' 'backups' 'administrative-units' (Get-Date).ToString('yyyy-MM-ddTHH-mm-ss')
    $null = New-Item -ItemType Directory -Path $backupDir -Force
    $au | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $backupDir "$AUDisplayName.json") -Encoding UTF8
    Write-Log "Backup saved to $backupDir"

    Write-Log "Removing Administrative Unit: $AUDisplayName (ID: $($au.Id))" -Level 'WARN'
    if ($PSCmdlet.ShouldProcess($AUDisplayName, 'Remove Administrative Unit')) {
        Remove-MgDirectoryAdministrativeUnit -AdministrativeUnitId $au.Id
        Write-Log "Removed: $AUDisplayName" -Level 'SUCCESS'
    }
}

#endregion

#region --- Main ---

Assert-RequiredModules
Connect-GraphWithManagedIdentity

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$auDir    = Join-Path $repoRoot 'administrative-units' 'units'

if ($AUName) {
    Remove-SingleAU -AUDisplayName $AUName
}
else {
    $auFiles = Get-ChildItem -Path $auDir -Filter '*.json' | Sort-Object Name
    Write-Log "Rolling back $($auFiles.Count) Administrative Units..."
    foreach ($file in $auFiles) {
        $json = Get-Content -Raw $file.FullName | ConvertFrom-Json
        Remove-SingleAU -AUDisplayName $json.administrativeUnit.displayName
    }
}

Write-Log "Administrative Unit rollback complete." -Level 'SUCCESS'

#endregion
