<#
.SYNOPSIS
    Deploys dynamic and assigned group definitions from JSON templates to Microsoft Entra ID.

.DESCRIPTION
    Reads group JSON files and creates or updates groups via Microsoft Graph API.
    Supports WhatIf mode and single-group deployment.

.PARAMETER Environment
    Target environment: dev, staging, or prod.

.PARAMETER GroupFile
    Path to a specific group JSON file. If omitted, all groups in dynamic-groups/groups/ are deployed.

.PARAMETER WhatIf
    Preview changes without applying them.

.EXAMPLE
    pwsh scripts/deploy-dynamic-groups.ps1 -Environment prod -WhatIf
    pwsh scripts/deploy-dynamic-groups.ps1 -Environment prod
    pwsh scripts/deploy-dynamic-groups.ps1 -Environment prod -GroupFile dynamic-groups/groups/grp-all-employees.json
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment,

    [Parameter()]
    [string]$GroupFile,

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
    $required = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Groups')
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

function Get-ExistingGroup {
    param([string]$DisplayName)
    try {
        $groups = Get-MgGroup -Filter "displayName eq '$DisplayName'"
        return $groups | Select-Object -First 1
    }
    catch {
        return $null
    }
}

function Deploy-GroupFromFile {
    param([string]$FilePath)

    $json        = Get-Content -Raw -Path $FilePath | ConvertFrom-Json
    $groupDef    = $json.group
    $displayName = $groupDef.displayName
    $existing    = Get-ExistingGroup -DisplayName $displayName

    # Build the Graph request body — only include dynamic membership fields if applicable
    $body = @{
        displayName              = $groupDef.displayName
        description              = $groupDef.description
        groupTypes               = $groupDef.groupTypes
        mailEnabled              = $groupDef.mailEnabled
        mailNickname             = $groupDef.mailNickname
        securityEnabled          = $groupDef.securityEnabled
    }

    if ($groupDef.membershipRule) {
        $body['membershipRule']                 = $groupDef.membershipRule
        $body['membershipRuleProcessingState']  = $groupDef.membershipRuleProcessingState
    }

    $bodyJson = $body | ConvertTo-Json -Depth 10

    if ($existing) {
        Write-Log "Updating existing group: $displayName (ID: $($existing.Id))"
        if ($PSCmdlet.ShouldProcess($displayName, 'Update Group')) {
            Update-MgGroup -GroupId $existing.Id -Body $bodyJson
            Write-Log "Updated: $displayName" -Level 'SUCCESS'
        }
    }
    else {
        Write-Log "Creating new group: $displayName"
        if ($PSCmdlet.ShouldProcess($displayName, 'Create Group')) {
            New-MgGroup -Body $bodyJson
            Write-Log "Created: $displayName" -Level 'SUCCESS'
        }
    }
}

#endregion

#region --- Main ---

Assert-RequiredModules
Connect-GraphWithManagedIdentity

if ($GroupFile) {
    if (-not (Test-Path $GroupFile)) {
        throw "Group file not found: $GroupFile"
    }
    Write-Log "Deploying single group: $GroupFile"
    Deploy-GroupFromFile -FilePath $GroupFile
}
else {
    $repoRoot  = Split-Path -Parent $PSScriptRoot
    $groupDir  = Join-Path $repoRoot 'dynamic-groups' 'groups'
    $groupFiles = Get-ChildItem -Path $groupDir -Filter '*.json' | Sort-Object Name

    Write-Log "Found $($groupFiles.Count) group files in $groupDir"

    foreach ($file in $groupFiles) {
        Write-Log "Processing: $($file.Name)"
        Deploy-GroupFromFile -FilePath $file.FullName
    }
}

Write-Log "Group deployment complete for environment: $Environment" -Level 'SUCCESS'

#endregion
