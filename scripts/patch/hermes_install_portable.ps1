# \scripts\patch\hermes_install_portable.ps1
# Hermes Portable — Wrapper для install.ps1
# ============================================================================
# v2.0 — Сначала проверяет локальный install.ps1 в репозитории,
#         если есть — использует его. Если нет — качает с сайта.
# ============================================================================
param(
    [string]$HermesHome = "D:\Hermes\data\hermes",
    [string]$InstallDir = "D:\Hermes\data\hermes\hermes-agent",
    [switch]$IncludeDesktop = $false
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Устанавливаем переменные окружения для портативного режима
$env:HERMES_HOME = $HermesHome
$env:UV_INSTALL_DIR = "$HermesHome\bin"

# Обновляем PATH для текущего процесса
$env:Path = "$HermesHome\node;$HermesHome\bin;C:\Program Files\Git\cmd;" + $env:Path

# КРИТИЧНО: Явно экспортируем PATH для дочерних процессов
[Environment]::SetEnvironmentVariable("Path", $env:Path, "Process")

# ---------------------------------------------------------------------------
#   Приоритет: локальный install.ps1 в репозитории > скачивание с сайта
# ---------------------------------------------------------------------------
$localInstallScript = Join-Path $InstallDir "scripts\install.ps1"
$installScript = $null

if (Test-Path $localInstallScript) {
    Write-Host "Найден локальный install.ps1: $localInstallScript" -ForegroundColor Green
    $installScript = Get-Content $localInstallScript -Raw
}
else {
    Write-Host "Локальный install.ps1 не найден. Скачиваем с hermes-agent.nousresearch.com..." -ForegroundColor Cyan
    try {
        [Net.ServicePointManager]::SecurityProtocol = 'Tls12'; $installScript = Invoke-RestMethod -Uri "https://hermes-agent.nousresearch.com/install.ps1" -UseBasicParsing
        Write-Host "install.ps1 успешно скачан." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
        Write-Host "║  [ОШИБКА] Не удалось скачать install.ps1 с сайта!          ║" -ForegroundColor Red
        Write-Host "║                                                             ║" -ForegroundColor Red
        Write-Host "║  Возможные причины:                                        ║" -ForegroundColor Yellow
        Write-Host "║  • Блокировка РКН / файрвол                                ║" -ForegroundColor Yellow
        Write-Host "║  • TLS/SSL — сервер не поддерживает старый протокол        ║" -ForegroundColor Yellow
        Write-Host "║  • Репозиторий ещё не клонирован                            ║" -ForegroundColor Yellow
        Write-Host "║                                                             ║" -ForegroundColor Red
        Write-Host "║  Решение: клонируйте репозиторий через меню, затем         ║" -ForegroundColor Green
        Write-Host "║  повторите установку. install.ps1 будет взят локально.      ║" -ForegroundColor Green
        Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
        Write-Host ""
        throw "Не удалось получить install.ps1 (ни локально, ни с сайта). $_"
    }
}

Write-Host "Running install.ps1 with portable paths..." -ForegroundColor Cyan
Write-Host "  HERMES_HOME: $HermesHome" -ForegroundColor Gray
Write-Host "  InstallDir:  $InstallDir" -ForegroundColor Gray
Write-Host "  IncludeDesktop: $IncludeDesktop" -ForegroundColor Gray

# ---------------------------------------------------------------------------
#   Локальный uv.exe в репозитории — копируем на место ДО install.ps1
#   Это решает проблему: install.ps1 не может скачать uv из-за сети/РКН
# ---------------------------------------------------------------------------
$localUvExe = Join-Path $InstallDir "scripts\bin\uv.exe"
if (Test-Path $localUvExe) {
    $targetDir = "$HermesHome\bin"
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }
    Copy-Item $localUvExe "$targetDir\uv.exe" -Force
    Write-Host "  uv.exe скопирован из репозитория ($( (Get-Item $localUvExe).Length / 1MB ) МБ)" -ForegroundColor Green
}

# Выполняем скрипт с параметрами и пробрасываем exit code
$scriptBlock = [ScriptBlock]::Create($installScript)

$exitCode = 0
try {
    if ($IncludeDesktop) {
        & $scriptBlock -HermesHome $HermesHome -InstallDir $InstallDir -IncludeDesktop -NonInteractive
    } else {
        & $scriptBlock -HermesHome $HermesHome -InstallDir $InstallDir -NonInteractive
    }
    # Проверяем, что install.ps1 реально выполнил работу (uv должен быть)
    if (-not (Test-Path "$HermesHome\bin\uv.exe")) {
        Write-Host "  uv.exe не найден после install.ps1 — считаем ошибкой." -ForegroundColor Yellow
        $exitCode = 1
    } else {
        $exitCode = $LASTEXITCODE
    }
} catch {
    Write-Host "  [ОШИБКА] install.ps1 выбросил исключение: $_" -ForegroundColor Red
    $exitCode = 1
}

if ($exitCode -ne 0) {
    Write-Host "  install.ps1 завершился с кодом: $exitCode" -ForegroundColor Yellow
}
exit $exitCode
