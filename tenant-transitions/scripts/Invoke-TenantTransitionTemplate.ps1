param(
    [string]$TemplatePath = (Join-Path $PSScriptRoot "../templates/tenant-transition-plan.template.json")
)

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template not found: $TemplatePath"
}

$template = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json
Write-Host "Loaded Tenant Transition template: $($template.projectName)"
$template | ConvertTo-Json -Depth 20
