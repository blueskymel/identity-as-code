<#
.SYNOPSIS
    Rolls back Entra ID role assignments created by the pipeline.

.DESCRIPTION
    Removes active or eligible (PIM) role assignments that were created during deployment.
    Uses the role assignment JSON files as the source of truth for what to remove.

.PARAMETER AssignmentName
    Name of the assignment set to roll back (matches the assignmentName field in JSON).
    If omitted, all assignments in role-assignments/assignments/ are rolled back.

.PARAMETER RemoveEligible
    Also remove PIM eligible assignments in addition to active assignments.

.EXAMPLE
    pwsh rollback/scripts/rollback-role-assignments.ps1 -AssignmentName helpdesk-admins
    pwsh rollback/scripts/rollback-role-assignments.ps1 -RemoveEligible
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]$AssignmentName,

    [Parameter()]
    [switch]$RemoveEligible
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
            throw "Required module '$mod' is not installed."
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

function Remove-ActiveRoleAssignment {
    param([string]$RoleTemplateId, [string]$PrincipalId, [string]$PrincipalRef)
    $assignments = Get-MgRoleManagementDirectoryRoleAssignment -Filter "roleDefinitionId eq '$RoleTemplateId' and principalId eq '$PrincipalId'"
    foreach ($assignment in $assignments) {
        Write-Log "  Removing active assignment (ID: $($assignment.Id)) for $PrincipalRef"
        if ($PSCmdlet.ShouldProcess($assignment.Id, 'Remove Active Role Assignment')) {
            Remove-MgRoleManagementDirectoryRoleAssignment -UnifiedRoleAssignmentId $assignment.Id
            Write-Log "  Removed." -Level 'SUCCESS'
        }
    }
}

function Remove-EligibleRoleAssignment {
    param([string]$RoleTemplateId, [string]$PrincipalId, [string]$PrincipalRef)
    $schedules = Get-MgRoleManagementDirectoryRoleEligibilitySchedule -Filter "roleDefinitionId eq '$RoleTemplateId' and principalId eq '$PrincipalId'"
    foreach ($schedule in $schedules) {
        Write-Log "  Removing PIM eligible assignment (Schedule ID: $($schedule.Id)) for $PrincipalRef"
        if ($PSCmdlet.ShouldProcess($schedule.Id, 'Remove PIM Eligible Assignment')) {
            $body = @{
                action           = 'adminRemove'
                justification    = 'Identity-as-Code rollback'
                roleDefinitionId = $RoleTemplateId
                directoryScopeId = '/'
                principalId      = $PrincipalId
            } | ConvertTo-Json
            New-MgRoleManagementDirectoryRoleEligibilityScheduleRequest -Body $body
            Write-Log "  PIM eligible assignment removed." -Level 'SUCCESS'
        }
    }
}

function Rollback-AssignmentFile {
    param([string]$FilePath)

    $json           = Get-Content -Raw -Path $FilePath | ConvertFrom-Json
    $roleTemplateId = $json.role.templateId
    Write-Log "Processing rollback for: $($json.assignmentName) ($($json.role.displayName))"

    # Remove active assignments
    foreach ($a in $json.assignments) {
        try {
            $principalId = Resolve-PrincipalId -Ref $a.principalRef -Type $a.principalType
            Remove-ActiveRoleAssignment -RoleTemplateId $roleTemplateId -PrincipalId $principalId -PrincipalRef $a.principalRef
        }
        catch {
            Write-Log "  Could not resolve principal '$($a.principalRef)': $_" -Level 'WARN'
        }
    }

    # Remove scoped assignments
    foreach ($sa in $json.scopedAssignments) {
        try {
            $principalId = Resolve-PrincipalId -Ref $sa.principalRef -Type $sa.principalType
            Remove-ActiveRoleAssignment -RoleTemplateId $roleTemplateId -PrincipalId $principalId -PrincipalRef $sa.principalRef
        }
        catch {
            Write-Log "  Could not resolve principal '$($sa.principalRef)': $_" -Level 'WARN'
        }
    }

    # Remove eligible assignments (PIM) if requested
    if ($RemoveEligible) {
        foreach ($e in $json.eligibleAssignments) {
            try {
                $principalId = Resolve-PrincipalId -Ref $e.principalRef -Type $e.principalType
                Remove-EligibleRoleAssignment -RoleTemplateId $roleTemplateId -PrincipalId $principalId -PrincipalRef $e.principalRef
            }
            catch {
                Write-Log "  Could not resolve principal '$($e.principalRef)': $_" -Level 'WARN'
            }
        }
    }
}

#endregion

#region --- Main ---

Assert-RequiredModules
Connect-GraphWithManagedIdentity

$repoRoot       = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$assignmentDir  = Join-Path $repoRoot 'role-assignments' 'assignments'

if ($AssignmentName) {
    $file = Join-Path $assignmentDir "$AssignmentName.json"
    if (-not (Test-Path $file)) {
        throw "Assignment file not found: $file"
    }
    Write-Log "Rolling back assignment: $AssignmentName"
    Rollback-AssignmentFile -FilePath $file
}
else {
    $assignmentFiles = Get-ChildItem -Path $assignmentDir -Filter '*.json' | Sort-Object Name
    Write-Log "Rolling back all $($assignmentFiles.Count) assignment files..."
    foreach ($f in $assignmentFiles) {
        Rollback-AssignmentFile -FilePath $f.FullName
    }
}

Write-Log "Role assignment rollback complete." -Level 'SUCCESS'

#endregion
