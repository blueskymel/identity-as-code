<#
.SYNOPSIS
    Rolls back dynamic group definitions to a previous state.

.DESCRIPTION
    Can delete groups created by the pipeline (dry run safe) or restore membership rules
    from a backup snapshot taken at deploy time.

.PARAMETER GroupName
    Display name of the group to roll back. If omitted, all groups defined in dynamic-groups/groups/ are processed.

.PARAMETER BackupPath
    Path to a backup snapshot directory created by the deploy script.

.PARAMETER DeleteGroup
    Switch to DELETE the group entirely rather than restore its previous state.
    USE WITH CAUTION — this permanently removes the group and all its memberships.

.EXAMPLE
    pwsh rollback/scripts/rollback-groups.ps1 -GroupName grp-all-employees
    pwsh rollback/scripts/rollback-groups.ps1 -BackupPath rollback/backups/groups/2024-01-15T10-00-00
    pwsh rollback/scripts/rollback-groups.ps1 -GroupName grp-dept-it -DeleteGroup
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$GroupName,

    [Parameter()]
    [string]$BackupPath,

    [Parameter()]
    [switch]$DeleteGroup
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
    $required = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Groups')
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

function Rollback-SingleGroup {
    param([string]$GroupDisplayName, [string]$BackupDir, [bool]$Delete)

    $group = Get-MgGroup -Filter "displayName eq '$GroupDisplayName'" | Select-Object -First 1
    if (-not $group) {
        Write-Log "Group not found: $GroupDisplayName" -Level 'WARN'
        return
    }

    if ($Delete) {
        Write-Log "DELETING group: $GroupDisplayName (ID: $($group.Id))" -Level 'WARN'
        if ($PSCmdlet.ShouldProcess($GroupDisplayName, 'DELETE Group')) {
            Remove-MgGroup -GroupId $group.Id
            Write-Log "Deleted: $GroupDisplayName" -Level 'SUCCESS'
        }
        return
    }

    if ($BackupDir) {
        $backupFile = Join-Path $BackupDir "$GroupDisplayName.json"
        if (-not (Test-Path $backupFile)) {
            Write-Log "No backup found for '$GroupDisplayName' in $BackupDir" -Level 'WARN'
            return
        }
        $restored = Get-Content -Raw -Path $backupFile | ConvertFrom-Json
        Write-Log "Restoring group '$GroupDisplayName' membership rule from backup"
        if ($PSCmdlet.ShouldProcess($GroupDisplayName, 'Restore Group Membership Rule')) {
            # Only restore membershipRule for dynamic groups; assigned groups have no rule to restore
            if ($restored.membershipRule) {
                $body = @{
                    membershipRule                = $restored.membershipRule
                    membershipRuleProcessingState = $restored.membershipRuleProcessingState
                } | ConvertTo-Json
            }
            else {
                Write-Log "  Group '$GroupDisplayName' is an assigned group — nothing to restore in membership rule." -Level 'WARN'
                return
            }
            Update-MgGroup -GroupId $group.Id -Body $body
            Write-Log "Restored: $GroupDisplayName" -Level 'SUCCESS'
        }
    }
    else {
        Write-Log "No backup path provided and -DeleteGroup not specified for '$GroupDisplayName'. No action taken." -Level 'WARN'
    }
}

#endregion

#region --- Main ---

Assert-RequiredModules
Connect-GraphWithManagedIdentity

if ($GroupName) {
    Rollback-SingleGroup -GroupDisplayName $GroupName -BackupDir $BackupPath -Delete:$DeleteGroup
}
else {
    $repoRoot  = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $groupDir  = Join-Path $repoRoot 'dynamic-groups' 'groups'
    $groupFiles = Get-ChildItem -Path $groupDir -Filter '*.json' | Sort-Object Name

    foreach ($file in $groupFiles) {
        $json = Get-Content -Raw $file.FullName | ConvertFrom-Json
        Rollback-SingleGroup -GroupDisplayName $json.group.displayName -BackupDir $BackupPath -Delete:$DeleteGroup
    }
}

Write-Log "Group rollback complete." -Level 'SUCCESS'

#endregion
