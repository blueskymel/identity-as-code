param(
    [string]$TemplatePath = (Join-Path $PSScriptRoot "../templates/lifecycle-workflow.template.json")
)

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template not found: $TemplatePath"
}

$template = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json
Write-Host "Loaded Lifecycle Workflow template: $($template.displayName)"
$template | ConvertTo-Json -Depth 20
