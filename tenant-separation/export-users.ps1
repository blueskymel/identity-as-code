<#
.SYNOPSIS
    Exports all users from the source tenant including profile, license,
    and manager information.

.PARAMETER OutputPath
    Directory where output CSV files will be written (created if absent).

.PARAMETER UseManagedIdentity
    Use managed identity authentication instead of interactive sign-in.

.EXAMPLE
    pwsh tenant-separation/export-users.ps1 -OutputPath ./tenant-separation/output
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
$connectParams = @{ Scopes = @("User.Read.All","Directory.Read.All") }
if ($UseManagedIdentity) { $connectParams["Identity"] = $true }
Connect-MgGraph @connectParams

# --- Export user profiles ---
Write-Host "Exporting user profiles..."
$selectProps = @(
    "Id","DisplayName","GivenName","Surname","UserPrincipalName",
    "Mail","MailNickname","JobTitle","Department","OfficeLocation",
    "MobilePhone","BusinessPhones","AccountEnabled","UserType",
    "CreatedDateTime","OnPremisesSyncEnabled","OnPremisesSamAccountName",
    "OnPremisesUserPrincipalName","PasswordPolicies"
)

$users = Get-MgUser -All -Property ($selectProps -join ",") |
    Select-Object $selectProps
$users | Export-Csv -Path (Join-Path $OutputPath "users.csv") -NoTypeInformation
Write-Host "  $($users.Count) users exported."

# --- Export manager relationships ---
Write-Host "Exporting manager relationships..."
$managerRows = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($user in $users) {
    try {
        $manager = Get-MgUserManager -UserId $user.Id -ErrorAction SilentlyContinue
        if ($manager) {
            $managerRows.Add([PSCustomObject]@{
                UserId              = $user.Id
                UserPrincipalName   = $user.UserPrincipalName
                ManagerId           = $manager.Id
            })
        }
    }
    catch { }
}

$managerRows | Export-Csv -Path (Join-Path $OutputPath "user-managers.csv") -NoTypeInformation
Write-Host "  $($managerRows.Count) manager relationships exported."

# --- Export assigned licenses ---
Write-Host "Exporting user license assignments..."
$licenseRows = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($user in $users) {
    $licenses = Get-MgUserLicenseDetail -UserId $user.Id -ErrorAction SilentlyContinue
    foreach ($lic in $licenses) {
        $licenseRows.Add([PSCustomObject]@{
            UserId            = $user.Id
            UserPrincipalName = $user.UserPrincipalName
            SkuId             = $lic.SkuId
            SkuPartNumber     = $lic.SkuPartNumber
        })
    }
}

$licenseRows | Export-Csv -Path (Join-Path $OutputPath "user-licenses.csv") -NoTypeInformation
Write-Host "  $($licenseRows.Count) license assignment records exported."

Write-Host ""
Write-Host "User export complete. Files written to: $OutputPath"
