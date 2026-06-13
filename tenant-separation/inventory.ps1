<#
.SYNOPSIS
    Collects a full inventory of identities, groups, app registrations,
    enterprise apps, and role assignments from the source tenant.

.PARAMETER OutputPath
    Directory where inventory CSV files will be written (created if absent).

.PARAMETER UseManagedIdentity
    Use managed identity authentication instead of interactive sign-in.

.EXAMPLE
    pwsh tenant-separation/inventory.ps1 -OutputPath ./tenant-separation/output
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
$connectParams = @{ Scopes = @("User.Read.All","Group.Read.All","Application.Read.All","RoleManagement.Read.Directory","Directory.Read.All") }
if ($UseManagedIdentity) { $connectParams["Identity"] = $true }
Connect-MgGraph @connectParams

# --- Users ---
Write-Host "Exporting users..."
$users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,AccountEnabled,UserType,CreatedDateTime |
    Select-Object Id, DisplayName, UserPrincipalName, AccountEnabled, UserType, CreatedDateTime
$users | Export-Csv -Path (Join-Path $OutputPath "inventory-users.csv") -NoTypeInformation
Write-Host "  $($users.Count) users exported."

# --- Groups ---
Write-Host "Exporting groups..."
$groups = Get-MgGroup -All -Property Id,DisplayName,GroupTypes,SecurityEnabled,MailEnabled,MembershipRule |
    Select-Object Id, DisplayName, GroupTypes, SecurityEnabled, MailEnabled, MembershipRule
$groups | Export-Csv -Path (Join-Path $OutputPath "inventory-groups.csv") -NoTypeInformation
Write-Host "  $($groups.Count) groups exported."

# --- App Registrations ---
Write-Host "Exporting app registrations..."
$apps = Get-MgApplication -All -Property Id,AppId,DisplayName,SignInAudience,CreatedDateTime |
    Select-Object Id, AppId, DisplayName, SignInAudience, CreatedDateTime
$apps | Export-Csv -Path (Join-Path $OutputPath "inventory-app-registrations.csv") -NoTypeInformation
Write-Host "  $($apps.Count) app registrations exported."

# --- Enterprise Apps (Service Principals) ---
Write-Host "Exporting enterprise apps..."
$sps = Get-MgServicePrincipal -All -Property Id,AppId,DisplayName,ServicePrincipalType,AccountEnabled |
    Select-Object Id, AppId, DisplayName, ServicePrincipalType, AccountEnabled
$sps | Export-Csv -Path (Join-Path $OutputPath "inventory-enterprise-apps.csv") -NoTypeInformation
Write-Host "  $($sps.Count) service principals exported."

# --- Directory Role Assignments ---
Write-Host "Exporting directory role assignments..."
$roleAssignments = Get-MgRoleManagementDirectoryRoleAssignment -All |
    Select-Object Id, RoleDefinitionId, PrincipalId, DirectoryScopeId
$roleAssignments | Export-Csv -Path (Join-Path $OutputPath "inventory-role-assignments.csv") -NoTypeInformation
Write-Host "  $($roleAssignments.Count) role assignments exported."

Write-Host ""
Write-Host "Inventory complete. Files written to: $OutputPath"
