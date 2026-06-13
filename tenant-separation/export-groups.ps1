<#
.SYNOPSIS
    Exports all groups and their memberships from the source tenant.

.PARAMETER OutputPath
    Directory where output CSV files will be written (created if absent).

.PARAMETER UseManagedIdentity
    Use managed identity authentication instead of interactive sign-in.

.EXAMPLE
    pwsh tenant-separation/export-groups.ps1 -OutputPath ./tenant-separation/output
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "output"),
    [switch]$UseManagedIdentity
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

Write-Host "Connecting to Microsoft Graph..."
$connectParams = @{ Scopes = @("Group.Read.All","GroupMember.Read.All","Directory.Read.All") }
if ($UseManagedIdentity) { $connectParams["Identity"] = $true }
Connect-MgGraph @connectParams

# --- Export group metadata ---
Write-Host "Exporting group metadata..."
$groups = Get-MgGroup -All -Property Id,DisplayName,Description,GroupTypes,SecurityEnabled,MailEnabled,MailNickname,MembershipRule,MembershipRuleProcessingState |
    Select-Object Id, DisplayName, Description, GroupTypes, SecurityEnabled, MailEnabled, MailNickname, MembershipRule, MembershipRuleProcessingState
$groups | Export-Csv -Path (Join-Path $OutputPath "groups.csv") -NoTypeInformation
Write-Host "  $($groups.Count) groups exported."

# --- Export group memberships ---
Write-Host "Exporting group memberships..."
$memberships = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($group in $groups) {
    $members = Get-MgGroupMember -GroupId $group.Id -All
    foreach ($member in $members) {
        $memberships.Add([PSCustomObject]@{
            GroupId          = $group.Id
            GroupDisplayName = $group.DisplayName
            MemberId         = $member.Id
            MemberType       = $member.AdditionalProperties["@odata.type"]
        })
    }
}

$memberships | Export-Csv -Path (Join-Path $OutputPath "group-memberships.csv") -NoTypeInformation
Write-Host "  $($memberships.Count) membership records exported."

# --- Export group owners ---
Write-Host "Exporting group owners..."
$owners = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($group in $groups) {
    $groupOwners = Get-MgGroupOwner -GroupId $group.Id -All
    foreach ($owner in $groupOwners) {
        $owners.Add([PSCustomObject]@{
            GroupId          = $group.Id
            GroupDisplayName = $group.DisplayName
            OwnerId          = $owner.Id
        })
    }
}

$owners | Export-Csv -Path (Join-Path $OutputPath "group-owners.csv") -NoTypeInformation
Write-Host "  $($owners.Count) group owner records exported."

Write-Host ""
Write-Host "Group export complete. Files written to: $OutputPath"
