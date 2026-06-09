param(
    [string]$TemplatePath = (Join-Path $PSScriptRoot "../templates/enterprise-app-assignment.template.json")
)

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template not found: $TemplatePath"
}

$template = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json
Write-Host "Loaded Enterprise App template for appId: $($template.servicePrincipalAppId)"
$template | ConvertTo-Json -Depth 20
