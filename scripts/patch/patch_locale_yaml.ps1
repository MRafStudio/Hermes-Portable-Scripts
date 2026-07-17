# scripts\patch\patch_locale_yaml.ps1
# Правка language: в блоке display: в config.yaml

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,
    [Parameter(Mandatory=$true)]
    [string]$Locale
)

if (-not (Test-Path $ConfigPath)) {
    Write-Host "  !   config.yaml not found: $ConfigPath" -ForegroundColor Yellow
    exit 1
}

$lines = Get-Content $ConfigPath -Encoding UTF8
$result = @()
$modified = $false
$inDisplayBlock = $false
$displayBaseIndent = -1
$languageDone = $false
$languageFound = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.TrimStart()
    $indent = $line.Length - $trimmed.Length
    
    # === Определяем блок display: ===
    if (-not $inDisplayBlock -and $trimmed -match '^display:\s*$') {
        $inDisplayBlock = $true
        $displayBaseIndent = $indent
        $result += $line
        continue
    }
    
    # === Внутри блока display: ===
    if ($inDisplayBlock) {
        # Проверяем, не вышли ли из блока (пустая строка или секция верхнего уровня)
        if ($indent -le $displayBaseIndent -and $trimmed -ne '' -and -not $trimmed.StartsWith('#')) {
            $inDisplayBlock = $false
            # language не найден в блоке — вставляем ПЕРЕД выходом
            if (-not $languageFound) {
                $result += (' ' * ($displayBaseIndent + 2)) + "language: $Locale"
                $languageDone = $true
                $languageFound = $true
                $modified = $true
            }
            $result += $line
            continue
        }
        
        # language: с кавычками или без → заменяем на переданное значение
        if (-not $languageDone -and $trimmed -match '^language:\s*"?[^"]*"?') {
            $line = (' ' * ($displayBaseIndent + 2)) + "language: $Locale"
            $languageDone = $true
            $languageFound = $true
            $modified = $true
        }
        # Уже наше значение
        elseif (-not $languageDone -and $trimmed -match '^language:\s*' + [regex]::Escape($Locale)) {
            $languageDone = $true
            $languageFound = $true
        }
        
        $result += $line
        continue
    }
    
    $result += $line
}

# === Если файл закончился, а мы всё ещё в блоке display: ===
# (например, display: — последний блок в файле)
if ($inDisplayBlock -and -not $languageFound) {
    $result += (' ' * ($displayBaseIndent + 2)) + "language: $Locale"
    $languageDone = $true
    $languageFound = $true
    $modified = $true
}

if ($modified) {
    $result | Set-Content $ConfigPath -Encoding UTF8
    Write-Host "    +   language: set to '$Locale' in config.yaml" -ForegroundColor Green
    exit 0
} elseif ($languageDone) {
    Write-Host "    .   language: already '$Locale' in config.yaml" -ForegroundColor Green
    exit 0
} else {
    Write-Host "    !   failed to process config.yaml" -ForegroundColor Yellow
    exit 1
}