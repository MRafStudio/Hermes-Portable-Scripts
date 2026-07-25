# \scripts\patch\patch_languages.ps1
# Hermes Portable — Патч для languages.ts
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

if ($content.Contains("id: 'ru'")) {
    Write-Host "languages.ts already contains 'ru'."
    exit 1
}

# 1. Add ru to LOCALE_OPTIONS (first, before 'en')
$oldEnBlock = "  {`r`n    id: 'en',`r`n    name: 'English',"
$newEnBlock = "  {`r`n    id: 'ru',`r`n    name: 'Russian',`r`n    englishName: 'Russian',`r`n    configValue: 'ru'`r`n  },`r`n  {`r`n    id: 'en',`r`n    name: 'English',"

if ($content.Contains($oldEnBlock)) {
    $content = $content.Replace($oldEnBlock, $newEnBlock)
} else {
    $oldEnBlockUnix = "  {`n    id: 'en',`n    name: 'English',"
    if ($content.Contains($oldEnBlockUnix)) {
        $newEnBlockUnix = "  {`n    id: 'ru',`n    name: 'Russian',`n    englishName: 'Russian',`n    configValue: 'ru'`n  },`n  {`n    id: 'en',`n    name: 'English',"
        $content = $content.Replace($oldEnBlockUnix, $newEnBlockUnix)
    } else {
        Write-Error "Could not find 'en' locale block"
        exit 2
    }
}

# 2. Add ru aliases to LOCALE_ALIASES (first, before 'en')
$oldAlias = "  en: 'en',`r`n  'en-us': 'en',"
$newAlias = "  ru: 'ru',`r`n  'ru-ru': 'ru',`r`n  ru_ru: 'ru',`r`n  'russkiy': 'ru',`r`n  en: 'en',`r`n  'en-us': 'en',"

if ($content.Contains($oldAlias)) {
    $content = $content.Replace($oldAlias, $newAlias)
} else {
    $oldAliasUnix = "  en: 'en',`n  'en-us': 'en',"
    if ($content.Contains($oldAliasUnix)) {
        $newAliasUnix = "  ru: 'ru',`n  'ru-ru': 'ru',`n  ru_ru: 'ru',`n  'russkiy': 'ru',`n  en: 'en',`n  'en-us': 'en',"
        $content = $content.Replace($oldAliasUnix, $newAliasUnix)
    } else {
        Write-Error "Could not find 'en' alias"
        exit 2
    }
}

$content | Set-Content $FilePath -NoNewline -Encoding UTF8
Write-Host "languages.ts patched (ru first)."
exit 0