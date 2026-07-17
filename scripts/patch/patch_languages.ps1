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

# 1. Add ru to LOCALE_OPTIONS
$oldJaBlock = "    configValue: 'ja'`r`n  }"
$newJaBlock = "    configValue: 'ja'`r`n  },`r`n  {`r`n    id: 'ru',`r`n    name: 'Russian',`r`n    englishName: 'Russian',`r`n    configValue: 'ru'`r`n  }"

if ($content.Contains($oldJaBlock)) {
    $content = $content.Replace($oldJaBlock, $newJaBlock)
} else {
    $oldJaBlockUnix = "    configValue: 'ja'`n  }"
    if ($content.Contains($oldJaBlockUnix)) {
        $newJaBlockUnix = "    configValue: 'ja'`n  },`n  {`n    id: 'ru',`n    name: 'Russian',`n    englishName: 'Russian',`n    configValue: 'ru'`n  }"
        $content = $content.Replace($oldJaBlockUnix, $newJaBlockUnix)
    } else {
        Write-Error "Could not find ja locale block"
        exit 2
    }
}

# 2. Add ru aliases to LOCALE_ALIASES
$oldAlias = "  ja_jp: 'ja'`r`n}"
$newAlias = "  ja_jp: 'ja',`r`n  ru: 'ru',`r`n  'ru-ru': 'ru',`r`n  ru_ru: 'ru',`r`n  'russkiy': 'ru'`r`n}"

if ($content.Contains($oldAlias)) {
    $content = $content.Replace($oldAlias, $newAlias)
} else {
    $oldAliasUnix = "  ja_jp: 'ja'`n}"
    if ($content.Contains($oldAliasUnix)) {
        $newAliasUnix = "  ja_jp: 'ja',`n  ru: 'ru',`n  'ru-ru': 'ru',`n  ru_ru: 'ru',`n  'russkiy': 'ru'`n}"
        $content = $content.Replace($oldAliasUnix, $newAliasUnix)
    } else {
        Write-Error "Could not find ja_jp alias"
        exit 2
    }
}

$content | Set-Content $FilePath -NoNewline -Encoding UTF8
Write-Host "languages.ts patched."
exit 0