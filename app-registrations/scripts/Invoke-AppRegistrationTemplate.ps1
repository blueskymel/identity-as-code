param(
    [string]$TemplatePath = (Join-Path $PSScriptRoot "../templates/app-registration.template.json")
)

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template not found: $TemplatePath"
}

$template = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json
Write-Host "Loaded App Registration template: $($template.displayName)"
$template | ConvertTo-Json -Depth 20
