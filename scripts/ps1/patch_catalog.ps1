# \scripts\ps1\patch_catalog.ps1
# Hermes Portable - Патч для catalog.ts: подключает русские переводы.
# Идемпотентен: "import { ru }" уже есть -> exit 1 (ничего не меняем).
# Стиль апстрима: импорт встаёт в алфавитном порядке (перед "import type"),
# элемент TRANSLATIONS - последним.
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

$nl = "`n"
if ($content.Contains("`r`n")) { $nl = "`r`n" }

function Insert-ListItem {
    param([string]$Text, [int]$Idx, [string]$Block)
    $i = $Idx - 1
    while ($i -ge 0 -and ($Text[$i] -eq " " -or $Text[$i] -eq "`t" -or $Text[$i] -eq "`r" -or $Text[$i] -eq "`n")) { $i-- }
    if ($i -lt 0) { return $null }
    if ($Text[$i] -eq ",") {
        $pos = $i + 1
        return $Text.Substring(0, $pos) + $Block + $Text.Substring($pos)
    }
    return $Text.Substring(0, $i + 1) + "," + $Block + $Text.Substring($i + 1)
}

# --- 1) импорт: перед "import type" (алфавитный порядок сохраняется) ---
$anchor = "import type {"
$idx = $content.IndexOf($anchor)
if ($idx -lt 0) {
    Write-Error "Could not find 'import type' anchor in catalog.ts"
    exit 2
}
$content = $content.Insert($idx, "import { ru } from './ru'" + $nl)

# --- 2) элемент TRANSLATIONS: последним ---
$lastBrace = $content.LastIndexOf("}")
if ($lastBrace -lt 0 -or $content.Substring($lastBrace + 1).Trim().Length -ne 0) {
    Write-Error "Could not find the closing brace of TRANSLATIONS"
    exit 2
}
$content = Insert-ListItem -Text $content -Idx $lastBrace -Block ($nl + "  ru")
if ($null -eq $content) {
    Write-Error "Could not locate the last TRANSLATIONS entry"
    exit 2
}

[System.IO.File]::WriteAllText($FilePath, $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "catalog.ts patched (ru wired into TRANSLATIONS)."
exit 0
