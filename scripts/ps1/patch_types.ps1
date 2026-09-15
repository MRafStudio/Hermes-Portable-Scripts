# \scripts\ps1\patch_types.ps1
# Hermes Portable - Патч для types.ts: добавляет 'ru' в union типа Locale.
# Идемпотентен: 'ru' уже есть -> exit 1 (ничего не меняем).
# Список языков НЕ фиксируется: 'ru' дописывается в конец union, какие бы языки
# ни добавил апстрим (например, 'ar').
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

$m = [regex]::Match($content, "export type Locale = ([^\r\n]+)")
if (-not $m.Success) {
    Write-Error "Could not find 'export type Locale' in types.ts"
    exit 2
}

$list = $m.Groups[1].Value.TrimEnd()
if ($list -notmatch "^('.*?'\s*\|\s*)+'[^']*'$") {
    Write-Error "Unexpected Locale union format: $list"
    exit 2
}

$newList = $list + " | 'ru'"
$content = $content.Remove($m.Groups[1].Index, $m.Groups[1].Length).Insert($m.Groups[1].Index, $newList)

[System.IO.File]::WriteAllText($FilePath, $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "types.ts patched (ru appended to Locale)."
exit 0
