# \scripts\ps1\patch_languages.ps1
# Hermes Portable - Патч для languages.ts: регистрирует русский язык.
# Идемпотентен: "id: 'ru'" уже есть -> exit 1 (ничего не меняем).
# Стиль апстрима: запись идёт ПОСЛЕДНЕЙ в LOCALE_OPTIONS, имя берётся из
# LOCALE_ENDONYMS (ключ 'ru' гарантирован патчем patch_types.ps1).
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

$nl = "`n"
if ($content.Contains("`r`n")) { $nl = "`r`n" }

function Insert-ListItem {
    param([string]$Text, [int]$Idx, [string]$Block)
    # отступаем от закрывающей скобки к концу последнего элемента списка
    $i = $Idx - 1
    while ($i -ge 0 -and ($Text[$i] -eq " " -or $Text[$i] -eq "`t" -or $Text[$i] -eq "`r" -or $Text[$i] -eq "`n")) { $i-- }
    if ($i -lt 0) { return $null }
    if ($Text[$i] -eq ",") {
        $pos = $i + 1
        return $Text.Substring(0, $pos) + $Block + $Text.Substring($pos)
    }
    return $Text.Substring(0, $i + 1) + "," + $Block + $Text.Substring($i + 1)
}

# --- 1) LOCALE_OPTIONS: запись идёт последней ---
$idx = $content.IndexOf("] as const")
if ($idx -lt 0) {
    Write-Error "Could not find LOCALE_OPTIONS end ('] as const')"
    exit 2
}
$entry = $nl + "  {" + $nl + "    id: 'ru'," + $nl + "    name: LOCALE_ENDONYMS.ru," +
         $nl + "    englishName: 'Russian'," + $nl + "    configValue: 'ru'" + $nl + "  }"
$content = Insert-ListItem -Text $content -Idx $idx -Block $entry
if ($null -eq $content) {
    Write-Error "Could not locate the last LOCALE_OPTIONS entry"
    exit 2
}

# --- 2) LOCALE_ALIASES: набор алиасов идёт последним ---
$anchor2 = "const LOCALE_ALIASES"
$i2 = $content.IndexOf($anchor2)
if ($i2 -lt 0) {
    Write-Error "Could not find LOCALE_ALIASES in languages.ts"
    exit 2
}
$open2 = $content.IndexOf("{", $i2)
$close2 = $content.IndexOf("}", $open2)
if ($open2 -lt 0 -or $close2 -lt 0) {
    Write-Error "Could not find the LOCALE_ALIASES body"
    exit 2
}
$aliasBlock = $nl + "  ru: 'ru'," + $nl + "  'ru-ru': 'ru'," + $nl + "  ru_ru: 'ru'," + $nl +
              "  'ru-by': 'ru'," + $nl + "  'ru-kz': 'ru'," + $nl + "  russian: 'ru'," + $nl +
              "  'russian-russian': 'ru'," + $nl + "  русский: 'ru'," + $nl + "  руский: 'ru'"
$content = Insert-ListItem -Text $content -Idx $close2 -Block $aliasBlock
if ($null -eq $content) {
    Write-Error "Could not locate the last LOCALE_ALIASES entry"
    exit 2
}

[System.IO.File]::WriteAllText($FilePath, $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "languages.ts patched (ru registered)."
exit 0
