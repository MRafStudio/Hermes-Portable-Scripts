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
# Управляемые uv Python-интерпретаторы — в ИЗОЛИРОВАННЫЙ каталог data\appdata\uv\python
# (uv на Windows берёт AppData через WinAPI и игнорирует переменную APPDATA —
#  без этой переменной питон уезжает в реальный профиль пользователя,
#  а наши скрипты ищут его в изолированном каталоге)
$env:UV_PYTHON_INSTALL_DIR = "$(Split-Path $HermesHome -Parent)\appdata\uv\python"

# Обновляем PATH для текущего процесса
$env:Path = "$HermesHome\node;$HermesHome\bin;C:\Program Files\Git\cmd;" + $env:Path

# КРИТИЧНО: Явно экспортируем PATH для дочерних процессов
[Environment]::SetEnvironmentVariable("Path", $env:Path, "Process")

# ---------------------------------------------------------------------------
#   Получение install.ps1: локальный репозиторий > кэш > сайт > GitHub raw
#   Сайт может блокировать (Cloudflare/РКН) — GitHub raw как fallback.
# ---------------------------------------------------------------------------
$localInstallScript = Join-Path $InstallDir "scripts\install.ps1"
$cacheFile = Join-Path $HermesHome "install.ps1.cache"
$installScript = $null

# Источник 1: локальный install.ps1 в уже клонированном репозитории
if (Test-Path $localInstallScript) {
    Write-Host "  Local install.ps1 found: $localInstallScript" -ForegroundColor Green
    $installScript = Get-Content $localInstallScript -Raw
}
# Источник 2: кэш от предыдущего успешного скачивания
elseif (Test-Path $cacheFile) {
    Write-Host "  Using cached install.ps1: $cacheFile" -ForegroundColor Green
    $installScript = Get-Content $cacheFile -Raw
}
# Источники 3-5: сайт и GitHub raw (main, затем master)
else {
    $browserUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
    $sources = @(
        @{ Name = "hermes-agent.nousresearch.com";       Uri = "https://hermes-agent.nousresearch.com/install.ps1";                                                     UseUA = $true  },
        @{ Name = "GitHub raw (main branch)";            Uri = "https://raw.githubusercontent.com/nousresearch/hermes-agent/main/scripts/install.ps1";                  UseUA = $false },
        @{ Name = "GitHub raw (master branch)";          Uri = "https://raw.githubusercontent.com/nousresearch/hermes-agent/master/scripts/install.ps1";                 UseUA = $false }
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    foreach ($src in $sources) {
        try {
            Write-Host "  Downloading install.ps1 from $($src.Name)..." -ForegroundColor Cyan
            if ($src.UseUA) {
                $installScript = Invoke-RestMethod -Uri $src.Uri -UseBasicParsing -UserAgent $browserUA -TimeoutSec 60
            } else {
                $installScript = Invoke-RestMethod -Uri $src.Uri -UseBasicParsing -TimeoutSec 60
            }
            # Кэшируем на будущее (UTF-8 без BOM — безопасно для ScriptBlock::Create)
            try {
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($cacheFile, $installScript, $utf8NoBom)
                Write-Host "  install.ps1 cached to $cacheFile" -ForegroundColor DarkGray
            } catch { }
            Write-Host "  install.ps1 downloaded successfully." -ForegroundColor Green
            break
        }
        catch {
            Write-Host "  [!] Source failed: $($src.Name)" -ForegroundColor Yellow
        }
    }
    if (-not $installScript) {
        Write-Host ""
        Write-Host "================================================================" -ForegroundColor Red
        Write-Host "  [ERROR] Could not obtain install.ps1 from any source." -ForegroundColor Red
        Write-Host "  Tried: local repo, cache, hermes-agent.nousresearch.com," -ForegroundColor Yellow
        Write-Host "         raw.githubusercontent.com (main/master branches)." -ForegroundColor Yellow
        Write-Host "  Check internet connection / firewall / DNS blocking." -ForegroundColor Yellow
        Write-Host "  Workaround: copy scripts\install.ps1 from the working 'home'" -ForegroundColor Yellow
        Write-Host "  installation into the target repo, or clone hermes-agent first." -ForegroundColor Yellow
        Write-Host "================================================================" -ForegroundColor Red
        throw "Could not obtain install.ps1 (local repo, cache, site and GitHub all failed)."
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
