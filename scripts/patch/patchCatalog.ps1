# \scripts\patch\patchCatalog.ps1
# Hermes Portable — Патч для catalog.ts
# ============================================================================
param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

if (-not (Test-Path $FilePath)) {
    Write-Error "File not found: $FilePath"
    exit 2
}

$content = Get-Content $FilePath -Raw -Encoding UTF8

if ($content.Contains("import { ru }")) {
    Write-Host "catalog.ts already contains 'ru'."
    exit 1
}

# 1. Add import
$oldImport = "import { zhHant } from './zh-hant'"
$newImport = "import { zhHant } from './zh-hant'`r`nimport { ru } from './ru'"

if ($content.Contains($oldImport)) {
    $content = $content.Replace($oldImport, $newImport)
} else {
    Write-Error "Could not find zhHant import"
    exit 2
}

# 2. Add ru to catalog
$oldCatalog = "  zh,"
$newCatalog = "  zh,`r`n  ru,"

if ($content.Contains($oldCatalog)) {
    $content = $content.Replace($oldCatalog, $newCatalog)
} else {
    Write-Error "Could not find zh in catalog"
    exit 2
}

$content | Set-Content $FilePath -NoNewline -Encoding UTF8
Write-Host "catalog.ts patched."
exit 0