<#
.SYNOPSIS
    Deploys Administrative Unit definitions from JSON templates to Microsoft Entra ID.

.DESCRIPTION
    Creates or updates Administrative Units and their scoped role assignments via Microsoft Graph API.

.PARAMETER Environment
    Target environment: dev, staging, or prod.

.PARAMETER AUFile
    Path to a specific AU JSON file. If omitted, all AUs in administrative-units/units/ are deployed.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    pwsh scripts/deploy-administrative-units.ps1 -Environment prod -WhatIf
    pwsh scripts/deploy-administrative-units.ps1 -Environment prod
    pwsh scripts/deploy-administrative-units.ps1 -Environment prod -AUFile administrative-units/units/au-helpdesk.json
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter()]
    [string]$AUFile,

    [Parameter()]
    [switch]$WhatIf
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
            throw "Required module '$mod' is not installed. Run: Install-Module $mod"
        }
    }
}

function Connect-GraphWithManagedIdentity {
    Write-Log "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome
    Write-Log "Connected." -Level 'SUCCESS'
}

function Get-ExistingAU {
    param([string]$DisplayName)
    try {
        $aus = Get-MgDirectoryAdministrativeUnit -Filter "displayName eq '$DisplayName'"
        return $aus | Select-Object -First 1
    }
    catch {
        return $null
    }
}

function Resolve-PrincipalId {
    param([string]$Ref, [string]$Type)
    switch ($Type) {
        'user'  { return (Get-MgUser -UserId $Ref).Id }
        'group' { return (Get-MgGroup -Filter "displayName eq '$Ref'" | Select-Object -First 1).Id }
        default { throw "Unknown principal type: $Type" }
    }
}

function Deploy-ScopedRoleAssignments {
    param($AU, $Assignments)
    foreach ($assignment in $Assignments) {
        $roleId = $assignment.roleTemplateId
        foreach ($member in $assignment.members) {
            $principalId = Resolve-PrincipalId -Ref $member.ref -Type $member.type
            Write-Log "  Assigning role '$($assignment.role)' to '$($member.ref)' scoped to AU '$($AU.DisplayName)'"
            if ($PSCmdlet.ShouldProcess("$($AU.DisplayName) / $($assignment.role)", 'Create Scoped Role Assignment')) {
                $body = @{
                    '@odata.type' = '#microsoft.graph.scopedRoleMembership'
                    roleId        = $roleId
                    roleMemberId  = $principalId
                } | ConvertTo-Json
                New-MgDirectoryAdministrativeUnitScopedRoleMember -AdministrativeUnitId $AU.Id -Body $body
                Write-Log "  Scoped role assigned." -Level 'SUCCESS'
            }
        }
    }
}

function Deploy-AUFromFile {
    param([string]$FilePath)

    $json        = Get-Content -Raw -Path $FilePath | ConvertFrom-Json
    $auDef       = $json.administrativeUnit
    $displayName = $auDef.displayName
    $existing    = Get-ExistingAU -DisplayName $displayName

    $body = @{
        displayName = $auDef.displayName
        description = $auDef.description
        visibility  = $auDef.visibility
    } | ConvertTo-Json

    if ($existing) {
        Write-Log "Updating existing AU: $displayName (ID: $($existing.Id))"
        if ($PSCmdlet.ShouldProcess($displayName, 'Update Administrative Unit')) {
            Update-MgDirectoryAdministrativeUnit -AdministrativeUnitId $existing.Id -Body $body
            Write-Log "Updated: $displayName" -Level 'SUCCESS'
            $au = $existing
        }
    }
    else {
        Write-Log "Creating new AU: $displayName"
        if ($PSCmdlet.ShouldProcess($displayName, 'Create Administrative Unit')) {
            $au = New-MgDirectoryAdministrativeUnit -Body $body
            Write-Log "Created: $displayName (ID: $($au.Id))" -Level 'SUCCESS'
        }
    }

    # Deploy scoped role assignments if present
    if ($json.scopedRoleAssignments -and $au) {
        Deploy-ScopedRoleAssignments -AU $au -Assignments $json.scopedRoleAssignments
    }
}

#endregion

#region --- Main ---

Assert-RequiredModules
Connect-GraphWithManagedIdentity

if ($AUFile) {
    if (-not (Test-Path $AUFile)) {
        throw "AU file not found: $AUFile"
    }
    Write-Log "Deploying single AU: $AUFile"
    Deploy-AUFromFile -FilePath $AUFile
}
else {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $auDir    = Join-Path $repoRoot 'administrative-units' 'units'
    $auFiles  = Get-ChildItem -Path $auDir -Filter '*.json' | Sort-Object Name

    Write-Log "Found $($auFiles.Count) AU files in $auDir"

    foreach ($file in $auFiles) {
        Write-Log "Processing: $($file.Name)"
        Deploy-AUFromFile -FilePath $file.FullName
    }
}

Write-Log "Administrative Unit deployment complete for environment: $Environment" -Level 'SUCCESS'

#endregion
