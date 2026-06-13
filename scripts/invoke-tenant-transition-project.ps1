<#
.SYNOPSIS
    Executes identity consolidation and separation project workflows for tenant-to-tenant transitions.

.DESCRIPTION
    Implements discovery, export, identity mapping, migration, SSO validation support, and separation
    controls for M&A and divestiture scenarios using Microsoft Graph PowerShell.

.PARAMETER Action
    Transition action to execute.

.PARAMETER OutputPath
    Directory where generated CSV/JSON output files are written.

.PARAMETER SourceUsersCsv
    Source users CSV for identity mapping.

.PARAMETER TargetUsersCsv
    Target users CSV for identity mapping.

.PARAMETER MappingFile
    Identity mapping CSV produced by MapIdentities.

.PARAMETER GroupMembershipCsv
    Group membership CSV produced by ExportGroupMemberships.

.PARAMETER SsoPlanFile
    JSON file describing SSO applications to validate.

.PARAMETER SeparationPlanFile
    JSON file describing user removals and application disable actions.

.PARAMETER CreateMissingUsers
    During migration, create users in the target tenant when mapping has no target identity match.

.PARAMETER DefaultPassword
    Temporary password used when CreateMissingUsers is enabled.

.PARAMETER UseManagedIdentity
    Use managed identity authentication instead of delegated interactive authentication.

.EXAMPLE
    pwsh scripts/invoke-tenant-transition-project.ps1 -Action ReviewTenantStructure -UseManagedIdentity

.EXAMPLE
    pwsh scripts/invoke-tenant-transition-project.ps1 -Action MapIdentities `
      -SourceUsersCsv ./tenant-transitions/output/source-users.csv `
      -TargetUsersCsv ./tenant-transitions/output/target-users.csv
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        'ReviewTenantStructure',
        'ExportGroupMemberships',
        'MapIdentities',
        'MigrateIdentities',
        'TestSsoApplications',
        'RunSeparationProject'
    )]
    [string]$Action,

    [Parameter()]
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'tenant-transitions' 'output'),

    [Parameter()]
    [string]$SourceUsersCsv,

    [Parameter()]
    [string]$TargetUsersCsv,

    [Parameter()]
    [string]$MappingFile,

    [Parameter()]
    [string]$GroupMembershipCsv,

    [Parameter()]
    [string]$SsoPlanFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'tenant-transitions' 'templates' 'sso-test-plan.template.json'),

    [Parameter()]
    [string]$SeparationPlanFile = (Join-Path (Split-Path -Parent $PSScriptRoot) 'tenant-transitions' 'templates' 'separation-plan.template.json'),

    [Parameter()]
    [switch]$CreateMissingUsers,

    [Parameter()]
    [string]$DefaultPassword,

    [Parameter()]
    [switch]$UseManagedIdentity
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

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
        'Microsoft.Graph.Users',
        'Microsoft.Graph.Groups',
        'Microsoft.Graph.Applications'
    )
    foreach ($mod in $required) {
        if (-not (Get-Module -ListAvailable -Name $mod)) {
            throw "Required module '$mod' is not installed. Run: Install-Module $mod"
        }
    }
}

function Ensure-OutputPath {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -ItemType Directory -Force | Out-Null
    }
}

function Connect-Graph {
    if ($UseManagedIdentity) {
        Write-Log 'Connecting to Microsoft Graph with managed identity...'
        Connect-MgGraph -Identity -NoWelcome
    }
    else {
        Write-Log 'Connecting to Microsoft Graph with delegated scopes...'
        Connect-MgGraph -Scopes @(
            'User.Read.All',
            'User.ReadWrite.All',
            'Group.Read.All',
            'Group.ReadWrite.All',
            'Application.Read.All',
            'Application.ReadWrite.All',
            'Directory.ReadWrite.All'
        ) -NoWelcome
    }
    Write-Log 'Connected to Microsoft Graph.' -Level 'SUCCESS'
}

function Get-NormalizedValue {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    return $Value.Trim().ToLowerInvariant()
}

function Invoke-ReviewTenantStructure {
    param([string]$Path)
    Ensure-OutputPath -Path $Path

    $usersPath = Join-Path $Path 'source-users.csv'
    $groupsPath = Join-Path $Path 'source-groups.csv'
    $appsPath = Join-Path $Path 'source-applications.csv'

    Write-Log 'Exporting users...'
    Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,Mail,AccountEnabled |
        Select-Object Id,DisplayName,UserPrincipalName,Mail,AccountEnabled |
        Export-Csv -Path $usersPath -NoTypeInformation

    Write-Log 'Exporting groups...'
    Get-MgGroup -All -Property Id,DisplayName,Mail,SecurityEnabled,MailEnabled |
        Select-Object Id,DisplayName,Mail,SecurityEnabled,MailEnabled |
        Export-Csv -Path $groupsPath -NoTypeInformation

    Write-Log 'Exporting applications...'
    Get-MgApplication -All -Property Id,AppId,DisplayName,SignInAudience |
        Select-Object Id,AppId,DisplayName,SignInAudience |
        Export-Csv -Path $appsPath -NoTypeInformation

    Write-Log "Tenant inventory exported to: $Path" -Level 'SUCCESS'
}

function Invoke-ExportGroupMemberships {
    param([string]$Path)
    Ensure-OutputPath -Path $Path

    $membershipsPath = Join-Path $Path 'source-group-memberships.csv'
    $results = [System.Collections.Generic.List[object]]::new()
    $groups = Get-MgGroup -All -Property Id,DisplayName

    foreach ($group in $groups) {
        Write-Log "Exporting members for group: $($group.DisplayName)"
        $members = Get-MgGroupMember -GroupId $group.Id -All
        foreach ($member in $members) {
            $memberType = if ($member.AdditionalProperties.'@odata.type') {
                $member.AdditionalProperties.'@odata.type'
            }
            else {
                ''
            }

            $results.Add([pscustomobject]@{
                GroupId                = $group.Id
                GroupDisplayName       = $group.DisplayName
                MemberId               = $member.Id
                MemberType             = $memberType
                MemberDisplayName      = $member.AdditionalProperties.displayName
                MemberUserPrincipalName = $member.AdditionalProperties.userPrincipalName
                MemberMail             = $member.AdditionalProperties.mail
            })
        }
    }

    $results | Export-Csv -Path $membershipsPath -NoTypeInformation
    Write-Log "Group memberships exported to: $membershipsPath" -Level 'SUCCESS'
}

function Invoke-MapIdentities {
    param(
        [string]$SourcePath,
        [string]$TargetPath,
        [string]$OutPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) { throw "Source users CSV not found: $SourcePath" }
    if (-not (Test-Path -LiteralPath $TargetPath)) { throw "Target users CSV not found: $TargetPath" }
    Ensure-OutputPath -Path $OutPath

    $mappingPath = Join-Path $OutPath 'identity-mapping.csv'
    $sourceUsers = Import-Csv -Path $SourcePath
    $targetUsers = Import-Csv -Path $TargetPath

    $targetByMail = @{}
    $targetByUpn = @{}
    foreach ($target in $targetUsers) {
        $mail = Get-NormalizedValue -Value $target.Mail
        $upn = Get-NormalizedValue -Value $target.UserPrincipalName
        if ($mail -and -not $targetByMail.ContainsKey($mail)) { $targetByMail[$mail] = $target }
        if ($upn -and -not $targetByUpn.ContainsKey($upn)) { $targetByUpn[$upn] = $target }
    }

    $rows = foreach ($source in $sourceUsers) {
        $sourceMail = Get-NormalizedValue -Value $source.Mail
        $sourceUpn = Get-NormalizedValue -Value $source.UserPrincipalName
        $match = $null
        $matchType = 'none'

        if ($sourceMail -and $targetByMail.ContainsKey($sourceMail)) {
            $match = $targetByMail[$sourceMail]
            $matchType = 'mail'
        }
        elseif ($sourceUpn -and $targetByUpn.ContainsKey($sourceUpn)) {
            $match = $targetByUpn[$sourceUpn]
            $matchType = 'userPrincipalName'
        }

        [pscustomobject]@{
            SourceId                  = $source.Id
            SourceDisplayName         = $source.DisplayName
            SourceUserPrincipalName   = $source.UserPrincipalName
            SourceMail                = $source.Mail
            TargetId                  = $match.Id
            TargetDisplayName         = $match.DisplayName
            TargetUserPrincipalName   = $match.UserPrincipalName
            TargetMail                = $match.Mail
            MatchType                 = $matchType
            PreserveMailbox           = $true
            PreserveTeams             = $true
            PreserveSharePoint        = $true
            PreserveAppPermissions    = $true
            PreserveGroupMemberships  = $true
        }
    }

    $rows | Export-Csv -Path $mappingPath -NoTypeInformation
    Write-Log "Identity mapping exported to: $mappingPath" -Level 'SUCCESS'
}

function New-SecurePassword {
    param([int]$Length = 24)

    if ($Length -lt 12) { $Length = 12 }

    $lower = 'abcdefghijkmnopqrstuvwxyz'
    $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
    $digits = '23456789'
    $special = '!@#$%^&*()-_=+[]{}'
    $all = "$lower$upper$digits$special"

    $bytes = New-Object byte[] ($Length * 2)
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)

    $chars = [System.Collections.Generic.List[char]]::new()
    $chars.Add($lower[$bytes[0] % $lower.Length])
    $chars.Add($upper[$bytes[1] % $upper.Length])
    $chars.Add($digits[$bytes[2] % $digits.Length])
    $chars.Add($special[$bytes[3] % $special.Length])

    for ($i = 4; $i -lt $Length; $i++) {
        $chars.Add($all[$bytes[$i] % $all.Length])
    }

    for ($i = $chars.Count - 1; $i -gt 0; $i--) {
        $swap = $bytes[$i + $Length] % ($i + 1)
        $tmp = $chars[$i]
        $chars[$i] = $chars[$swap]
        $chars[$swap] = $tmp
    }

    return -join $chars
}

function Get-UniqueMailNickname {
    param([string]$Preferred)

    $base = if ([string]::IsNullOrWhiteSpace($Preferred)) {
        "user$([guid]::NewGuid().ToString('N').Substring(0,8))"
    }
    else {
        $Preferred
    }

    for ($i = 0; $i -lt 20; $i++) {
        $candidate = if ($i -eq 0) { $base } else { "$base$i" }
        $existing = Get-MgUser -Filter "mailNickname eq '$candidate'" -Top 1
        if (-not $existing) {
            return $candidate
        }
    }

    return "user$([guid]::NewGuid().ToString('N').Substring(0,12))"
}

function Invoke-MigrateIdentities {
    param(
        [string]$IdentityMappingPath,
        [string]$MembershipPath
    )

    if (-not (Test-Path -LiteralPath $IdentityMappingPath)) { throw "Mapping file not found: $IdentityMappingPath" }
    if (-not (Test-Path -LiteralPath $MembershipPath)) { throw "Group membership file not found: $MembershipPath" }

    $mapping = Import-Csv -Path $IdentityMappingPath
    $memberships = Import-Csv -Path $MembershipPath
    $targetGroups = Get-MgGroup -All -Property Id,DisplayName
    $targetGroupsByDisplayName = @{}
    foreach ($group in $targetGroups) {
        $name = Get-NormalizedValue -Value $group.DisplayName
        if ($name -and -not $targetGroupsByDisplayName.ContainsKey($name)) {
            $targetGroupsByDisplayName[$name] = $group
        }
    }

    foreach ($row in $mapping) {
        $targetId = $row.TargetId
        if ([string]::IsNullOrWhiteSpace($targetId) -and $CreateMissingUsers) {
            $upn = $row.SourceUserPrincipalName
            if ([string]::IsNullOrWhiteSpace($upn)) {
                Write-Log "Skipping user creation for '$($row.SourceDisplayName)' because SourceUserPrincipalName is empty." -Level 'WARN'
                continue
            }

            $password = if ([string]::IsNullOrWhiteSpace($DefaultPassword)) { New-SecurePassword } else { $DefaultPassword }
            $mailAliasRaw = $upn.Split('@')[0]
            $mailAliasClean = ($mailAliasRaw -replace '[^a-zA-Z0-9\-_]', '')
            if ($mailAliasClean.Length -gt 40) {
                $mailAliasClean = $mailAliasClean.Substring(0, 40)
            }
            $mailNickname = Get-UniqueMailNickname -Preferred $mailAliasClean
            $newUserBody = @{
                accountEnabled    = $true
                displayName       = $row.SourceDisplayName
                mailNickname      = $mailNickname
                userPrincipalName = $upn
                passwordProfile   = @{
                    forceChangePasswordNextSignIn = $true
                    password                      = $password
                }
            }

            if ($PSCmdlet.ShouldProcess($upn, 'Create target tenant user')) {
                try {
                    $newUser = New-MgUser -BodyParameter $newUserBody
                    $targetId = $newUser.Id
                    Write-Log "Created target user: $upn" -Level 'SUCCESS'
                }
                catch {
                    Write-Log "Failed to create target user '$upn'. Error: $($_.Exception.Message)" -Level 'WARN'
                    continue
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($targetId)) {
            Write-Log "No target user mapped for source user '$($row.SourceDisplayName)'. Skipping membership migration." -Level 'WARN'
            continue
        }

        $sourceIdentityKeys = @(
            Get-NormalizedValue -Value $row.SourceUserPrincipalName
            Get-NormalizedValue -Value $row.SourceMail
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

        $userMemberships = $memberships | Where-Object {
            $mUpn = Get-NormalizedValue -Value $_.MemberUserPrincipalName
            $mMail = Get-NormalizedValue -Value $_.MemberMail
            ($sourceIdentityKeys -contains $mUpn) -or ($sourceIdentityKeys -contains $mMail)
        }

        foreach ($membership in $userMemberships) {
            $groupName = Get-NormalizedValue -Value $membership.GroupDisplayName
            if (-not $groupName -or -not $targetGroupsByDisplayName.ContainsKey($groupName)) {
                Write-Log "Target group not found for source group '$($membership.GroupDisplayName)'." -Level 'WARN'
                continue
            }

            $targetGroup = $targetGroupsByDisplayName[$groupName]
            if ($PSCmdlet.ShouldProcess("$($targetGroup.DisplayName) -> $targetId", 'Assign group membership')) {
                try {
                    New-MgGroupMemberByRef -GroupId $targetGroup.Id -BodyParameter @{
                        '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$targetId"
                    } | Out-Null
                    Write-Log "Assigned user $targetId to group '$($targetGroup.DisplayName)'." -Level 'SUCCESS'
                }
                catch {
                    if ($_.Exception.Message -like '*already exist*') {
                        Write-Log "Membership already exists in '$($targetGroup.DisplayName)'." -Level 'WARN'
                    }
                    else {
                        Write-Log "Failed to assign group '$($targetGroup.DisplayName)': $($_.Exception.Message)" -Level 'WARN'
                    }
                }
            }
        }
    }

    Write-Log 'Identity migration workflow completed.' -Level 'SUCCESS'
}

function Invoke-TestSsoApplications {
    param(
        [string]$PlanPath,
        [string]$OutPath
    )

    if (-not (Test-Path -LiteralPath $PlanPath)) { throw "SSO plan file not found: $PlanPath" }
    Ensure-OutputPath -Path $OutPath

    $apps = (Get-Content -Path $PlanPath -Raw | ConvertFrom-Json).applications
    $resultsPath = Join-Path $OutPath 'sso-test-results.csv'

    $results = foreach ($app in $apps) {
        $sp = $null
        if ($app.servicePrincipalAppId) {
            $sp = Get-MgServicePrincipal -Filter "appId eq '$($app.servicePrincipalAppId)'" | Select-Object -First 1
        }

        $protocolCheck = 'not-configured'
        $notes = @()

        if ($app.protocol -in @('OAuth', 'OpenID Connect') -and $app.oidcDiscoveryUrl) {
            try {
                $meta = Invoke-RestMethod -Uri $app.oidcDiscoveryUrl -Method Get
                if ($meta.authorization_endpoint -and $meta.token_endpoint) {
                    $protocolCheck = 'reachable'
                }
                else {
                    $protocolCheck = 'metadata-incomplete'
                    $notes += 'OIDC metadata missing authorization/token endpoints.'
                }
            }
            catch {
                $protocolCheck = 'unreachable'
                $notes += "OIDC metadata request failed: $($_.Exception.Message)"
            }
        }
        elseif ($app.protocol -eq 'SAML') {
            if ($sp -and $sp.PreferredSingleSignOnMode -eq 'saml') {
                $protocolCheck = 'configured'
            }
            else {
                $protocolCheck = 'not-configured'
                $notes += 'Service principal SSO mode is not SAML or service principal not found.'
            }
        }

        [pscustomobject]@{
            ApplicationDisplayName = $app.displayName
            Protocol               = $app.protocol
            LoginTestStatus        = 'manual-required'
            ProtocolCheckStatus    = $protocolCheck
            ServicePrincipalFound  = [bool]$sp
            Notes                  = ($notes -join ' ')
        }
    }

    $results | Export-Csv -Path $resultsPath -NoTypeInformation
    Write-Log "SSO test support output written to: $resultsPath" -Level 'SUCCESS'
}

function Invoke-RunSeparationProject {
    param([string]$PlanPath)

    if (-not (Test-Path -LiteralPath $PlanPath)) { throw "Separation plan file not found: $PlanPath" }
    $plan = Get-Content -Path $PlanPath -Raw | ConvertFrom-Json

    foreach ($user in $plan.usersToMove) {
        $resolved = Get-MgUser -Filter "userPrincipalName eq '$($user.userPrincipalName)'" | Select-Object -First 1
        if (-not $resolved) {
            Write-Log "User not found in source tenant: $($user.userPrincipalName)" -Level 'WARN'
            continue
        }

        Write-Log "Processing separation actions for: $($user.userPrincipalName)"
        foreach ($groupId in $user.removeFromGroupIds) {
            if ($PSCmdlet.ShouldProcess("$groupId -> $($resolved.Id)", 'Remove group membership')) {
                try {
                    Remove-MgGroupMemberByRef -GroupId $groupId -DirectoryObjectId $resolved.Id
                    Write-Log "Removed $($user.userPrincipalName) from group $groupId." -Level 'SUCCESS'
                }
                catch {
                    Write-Log "Failed to remove group membership ($groupId): $($_.Exception.Message)" -Level 'WARN'
                }
            }
        }
    }

    foreach ($app in $plan.applicationsToDisable) {
        $sp = Get-MgServicePrincipal -Filter "appId eq '$($app.appId)'" | Select-Object -First 1
        if (-not $sp) {
            Write-Log "Service principal not found for appId: $($app.appId)" -Level 'WARN'
            continue
        }

        if ($PSCmdlet.ShouldProcess($sp.DisplayName, 'Disable enterprise application')) {
            Update-MgServicePrincipal -ServicePrincipalId $sp.Id -BodyParameter @{ accountEnabled = $false } | Out-Null
            Write-Log "Disabled enterprise app: $($sp.DisplayName)" -Level 'SUCCESS'
        }
    }

    Write-Log 'Separation workflow completed. Review outputs and run post-cutover access audits.' -Level 'SUCCESS'
}

Assert-RequiredModules
Connect-Graph

switch ($Action) {
    'ReviewTenantStructure' {
        Invoke-ReviewTenantStructure -Path $OutputPath
    }
    'ExportGroupMemberships' {
        Invoke-ExportGroupMemberships -Path $OutputPath
    }
    'MapIdentities' {
        if (-not $SourceUsersCsv) { throw '-SourceUsersCsv is required for MapIdentities.' }
        if (-not $TargetUsersCsv) { throw '-TargetUsersCsv is required for MapIdentities.' }
        Invoke-MapIdentities -SourcePath $SourceUsersCsv -TargetPath $TargetUsersCsv -OutPath $OutputPath
    }
    'MigrateIdentities' {
        if (-not $MappingFile) { throw '-MappingFile is required for MigrateIdentities.' }
        if (-not $GroupMembershipCsv) { throw '-GroupMembershipCsv is required for MigrateIdentities.' }
        Invoke-MigrateIdentities -IdentityMappingPath $MappingFile -MembershipPath $GroupMembershipCsv
    }
    'TestSsoApplications' {
        Invoke-TestSsoApplications -PlanPath $SsoPlanFile -OutPath $OutputPath
    }
    'RunSeparationProject' {
        Invoke-RunSeparationProject -PlanPath $SeparationPlanFile
    }
}

Disconnect-MgGraph | Out-Null
