<#
.SYNOPSIS
    Deploys Entra ID role assignments and PIM eligible assignments from JSON definitions.

.DESCRIPTION
    Reads role assignment JSON files and creates permanent active assignments and PIM
    eligible assignments via Microsoft Graph. Supports WhatIf mode.

.PARAMETER Environment
    Target environment: dev, staging, or prod.

.PARAMETER AssignmentFile
    Path to a specific assignment JSON file. If omitted, all files in role-assignments/assignments/ are deployed.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    pwsh scripts/deploy-role-assignments.ps1 -Environment prod -WhatIf
    pwsh scripts/deploy-role-assignments.ps1 -Environment prod
    pwsh scripts/deploy-role-assignments.ps1 -Environment prod -AssignmentFile role-assignments/assignments/helpdesk-admins.json
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter()]
    [string]$AssignmentFile,

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
    $required = @(
        'Microsoft.Graph.Authentication',
        'Microsoft.Graph.Identity.Governance',
        'Microsoft.Graph.Identity.DirectoryManagement'
    )
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

function Resolve-PrincipalId {
    param([string]$Ref, [string]$Type)
    switch ($Type) {
        'user'  { return (Get-MgUser -UserId $Ref).Id }
        'group' { return (Get-MgGroup -Filter "displayName eq '$Ref'" | Select-Object -First 1).Id }
        default { throw "Unknown principal type: $Type" }
    }
}

function Get-AUId {
    param([string]$AUName)
    $au = Get-MgDirectoryAdministrativeUnit -Filter "displayName eq '$AUName'" | Select-Object -First 1
    if (-not $au) { throw "Administrative Unit not found: $AUName" }
    return $au.Id
}

function Deploy-ActiveAssignment {
    param($RoleTemplateId, $PrincipalId, $PrincipalRef, $RoleName, [string]$AUId = $null)
    $scope = if ($AUId) { "/administrativeUnits/$AUId" } else { "/" }
    Write-Log "  Active assignment: '$RoleName' -> '$PrincipalRef' (scope: $scope)"
    if ($PSCmdlet.ShouldProcess("$RoleName -> $PrincipalRef", 'Create Active Role Assignment')) {
        $body = @{
            '@odata.type'    = '#microsoft.graph.unifiedRoleAssignment'
            roleDefinitionId = $RoleTemplateId
            principalId      = $PrincipalId
            directoryScopeId = $scope
        } | ConvertTo-Json

        try {
            New-MgRoleManagementDirectoryRoleAssignment -Body $body
            Write-Log "  Active assignment created." -Level 'SUCCESS'
        }
        catch {
            if ($_.Exception.Message -like '*already exists*') {
                Write-Log "  Assignment already exists — skipping." -Level 'WARN'
            }
            else {
                throw
            }
        }
    }
}

function Deploy-EligibleAssignment {
    param($RoleTemplateId, $PrincipalId, $PrincipalRef, $RoleName, $EligibilityDuration)
    Write-Log "  PIM eligible assignment: '$RoleName' -> '$PrincipalRef'"
    if ($PSCmdlet.ShouldProcess("$RoleName -> $PrincipalRef", 'Create PIM Eligible Assignment')) {
        $startDateTime = (Get-Date).ToUniversalTime().ToString('o')

        # Parse ISO 8601 duration (e.g. P365D, P1Y, PT8H) into total days
        $totalDays = 0
        if ($EligibilityDuration -match 'P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?)?') {
            $years   = if ($Matches[1]) { [int]$Matches[1] } else { 0 }
            $months  = if ($Matches[2]) { [int]$Matches[2] } else { 0 }
            $days    = if ($Matches[3]) { [int]$Matches[3] } else { 0 }
            $hours   = if ($Matches[4]) { [int]$Matches[4] } else { 0 }
            $totalDays = ($years * 365) + ($months * 30) + $days + [math]::Ceiling($hours / 24.0)
        }
        if ($totalDays -eq 0) { $totalDays = 365 }   # safe default

        $endDateTime = (Get-Date).AddDays($totalDays).ToUniversalTime().ToString('o')

        $body = @{
            action           = 'adminAssign'
            justification    = 'Identity-as-Code automated deployment'
            roleDefinitionId = $RoleTemplateId
            directoryScopeId = '/'
            principalId      = $PrincipalId
            scheduleInfo     = @{
                startDateTime = $startDateTime
                expiration    = @{
                    type        = 'afterDateTime'
                    endDateTime = $endDateTime
                }
            }
        } | ConvertTo-Json -Depth 10

        try {
            New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -Body $body
            Write-Log "  PIM eligible assignment created." -Level 'SUCCESS'
        }
        catch {
            if ($_.Exception.Message -like '*already exists*') {
                Write-Log "  Eligible assignment already exists — skipping." -Level 'WARN'
            }
            else {
                throw
            }
        }
    }
}

function Deploy-AssignmentsFromFile {
    param([string]$FilePath)

    $json           = Get-Content -Raw -Path $FilePath | ConvertFrom-Json
    $roleTemplateId = $json.role.templateId
    $roleName       = $json.role.displayName

    Write-Log "Processing role: $roleName"

    # Active assignments (direct)
    foreach ($assignment in $json.assignments) {
        $principalId = Resolve-PrincipalId -Ref $assignment.principalRef -Type $assignment.principalType
        $auId        = $null
        if ($json.scopedToAU) {
            $auId = Get-AUId -AUName $json.scopedToAU
        }
        Deploy-ActiveAssignment -RoleTemplateId $roleTemplateId -PrincipalId $principalId `
            -PrincipalRef $assignment.principalRef -RoleName $roleName -AUId $auId
    }

    # Scoped assignments (different AU per principal)
    foreach ($sa in $json.scopedAssignments) {
        $principalId = Resolve-PrincipalId -Ref $sa.principalRef -Type $sa.principalType
        $auId        = Get-AUId -AUName $sa.scopedToAU
        Deploy-ActiveAssignment -RoleTemplateId $roleTemplateId -PrincipalId $principalId `
            -PrincipalRef $sa.principalRef -RoleName $roleName -AUId $auId
    }

    # PIM eligible assignments
    foreach ($eligible in $json.eligibleAssignments) {
        $principalId = Resolve-PrincipalId -Ref $eligible.principalRef -Type $eligible.principalType
        Deploy-EligibleAssignment -RoleTemplateId $roleTemplateId -PrincipalId $principalId `
            -PrincipalRef $eligible.principalRef -RoleName $roleName `
            -EligibilityDuration $eligible.eligibilityDuration
    }
}

#endregion

#region --- Main ---

Assert-RequiredModules
Connect-GraphWithManagedIdentity

if ($AssignmentFile) {
    if (-not (Test-Path $AssignmentFile)) {
        throw "Assignment file not found: $AssignmentFile"
    }
    Write-Log "Deploying single assignment file: $AssignmentFile"
    Deploy-AssignmentsFromFile -FilePath $AssignmentFile
}
else {
    $repoRoot       = Split-Path -Parent $PSScriptRoot
    $assignmentDir  = Join-Path $repoRoot 'role-assignments' 'assignments'
    $assignmentFiles = Get-ChildItem -Path $assignmentDir -Filter '*.json' | Sort-Object Name

    Write-Log "Found $($assignmentFiles.Count) assignment files in $assignmentDir"

    foreach ($file in $assignmentFiles) {
        Write-Log "Processing: $($file.Name)"
        Deploy-AssignmentsFromFile -FilePath $file.FullName
    }
}

Write-Log "Role assignment deployment complete for environment: $Environment" -Level 'SUCCESS'

#endregion
