<#
.SYNOPSIS
    Deploys Conditional Access policies from JSON templates to Microsoft Entra ID.

.DESCRIPTION
    Reads CA policy JSON files and creates or updates policies via Microsoft Graph API.
    Supports WhatIf mode, single-policy deployment, and environment-specific state overrides.

.PARAMETER Environment
    Target environment: dev, staging, or prod.

.PARAMETER PolicyFile
    Path to a specific policy JSON file. If omitted, all policies in conditional-access/policies/ are deployed.

.PARAMETER WhatIf
    Preview changes without applying them.

.PARAMETER StateOverride
    Override policy state for non-prod environments: 'enabledForReportingButNotEnforced' (report-only).

.EXAMPLE
    pwsh scripts/deploy-ca-policies.ps1 -Environment prod -WhatIf
    pwsh scripts/deploy-ca-policies.ps1 -Environment dev -StateOverride enabledForReportingButNotEnforced
    pwsh scripts/deploy-ca-policies.ps1 -Environment prod -PolicyFile conditional-access/policies/001-block-legacy-auth.json
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter()]
    [string]$PolicyFile,

    [Parameter()]
    [ValidateSet('enabled', 'disabled', 'enabledForReportingButNotEnforced')]
    [string]$StateOverride
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
            throw "Required module '$mod' is not installed. Run: Install-Module $mod"
        }
    }
}

function Connect-GraphWithManagedIdentity {
    Write-Log "Connecting to Microsoft Graph..."
    Connect-MgGraph -Identity -NoWelcome
    Write-Log "Connected to Microsoft Graph." -Level 'SUCCESS'
}

function Get-ExistingPolicy {
    param([string]$DisplayName)
    try {
        $policies = Get-MgIdentityConditionalAccessPolicy -Filter "displayName eq '$DisplayName'"
        return $policies | Select-Object -First 1
    }
    catch {
        return $null
    }
}

function Deploy-CAPolicyFromFile {
    param([string]$FilePath)

    $json   = Get-Content -Raw -Path $FilePath | ConvertFrom-Json
    $policy = $json.policy

    if ($StateOverride) {
        Write-Log "Overriding state to '$StateOverride' for $Environment environment."
        $policy.state = $StateOverride
    }

    $displayName = $policy.displayName
    $existing    = Get-ExistingPolicy -DisplayName $displayName

    $body = $policy | ConvertTo-Json -Depth 20

    if ($existing) {
        Write-Log "Updating existing policy: $displayName (ID: $($existing.Id))"
        if ($PSCmdlet.ShouldProcess($displayName, 'Update Conditional Access Policy')) {
            Update-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $existing.Id -Body $body
            Write-Log "Updated: $displayName" -Level 'SUCCESS'
        }
    }
    else {
        Write-Log "Creating new policy: $displayName"
        if ($PSCmdlet.ShouldProcess($displayName, 'Create Conditional Access Policy')) {
            New-MgIdentityConditionalAccessPolicy -Body $body
            Write-Log "Created: $displayName" -Level 'SUCCESS'
        }
    }
}

#endregion

#region --- Main ---

Assert-RequiredModules
Connect-GraphWithManagedIdentity

# Apply safe default: non-prod environments use report-only mode unless explicitly overridden
if (-not $StateOverride -and $Environment -ne 'prod') {
    $StateOverride = 'enabledForReportingButNotEnforced'
    Write-Log "Non-prod environment detected — defaulting to report-only mode. Use -StateOverride to change." -Level 'WARN'
}

if ($PolicyFile) {
    if (-not (Test-Path $PolicyFile)) {
        throw "Policy file not found: $PolicyFile"
    }
    Write-Log "Deploying single policy: $PolicyFile"
    Deploy-CAPolicyFromFile -FilePath $PolicyFile
}
else {
    $repoRoot   = Split-Path -Parent $PSScriptRoot
    $policyDir  = Join-Path $repoRoot 'conditional-access' 'policies'
    $policyFiles = Get-ChildItem -Path $policyDir -Filter '*.json' | Sort-Object Name

    Write-Log "Found $($policyFiles.Count) policy files in $policyDir"

    foreach ($file in $policyFiles) {
        Write-Log "Processing: $($file.Name)"
        Deploy-CAPolicyFromFile -FilePath $file.FullName
    }
}

Write-Log "CA policy deployment complete for environment: $Environment" -Level 'SUCCESS'

#endregion
