# scripts\ps1\fix-user_env.ps1
# Синхронизация переменных окружения пользователя (HKCU\Environment) с корнем запуска.
# Start.bat вызывает этот скрипт при каждом запуске: реестр всегда указывает
# на тот корень Hermes, из которого запущен Start.bat.
# install.ps1 (официальный установщик) пишет в реестр:
#   HERMES_HOME, HERMES_GIT_BASH_PATH, Path (+ venv\Scripts, git\cmd|bin|usr\bin, node)
# Этот скрипт приводит их к актуальному корню.
# Параметры:
#   -RootDir <путь>  — корень запущенного вендора (например, D:\Hermes)
#   -WhatIf          — сухой прогон: показать изменения без записи
param(
    [Parameter(Mandatory = $true)][string]$RootDir,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

# Нормализация корня: убираем завершающий слэш
$RootDir = $RootDir.TrimEnd('\')

$expectedHome = "$RootDir\data\hermes"
$changed = $false

Write-Host "  [ENV] Syncing user environment with root: $RootDir"

# ---------------------------------------------------------------------------
# 1. HERMES_HOME
# ---------------------------------------------------------------------------
$curHome = [Environment]::GetEnvironmentVariable('HERMES_HOME', 'User')
if ($curHome -ne $expectedHome) {
    $oldHome = if ($curHome) { $curHome } else { '(not set)' }
    Write-Host "  [ENV]   HERMES_HOME: $oldHome  ->  $expectedHome" -ForegroundColor Yellow
    if (-not $WhatIf) {
        [Environment]::SetEnvironmentVariable('HERMES_HOME', $expectedHome, 'User')
    }
    $changed = $true
}

# ---------------------------------------------------------------------------
# 2. HERMES_GIT_BASH_PATH (чиним только если указывает внутрь portable-корня)
# ---------------------------------------------------------------------------
$curGit = [Environment]::GetEnvironmentVariable('HERMES_GIT_BASH_PATH', 'User')
if ($curGit -and $curGit -match '\\data\\') {
    $idx = $curGit.IndexOf('\data\')
    $newGit = $RootDir + $curGit.Substring($idx)
    if ($newGit -ne $curGit) {
        Write-Host "  [ENV]   HERMES_GIT_BASH_PATH: $curGit  ->  $newGit" -ForegroundColor Yellow
        if (-not $WhatIf) {
            [Environment]::SetEnvironmentVariable('HERMES_GIT_BASH_PATH', $newGit, 'User')
        }
        $changed = $true
    }
}

# ---------------------------------------------------------------------------
# 3. Path: элементы с \data\hermes\ или \data\home\ приводим к новому корню
# ---------------------------------------------------------------------------
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath) {
    $items = $userPath -split ';' | Where-Object { $_ -ne '' }
    $newItems = @()
    $pathChanged = $false
    foreach ($item in $items) {
        if ($item -match '\\data\\(hermes|home)\\.*') {
            $idx = $item.IndexOf('\data\')
            $fixed = $RootDir + $item.Substring($idx)
            if ($fixed -ne $item) {
                Write-Host "  [ENV]   PATH: $item" -ForegroundColor Yellow
                Write-Host "             -> $fixed" -ForegroundColor Yellow
                $pathChanged = $true
            }
            if ($newItems -notcontains $fixed) { $newItems += $fixed }
        } else {
            if ($newItems -notcontains $item) { $newItems += $item }
        }
    }
    if ($pathChanged) {
        if (-not $WhatIf) {
            [Environment]::SetEnvironmentVariable('Path', ($newItems -join ';'), 'User')
        }
        $changed = $true
    }
}

if ($changed) {
    Write-Host "  [ENV] Registry updated." -ForegroundColor Green
} else {
    Write-Host "  [ENV] No changes needed - registry is in order." -ForegroundColor DarkGray
}
exit 0
