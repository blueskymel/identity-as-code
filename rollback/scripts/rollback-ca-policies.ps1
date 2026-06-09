<#
.SYNOPSIS
    Rolls back Conditional Access policies to their previous state.

.DESCRIPTION
    Sets CA policies to 'disabled' or restores from a saved backup JSON snapshot.
    Backup snapshots are created automatically at deploy time and stored in rollback/backups/.

.PARAMETER PolicyName
    Display name of the CA policy to roll back (e.g. CA001-Block-Legacy-Authentication).
    If omitted, rolls back ALL policies.

.PARAMETER BackupPath
    Path to a backup snapshot directory. Defaults to rollback/backups/ca-policies/<latest>.

.PARAMETER DisableOnly
    Instead of restoring from backup, simply set the policy state to 'disabled'.

.EXAMPLE
    pwsh rollback/scripts/rollback-ca-policies.ps1 -PolicyName CA001-Block-Legacy-Authentication
    pwsh rollback/scripts/rollback-ca-policies.ps1 -DisableOnly
    pwsh rollback/scripts/rollback-ca-policies.ps1 -BackupPath rollback/backups/ca-policies/2024-01-15T10-00-00
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$PolicyName,

    [Parameter()]
    [string]$BackupPath,

    [Parameter()]
    [switch]$DisableOnly
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
    $required = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Identity.SignIns')
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

function Save-PolicyBackup {
    param($Policy, [string]$BackupDir)
    $null = New-Item -ItemType Directory -Path $BackupDir -Force
    $backupFile = Join-Path $BackupDir "$($Policy.DisplayName).json"
    $Policy | ConvertTo-Json -Depth 20 | Set-Content -Path $backupFile -Encoding UTF8
    Write-Log "  Backup saved: $backupFile"
}

function Rollback-SinglePolicy {
    param([string]$PolicyDisplayName, [string]$BackupDir, [bool]$DisableOnly)

    $policy = Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq '$PolicyDisplayName'" | Select-Object -First 1
    if (-not $policy) {
        Write-Log "Policy not found: $PolicyDisplayName" -Level 'WARN'
        return
    }

    # Always save current state before making changes
    $repoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $backupRoot = Join-Path $repoRoot 'rollback' 'backups' 'ca-policies' (Get-Date).ToString('yyyy-MM-ddTHH-mm-ss')
    Save-PolicyBackup -Policy $policy -BackupDir $backupRoot

    if ($DisableOnly) {
        Write-Log "Disabling policy: $PolicyDisplayName"
        if ($PSCmdlet.ShouldProcess($PolicyDisplayName, 'Disable Conditional Access Policy')) {
            Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -Body '{"state":"disabled"}'
            Write-Log "Disabled: $PolicyDisplayName" -Level 'SUCCESS'
        }
        return
    }

    if ($BackupDir) {
        $backupFile = Join-Path $BackupDir "$PolicyDisplayName.json"
        if (-not (Test-Path $backupFile)) {
            Write-Log "No backup found for '$PolicyDisplayName' in $BackupDir" -Level 'WARN'
            return
        }
        $restoredBody = Get-Content -Raw -Path $backupFile
        Write-Log "Restoring policy '$PolicyDisplayName' from backup: $backupFile"
        if ($PSCmdlet.ShouldProcess($PolicyDisplayName, 'Restore Conditional Access Policy from backup')) {
            Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -Body $restoredBody
            Write-Log "Restored: $PolicyDisplayName" -Level 'SUCCESS'
        }
    }
    else {
        # Default: disable the policy
        Write-Log "No backup path specified — disabling policy: $PolicyDisplayName" -Level 'WARN'
        if ($PSCmdlet.ShouldProcess($PolicyDisplayName, 'Disable Conditional Access Policy')) {
            Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policy.Id -Body '{"state":"disabled"}'
            Write-Log "Disabled: $PolicyDisplayName" -Level 'SUCCESS'
        }
    }
}

#endregion

#region --- Main ---

Assert-RequiredModules
Connect-GraphWithManagedIdentity

if ($PolicyName) {
    Write-Log "Rolling back single policy: $PolicyName"
    Rollback-SinglePolicy -PolicyDisplayName $PolicyName -BackupDir $BackupPath -DisableOnly:$DisableOnly
}
else {
    Write-Log "Rolling back ALL Conditional Access policies..."

    $repoRoot   = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $policyDir  = Join-Path $repoRoot 'conditional-access' 'policies'
    $policyFiles = Get-ChildItem -Path $policyDir -Filter '*.json' | Sort-Object Name

    foreach ($file in $policyFiles) {
        $json = Get-Content -Raw $file.FullName | ConvertFrom-Json
        Rollback-SinglePolicy -PolicyDisplayName $json.policy.displayName -BackupDir $BackupPath -DisableOnly:$DisableOnly
    }
}

Write-Log "CA policy rollback complete." -Level 'SUCCESS'

#endregion
