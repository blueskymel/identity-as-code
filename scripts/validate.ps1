<#
.SYNOPSIS
    Validates all JSON template files in the repository before deployment.

.DESCRIPTION
    Performs structural and semantic validation on CA policy, dynamic group,
    administrative unit, and role assignment JSON files. Exits with a non-zero
    code on failure so the pipeline can block deployment.

.PARAMETER Path
    Root path of the repository. Defaults to the parent directory of this script.

.EXAMPLE
    pwsh scripts/validate.ps1
    pwsh scripts/validate.ps1 -Path /repo
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$errors   = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$checked  = 0

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

function Test-JsonParse {
    param([string]$FilePath)
    try {
        $null = Get-Content -Raw -Path $FilePath | ConvertFrom-Json -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Assert-RequiredField {
    param($Obj, [string]$Field, [string]$FilePath)
    if (-not (Get-Member -InputObject $Obj -Name $Field -MemberType NoteProperty)) {
        $script:errors.Add("[$FilePath] Missing required field: '$Field'")
    }
}

function Validate-CAPolicyFile {
    param([string]$FilePath)
    $script:checked++
    if (-not (Test-JsonParse -FilePath $FilePath)) {
        $script:errors.Add("[$FilePath] Invalid JSON")
        return
    }
    $json = Get-Content -Raw -Path $FilePath | ConvertFrom-Json

    Assert-RequiredField -Obj $json -Field 'policyName' -FilePath $FilePath
    Assert-RequiredField -Obj $json -Field 'policy'     -FilePath $FilePath
    Assert-RequiredField -Obj $json -Field 'version'    -FilePath $FilePath

    if ($json.policy) {
        Assert-RequiredField -Obj $json.policy -Field 'displayName' -FilePath $FilePath
        Assert-RequiredField -Obj $json.policy -Field 'state'       -FilePath $FilePath

        $validStates = @('enabled', 'disabled', 'enabledForReportingButNotEnforced')
        if ($json.policy.state -notin $validStates) {
            $script:errors.Add("[$FilePath] Invalid state '$($json.policy.state)'. Must be one of: $($validStates -join ', ')")
        }

        # Warn if no emergency exclusion group
        $excludeGroups = $json.policy.conditions?.users?.excludeGroups ?? @()
        if ('grp-ca-exclusion-emergency' -notin $excludeGroups) {
            $script:warnings.Add("[$FilePath] Policy does not exclude 'grp-ca-exclusion-emergency'. Consider adding break-glass exclusion.")
        }
    }
    Write-Log "  CA policy valid: $($json.policyName)" -Level 'SUCCESS'
}

function Validate-GroupFile {
    param([string]$FilePath)
    $script:checked++
    if (-not (Test-JsonParse -FilePath $FilePath)) {
        $script:errors.Add("[$FilePath] Invalid JSON")
        return
    }
    $json = Get-Content -Raw -Path $FilePath | ConvertFrom-Json

    Assert-RequiredField -Obj $json -Field 'groupName' -FilePath $FilePath
    Assert-RequiredField -Obj $json -Field 'group'     -FilePath $FilePath
    Assert-RequiredField -Obj $json -Field 'version'   -FilePath $FilePath

    if ($json.group) {
        Assert-RequiredField -Obj $json.group -Field 'displayName'     -FilePath $FilePath
        Assert-RequiredField -Obj $json.group -Field 'securityEnabled' -FilePath $FilePath
        Assert-RequiredField -Obj $json.group -Field 'mailNickname'    -FilePath $FilePath

        # Validate dynamic group has a membership rule
        if ($json.group.groupTypes -contains 'DynamicMembership' -and -not $json.group.membershipRule) {
            $script:errors.Add("[$FilePath] Dynamic group must have a 'membershipRule'")
        }
    }
    Write-Log "  Group valid: $($json.groupName)" -Level 'SUCCESS'
}

function Validate-AUFile {
    param([string]$FilePath)
    $script:checked++
    if (-not (Test-JsonParse -FilePath $FilePath)) {
        $script:errors.Add("[$FilePath] Invalid JSON")
        return
    }
    $json = Get-Content -Raw -Path $FilePath | ConvertFrom-Json

    Assert-RequiredField -Obj $json -Field 'auName'              -FilePath $FilePath
    Assert-RequiredField -Obj $json -Field 'administrativeUnit'  -FilePath $FilePath
    Assert-RequiredField -Obj $json -Field 'version'             -FilePath $FilePath

    if ($json.administrativeUnit) {
        Assert-RequiredField -Obj $json.administrativeUnit -Field 'displayName' -FilePath $FilePath
    }
    Write-Log "  AU valid: $($json.auName)" -Level 'SUCCESS'
}

function Validate-RoleAssignmentFile {
    param([string]$FilePath)
    $script:checked++
    if (-not (Test-JsonParse -FilePath $FilePath)) {
        $script:errors.Add("[$FilePath] Invalid JSON")
        return
    }
    $json = Get-Content -Raw -Path $FilePath | ConvertFrom-Json

    Assert-RequiredField -Obj $json -Field 'assignmentName' -FilePath $FilePath
    Assert-RequiredField -Obj $json -Field 'role'           -FilePath $FilePath
    Assert-RequiredField -Obj $json -Field 'version'        -FilePath $FilePath

    if ($json.role) {
        Assert-RequiredField -Obj $json.role -Field 'displayName' -FilePath $FilePath
        Assert-RequiredField -Obj $json.role -Field 'templateId'  -FilePath $FilePath

        # Validate GUID format (case-insensitive)
        $guidRegex = '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
        if ($json.role.templateId -notmatch $guidRegex) {
            $script:errors.Add("[$FilePath] role.templateId '$($json.role.templateId)' is not a valid GUID")
        }
    }
    Write-Log "  Role assignment valid: $($json.assignmentName)" -Level 'SUCCESS'
}

function Validate-TemplateFile {
    param([string]$FilePath)
    $script:checked++
    try {
        $null = Get-Content -Raw -Path $FilePath | ConvertFrom-Json -ErrorAction Stop
        Write-Log "  Template valid: $(Split-Path -Leaf $FilePath)" -Level 'SUCCESS'
    }
    catch {
        $script:errors.Add("[$FilePath] Invalid JSON: $($_.Exception.Message)")
    }
}

#endregion

#region --- Main ---

Write-Log "Starting validation from root: $Path"

# Validate CA policies
$caPolicies = Get-ChildItem -Path (Join-Path $Path 'conditional-access' 'policies') -Filter '*.json' -ErrorAction SilentlyContinue
Write-Log "Validating $($caPolicies.Count) CA policy files..."
foreach ($f in $caPolicies) { Validate-CAPolicyFile -FilePath $f.FullName }

# Validate dynamic groups
$groupFiles = Get-ChildItem -Path (Join-Path $Path 'dynamic-groups' 'groups') -Filter '*.json' -ErrorAction SilentlyContinue
Write-Log "Validating $($groupFiles.Count) group files..."
foreach ($f in $groupFiles) { Validate-GroupFile -FilePath $f.FullName }

# Validate administrative units
$auFiles = Get-ChildItem -Path (Join-Path $Path 'administrative-units' 'units') -Filter '*.json' -ErrorAction SilentlyContinue
Write-Log "Validating $($auFiles.Count) AU files..."
foreach ($f in $auFiles) { Validate-AUFile -FilePath $f.FullName }

# Validate role assignments
$assignmentFiles = Get-ChildItem -Path (Join-Path $Path 'role-assignments' 'assignments') -Filter '*.json' -ErrorAction SilentlyContinue
Write-Log "Validating $($assignmentFiles.Count) role assignment files..."
foreach ($f in $assignmentFiles) { Validate-RoleAssignmentFile -FilePath $f.FullName }

# Validate additional template scaffolding files
$templateFiles = Get-ChildItem -Path $Path -Recurse -Filter '*.template.json' -File -ErrorAction SilentlyContinue
Write-Log "Validating $($templateFiles.Count) template scaffolding files..."
foreach ($f in $templateFiles) { Validate-TemplateFile -FilePath $f.FullName }

# Summary
Write-Log "---"
Write-Log "Files checked: $checked"

if ($warnings.Count -gt 0) {
    Write-Log "$($warnings.Count) warning(s):" -Level 'WARN'
    $warnings | ForEach-Object { Write-Log "  $_" -Level 'WARN' }
}

if ($errors.Count -gt 0) {
    Write-Log "$($errors.Count) error(s):" -Level 'ERROR'
    $errors | ForEach-Object { Write-Log "  $_" -Level 'ERROR' }
    exit 1
}
else {
    Write-Log "All files passed validation." -Level 'SUCCESS'
    exit 0
}

#endregion
