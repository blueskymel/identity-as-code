<#
.SYNOPSIS
    Maps Azure AD directory roles and PIM role assignments from the source
    tenant to equivalent roles in the target tenant, producing a role
    mapping CSV for use during migration.

.PARAMETER SourceExportPath
    Path to the folder containing role-assignment and inventory CSVs
    produced by inventory.ps1.

.PARAMETER OutputPath
    Directory where the role-mapping output file will be written.

.PARAMETER UseManagedIdentity
    Use managed identity authentication instead of interactive sign-in.

.EXAMPLE
    pwsh tenant-separation/role-mapping.ps1 `
        -SourceExportPath ./tenant-separation/output `
        -OutputPath ./tenant-separation/output
#>
[CmdletBinding()]
param(
    [string]$SourceExportPath = (Join-Path $PSScriptRoot "output"),
    [string]$OutputPath       = (Join-Path $PSScriptRoot "output"),
    [switch]$UseManagedIdentity
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

$assignmentsCsv = Join-Path $SourceExportPath "inventory-role-assignments.csv"
$usersCsv       = Join-Path $SourceExportPath "inventory-users.csv"

if (-not (Test-Path $assignmentsCsv)) { throw "Missing: $assignmentsCsv — run inventory.ps1 first." }
if (-not (Test-Path $usersCsv))       { throw "Missing: $usersCsv — run inventory.ps1 first." }

Write-Host "Connecting to Microsoft Graph..."
$connectParams = @{ Scopes = @("RoleManagement.Read.Directory","User.Read.All","Directory.Read.All") }
if ($UseManagedIdentity) { $connectParams["Identity"] = $true }
Connect-MgGraph @connectParams

# Load role definitions for display-name enrichment
Write-Host "Loading role definitions..."
$roleDefs = Get-MgRoleManagementDirectoryRoleDefinition -All |
    Select-Object Id, DisplayName, IsBuiltIn
$roleDefMap = @{}
foreach ($rd in $roleDefs) { $roleDefMap[$rd.Id] = $rd }

# Load exported data
$assignments = Import-Csv $assignmentsCsv
$users       = Import-Csv $usersCsv
$userMap     = @{}
foreach ($u in $users) { $userMap[$u.Id] = $u }

Write-Host "Building role mapping..."
$mappingRows = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($a in $assignments) {
    $roleDef    = $roleDefMap[$a.RoleDefinitionId]
    $principal  = $userMap[$a.PrincipalId]

    $mappingRows.Add([PSCustomObject]@{
        AssignmentId          = $a.Id
        RoleDefinitionId      = $a.RoleDefinitionId
        RoleDisplayName       = if ($roleDef) { $roleDef.DisplayName } else { "Unknown" }
        IsBuiltIn             = if ($roleDef) { $roleDef.IsBuiltIn }   else { "" }
        PrincipalId           = $a.PrincipalId
        PrincipalUPN          = if ($principal) { $principal.UserPrincipalName } else { "" }
        PrincipalDisplayName  = if ($principal) { $principal.DisplayName }       else { "" }
        DirectoryScopeId      = $a.DirectoryScopeId
        TargetRoleDefinitionId = $a.RoleDefinitionId   # update if target role differs
        TargetPrincipalUPN    = if ($principal) { $principal.UserPrincipalName } else { "" }
        MigrationNotes        = ""
    })
}

$outputFile = Join-Path $OutputPath "role-mapping.csv"
$mappingRows | Export-Csv -Path $outputFile -NoTypeInformation
Write-Host "  $($mappingRows.Count) role mapping records written to: $outputFile"
Write-Host ""
Write-Host "Review the 'TargetRoleDefinitionId' and 'TargetPrincipalUPN' columns before applying to the target tenant."
