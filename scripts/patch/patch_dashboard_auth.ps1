# scripts\patch\patch_dashboard_auth.ps1
# Добавляет dashboard.basic_auth (username + password_hash) в config.yaml.
# Зачем: dashboard ОТКАЗЫВАЕТСЯ слушать 0.0.0.0 (удалённый доступ) без настроенного
# auth-провайдера (June 2026 hardening; --insecure больше не работает).
# Логика: секция dashboard: — обновляем/добавляем basic_auth; нет секции — добавляем.
# ВАЖНО: при повторном запуске СТАРЫЕ username/password_hash пропускаются
# (иначе дубликаты ключей в YAML — мусор в config.yaml).

param(
    [Parameter(Mandatory=$true)]
    [string]$ConfigPath,
    [Parameter(Mandatory=$true)]
    [string]$Username,
    [Parameter(Mandatory=$true)]
    [string]$PasswordHash
)

if (-not (Test-Path $ConfigPath)) {
    Write-Host "  !   config.yaml not found: $ConfigPath" -ForegroundColor Yellow
    exit 1
}

$Username = $Username.Trim().Trim('"').Trim("'")
$PasswordHash = $PasswordHash.Trim()
if ([string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($PasswordHash)) {
    Write-Host "  !   empty username or password_hash" -ForegroundColor Yellow
    exit 1
}

$lines = Get-Content $ConfigPath -Encoding UTF8
$result = @()
$modified = $false
$inDashboardBlock = $false
$dashBaseIndent = -1
$basicAuthDone = $false
$basicAuthFound = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.TrimStart()
    $indent = $line.Length - $trimmed.Length

    # === Определяем блок dashboard: (верхний уровень) ===
    if (-not $inDashboardBlock -and $trimmed -match '^dashboard:\s*$') {
        $inDashboardBlock = $true
        $dashBaseIndent = $indent
        $result += $line
        continue
    }

    # === Внутри блока dashboard: ===
    if ($inDashboardBlock) {
        # Выход из блока (пустая строка или секция верхнего уровня)
        if ($indent -le $dashBaseIndent -and $trimmed -ne '' -and -not $trimmed.StartsWith('#')) {
            $inDashboardBlock = $false
            # basic_auth не найден — вставляем ПЕРЕД выходом
            if (-not $basicAuthFound) {
                $result += (' ' * ($dashBaseIndent + 2)) + "basic_auth:"
                $result += (' ' * ($dashBaseIndent + 4)) + "username: '$Username'"
                $result += (' ' * ($dashBaseIndent + 4)) + "password_hash: '$PasswordHash'"
                $basicAuthDone = $true
                $basicAuthFound = $true
                $modified = $true
            }
            $result += $line
            continue
        }
        # Строка basic_auth: — обновляем username/password_hash под ней
        if (-not $basicAuthDone -and $trimmed -match '^basic_auth:\s*$') {
            $result += (' ' * $indent) + "basic_auth:"
            $result += (' ' * ($indent + 2)) + "username: '$Username'"
            $result += (' ' * ($indent + 2)) + "password_hash: '$PasswordHash'"
            $basicAuthDone = $true
            $basicAuthFound = $true
            $modified = $true
            # Пропускаем СТАРЫЕ username/password_hash (защита от дубликатов)
            while ($i + 1 -lt $lines.Count) {
                $nxtLine = $lines[$i + 1]
                $nxtTrim = $nxtLine.TrimStart()
                $nxtIndent = $nxtLine.Length - $nxtTrim.Length
                if ($nxtTrim -match '^(username|password_hash):' -and $nxtIndent -gt $indent) {
                    $i++
                } else {
                    break
                }
            }
            continue
        }
        $result += $line
        continue
    }

    $result += $line
}

# === Файл закончился внутри dashboard-блока ===
if ($inDashboardBlock -and -not $basicAuthFound) {
    $result += (' ' * ($dashBaseIndent + 2)) + "basic_auth:"
    $result += (' ' * ($dashBaseIndent + 4)) + "username: '$Username'"
    $result += (' ' * ($dashBaseIndent + 4)) + "password_hash: '$PasswordHash'"
    $basicAuthDone = $true
    $basicAuthFound = $true
    $modified = $true
}

# === Секции dashboard: нет вообще — добавляем в конец ===
if (-not $inDashboardBlock -and -not $basicAuthFound) {
    $result += ''
    $result += 'dashboard:'
    $result += '  basic_auth:'
    $result += "    username: '$Username'"
    $result += "    password_hash: '$PasswordHash'"
    $modified = $true
}

if ($modified) {
    $result | Set-Content $ConfigPath -Encoding UTF8
    Write-Host "    +   dashboard.basic_auth set for user '$Username' in config.yaml" -ForegroundColor Green
    exit 0
} elseif ($basicAuthDone) {
    Write-Host "    .   dashboard.basic_auth already configured in config.yaml" -ForegroundColor Green
    exit 0
} else {
    Write-Host "    !   failed to process config.yaml" -ForegroundColor Yellow
    exit 1
}
