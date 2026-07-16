# \scripts\patch\patchTypes.ps1
# Hermes Portable — Патч для types.ts
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

if ($content.Contains("'ru'")) {
    Write-Host "types.ts already contains 'ru'."
    exit 1
}

$oldLine = "export type Locale = 'en' | 'zh' | 'zh-hant' | 'ja'"
$newLine = "export type Locale = 'en' | 'zh' | 'zh-hant' | 'ja' | 'ru'"

if ($content.Contains($oldLine)) {
    $content = $content.Replace($oldLine, $newLine)
} else {
    Write-Error "Could not find Locale type definition"
    exit 2
}

$content | Set-Content $FilePath -NoNewline -Encoding UTF8
Write-Host "types.ts patched."
exit 0