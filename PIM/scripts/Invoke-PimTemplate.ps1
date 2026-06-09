param(
    [string]$TemplatePath = (Join-Path $PSScriptRoot "../templates/pim-role-policy.template.json")
)

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template not found: $TemplatePath"
}

$template = Get-Content -LiteralPath $TemplatePath -Raw | ConvertFrom-Json
Write-Host "Loaded PIM template for role: $($template.roleDefinitionDisplayName)"
$template | ConvertTo-Json -Depth 20
