param(
    [string]$RootPath = (Resolve-Path "$PSScriptRoot/..").Path
)

$jsonFiles = Get-ChildItem -Path $RootPath -Recurse -File -Include '*.template.json'
$invalidFiles = [System.Collections.Generic.List[string]]::new()

foreach ($file in $jsonFiles) {
    try {
        Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json | Out-Null
    }
    catch {
        Write-Host "Invalid JSON: $($file.FullName)"
        Write-Host "Reason: $($_.Exception.Message)"
        [void]$invalidFiles.Add($file.FullName)
    }
}

if ($invalidFiles.Count -gt 0) {
    Write-Host "Validation failed. Invalid JSON file count: $($invalidFiles.Count)"
    exit 1
}

Write-Host "Validation passed. Files checked: $($jsonFiles.Count)"
exit 0
