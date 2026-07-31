# scripts\patch\patch_terminal_cwd.ps1
# Устанавливает terminal.cwd в config.yaml (рабочая директория сессий Hermes Desktop).
# Зачем: без явного cwd Electron берёт системный профиль через WinAPI (app.getPath('home')),
# игнорируя изолированный USERPROFILE — сессии падают в C:\Users\<user> (системный профиль).
# Вызывается при КАЖДОМ запуске Start.bat (самолечение, как Fix-UserEnv.ps1 для реестра).
# Логика замены (только эти случаи):
#   1) неявные значения: ".", "auto", "cwd", пусто
#   2) переносимый профиль ДРУГОГО корня: оканчивается на "\data\home"
# Явный пользовательский путь (проект) — НЕ трогаем.

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,
    [Parameter(Mandatory=$true)]
    [string]$Cwd
)

if (-not (Test-Path $ConfigPath)) {
    Write-Host "  !   config.yaml not found: $ConfigPath" -ForegroundColor Yellow
    exit 1
}

# Чистим путь от случайных кавычек
$Cwd = $Cwd.Trim().Trim('"').Trim("'")
if ([string]::IsNullOrWhiteSpace($Cwd)) {
    Write-Host "  !   empty cwd path" -ForegroundColor Yellow
    exit 1
}

$lines = Get-Content $ConfigPath -Encoding UTF8
$result = @()
$modified = $false
$inTerminalBlock = $false
$terminalBaseIndent = -1
$cwdDone = $false
$cwdFound = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.TrimStart()
    $indent = $line.Length - $trimmed.Length

    # === Определяем блок terminal: (верхний уровень) ===
    if (-not $inTerminalBlock -and $trimmed -match '^terminal:\s*$') {
        $inTerminalBlock = $true
        $terminalBaseIndent = $indent
        $result += $line
        continue
    }

    # === Внутри блока terminal: ===
    if ($inTerminalBlock) {
        # Выход из блока (пустая строка или секция верхнего уровня)
        if ($indent -le $terminalBaseIndent -and $trimmed -ne '' -and -not $trimmed.StartsWith('#')) {
            $inTerminalBlock = $false
            # cwd не найден в блоке — вставляем ПЕРЕД выходом
            if (-not $cwdFound) {
                $result += (' ' * ($terminalBaseIndent + 2)) + "cwd: '$Cwd'"
                $cwdDone = $true
                $cwdFound = $true
                $modified = $true
            }
            $result += $line
            continue
        }
        # Строка cwd: заменяем неявные значения ИЛИ переносимый профиль другого корня
        if (-not $cwdDone -and $trimmed -match '^cwd:\s*(.*)$') {
            $curVal = $Matches[1].Trim().Trim('"').Trim("'")
            $isImplicit = $curVal -in @('', '.', 'auto', 'cwd')
            $isOtherPortableHome = $curVal -match '[\\/]data[\\/]home$' -and $curVal -ne $Cwd
            if ($isImplicit -or $isOtherPortableHome) {
                $result += (' ' * $indent) + "cwd: '$Cwd'"
                $cwdDone = $true
                $cwdFound = $true
                $modified = $true
                continue
            }
            # Явный пользовательский путь (проект) — оставляем как есть
            $cwdDone = $true
            $cwdFound = $true
            $result += $line
            continue
        }
        # Уже наше значение
        elseif (-not $cwdDone -and $trimmed -match "^cwd:\s*'?" + [regex]::Escape($Cwd)) {
            $cwdDone = $true
            $cwdFound = $true
        }

        $result += $line
        continue
    }

    $result += $line
}

# === Если файл закончился, а мы всё ещё в блоке terminal: ===
if ($inTerminalBlock -and -not $cwdFound) {
    $result += (' ' * ($terminalBaseIndent + 2)) + "cwd: '$Cwd'"
    $cwdDone = $true
    $cwdFound = $true
    $modified = $true
}

# === Если секции terminal: нет вообще — добавляем в конец ===
if (-not $inTerminalBlock -and -not $cwdFound) {
    $result += ''
    $result += 'terminal:'
    $result += '  backend: local'
    $result += "  cwd: '$Cwd'"
    $result += '  timeout: 180'
    $modified = $true
}

if ($modified) {
    $result | Set-Content $ConfigPath -Encoding UTF8
    Write-Host "    +   terminal.cwd set to '$Cwd' in config.yaml" -ForegroundColor Green
    exit 0
} elseif ($cwdDone) {
    Write-Host "    .   terminal.cwd already '$Cwd' in config.yaml" -ForegroundColor Green
    exit 0
} else {
    Write-Host "    !   failed to process config.yaml" -ForegroundColor Yellow
    exit 1
}
