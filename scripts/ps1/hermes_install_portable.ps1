# \scripts\ps1\hermes_install_portable.ps1
# Hermes Portable — обёртка над РОДНЫМ install.ps1
# ============================================================================
# v3.0  Что добавлено против v2.0:
#   - явная передача -Channel (по умолчанию stable) и -Branch: поведение больше
#     не зависит от дефолтов апстрима и случайных env-переменных;
#   - автофикс git "dubious ownership" (safe.directory) ДО запуска установщика:
#     иначе git молча отказывает, релиз не применяется, а установка "проходит";
#   - предупреждение, когда install.ps1 взят из кэша (может быть устаревшим);
#   - ПОСТ-ПРОВЕРКА: версия из install-stamp.json + сверка с последним релизом
#     GitHub для канала stable; при расхождении - громкое предупреждение и
#     подсказка про -Channel main.
# ============================================================================
param(
    [string]$HermesHome = "D:\Hermes\data\hermes",
    [string]$InstallDir = "D:\Hermes\data\hermes\hermes-agent",
    [switch]$IncludeDesktop = $false,
    # Пустая строка = определить автоматически, тем же способом, что апстрим
    [string]$Channel = $(if ($env:HERMES_INSTALL_CHANNEL) { $env:HERMES_INSTALL_CHANNEL } else { "" }),
    [string]$Branch = $(if ($env:HERMES_INSTALL_BRANCH) { $env:HERMES_INSTALL_BRANCH } else { "" })
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Устанавливаем переменные окружения для портативного режима
$env:HERMES_HOME = $HermesHome
$env:UV_INSTALL_DIR = "$HermesHome\bin"
$env:HERMES_INSTALL_CHANNEL = $Channel
# Управляемые uv Python-интерпретаторы — в ИЗОЛИРОВАННЫЙ каталог data\appdata\uv\python
$env:UV_PYTHON_INSTALL_DIR = "$(Split-Path $HermesHome -Parent)\appdata\uv\python"

# Обновляем PATH для текущего процесса
$env:Path = "$HermesHome\node;$HermesHome\bin;C:\Program Files\Git\cmd;" + $env:Path
[Environment]::SetEnvironmentVariable("Path", $env:Path, "Process")

# ---------------------------------------------------------------------------
#   git: снять "dubious ownership" для репозитория Hermes
#   Иначе ЛЮБАЯ git-команда падает с "detected dubious ownership", установщик
#   не может применить релиз и тихо "оставляет checkout как есть".
# ---------------------------------------------------------------------------
if (Test-Path (Join-Path $InstallDir ".git")) {
    try {
        $gitCheck = & git -C $InstallDir rev-parse --git-dir 2>&1
        if ($LASTEXITCODE -ne 0 -and ("$gitCheck" -match "dubious ownership|safe\.directory")) {
            Write-Host "  git: снимаю dubious ownership для $InstallDir" -ForegroundColor Yellow
            & git config --global --add safe.directory ($InstallDir -replace '\\', '/') 2>&1 | Out-Null
            & git config --global --add safe.directory $InstallDir 2>&1 | Out-Null
            $gitCheck = & git -C $InstallDir rev-parse --git-dir 2>&1
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  [!] git не работает в $InstallDir : $gitCheck" -ForegroundColor Red
            Write-Host "      Установщик не сможет применить релиз. Проверь владельца каталога." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [!] не удалось проверить git: $_" -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
#   Получение install.ps1: локальный репозиторий > кэш > сайт > GitHub raw
# ---------------------------------------------------------------------------
$localInstallScript = Join-Path $InstallDir "scripts\install.ps1"
$cacheFile = Join-Path $HermesHome "install.ps1.cache"
$installScript = $null
$installScriptSource = ""

if (Test-Path $localInstallScript) {
    Write-Host "  Local install.ps1 found: $localInstallScript" -ForegroundColor Green
    $installScript = Get-Content $localInstallScript -Raw
    $installScriptSource = "repo"
}
elseif (Test-Path $cacheFile) {
    Write-Host "  Using cached install.ps1: $cacheFile" -ForegroundColor Yellow
    Write-Host "  [!] ВНИМАНИЕ: кэш может быть от старой версии Hermes." -ForegroundColor Yellow
    Write-Host "      Если версия не растёт - удали $cacheFile и запусти снова." -ForegroundColor Yellow
    $installScript = Get-Content $cacheFile -Raw
    $installScriptSource = "cache"
}
else {
    $browserUA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
    $sources = @(
        @{ Name = "hermes-agent.nousresearch.com"; Uri = "https://hermes-agent.nousresearch.com/install.ps1";                            UseUA = $true  },
        @{ Name = "GitHub raw (main branch)";     Uri = "https://raw.githubusercontent.com/nousresearch/hermes-agent/main/scripts/install.ps1";   UseUA = $false },
        @{ Name = "GitHub raw (master branch)";   Uri = "https://raw.githubusercontent.com/nousresearch/hermes-agent/master/scripts/install.ps1"; UseUA = $false }
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
            try {
                $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
                [System.IO.File]::WriteAllText($cacheFile, $installScript, $utf8NoBom)
                Write-Host "  install.ps1 cached to $cacheFile" -ForegroundColor DarkGray
            } catch { }
            Write-Host "  install.ps1 downloaded successfully." -ForegroundColor Green
            $installScriptSource = "network"
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
        Write-Host "================================================================" -ForegroundColor Red
        throw "Could not obtain install.ps1 (local repo, cache, site and GitHub all failed)."
    }
}

Write-Host "Running install.ps1 with portable paths..." -ForegroundColor Cyan
Write-Host "  HERMES_HOME:    $HermesHome" -ForegroundColor Gray
Write-Host "  InstallDir:     $InstallDir" -ForegroundColor Gray
Write-Host "  Channel:        $Channel" -ForegroundColor Gray
Write-Host "  Branch:         $Branch" -ForegroundColor Gray
Write-Host "  IncludeDesktop: $IncludeDesktop" -ForegroundColor Gray
Write-Host "  install.ps1 из: $installScriptSource" -ForegroundColor Gray

# ---------------------------------------------------------------------------
#   Локальный uv.exe в репозитории — копируем на место ДО install.ps1
# ---------------------------------------------------------------------------
$localUvExe = Join-Path $InstallDir "scripts\bin\uv.exe"
if (Test-Path $localUvExe) {
    $targetDir = "$HermesHome\bin"
    if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Force -Path $targetDir | Out-Null }
    Copy-Item $localUvExe "$targetDir\uv.exe" -Force
    Write-Host "  uv.exe скопирован из репозитория ($([math]::Round((Get-Item $localUvExe).Length / 1MB, 1)) МБ)" -ForegroundColor Green
}

# Кэш install.ps1 нужен только как аварийный источник. Если скрипт пришёл из
# репозитория или из сети - кэш устарел, удаляем, чтобы он не подсунулся потом.
if (($installScriptSource -eq "repo" -or $installScriptSource -eq "network") -and (Test-Path $cacheFile)) {
    try {
        Remove-Item $cacheFile -Force
        Write-Host "  устаревший кэш install.ps1 удалён" -ForegroundColor DarkGray
    } catch { }
}

# ---------------------------------------------------------------------------
#   Канал и ветка: НЕ хардкодим, а определяем тем же способом, что апстрим
#   (hermes_cli.update_channel.default_channel читает config.yaml и install-stamp).
#   Принудительный stable на canary-установке был бы откатом назад.
# ---------------------------------------------------------------------------
$channelSource = "задан параметром/env"
if (-not $Channel) {
    $venvPython = Join-Path $InstallDir "venv\Scripts\python.exe"
    if (Test-Path $venvPython) {
        try {
            $detected = & $venvPython -c "import sys; sys.path.insert(0, r'$InstallDir'); from hermes_cli.update_channel import default_channel; print(default_channel())" 2>$null
            if ($detected -and "$detected".Trim() -match '^(stable|main|canary)$') {
                $Channel = "$detected".Trim()
                $channelSource = "определён апстримом"
            }
        } catch { }
    }
    if (-not $Channel) {
        $channelSource = "НЕ определён - оставляем выбор установщику"
        $env:HERMES_INSTALL_CHANNEL = ""
    }
}
if ($Channel) { $env:HERMES_INSTALL_CHANNEL = $Channel }

$branchSource = "задана параметром/env"
if (-not $Branch) {
    $stampForBranch = Join-Path $InstallDir "install-stamp.json"
    if (Test-Path $stampForBranch) {
        try {
            $sb = (Get-Content $stampForBranch -Raw | ConvertFrom-Json).branch
            if ($sb) { $Branch = "$sb"; $branchSource = "из install-stamp.json" }
        } catch { }
    }
    if (-not $Branch) {
        try {
            $b = & git -C $InstallDir rev-parse --abbrev-ref HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and $b -and "$b".Trim() -ne "HEAD") {
                $Branch = "$b".Trim()
                $branchSource = "из git HEAD"
            }
        } catch { }
    }
    if (-not $Branch) { $branchSource = "НЕ определена - оставляем выбор установщику" }
}

Write-Host ""
Write-Host "  Канал:  $(if ($Channel) { $Channel } else { '<авто>' })  ($channelSource)" -ForegroundColor Cyan
Write-Host "  Ветка:  $(if ($Branch) { $Branch } else { '<авто>' })  ($branchSource)" -ForegroundColor Cyan

# ---------------------------------------------------------------------------
#   Запуск родного install.ps1
# ---------------------------------------------------------------------------
$scriptBlock = [ScriptBlock]::Create($installScript)

$exitCode = 0
$nativeArgs = @{
    HermesHome     = $HermesHome
    InstallDir     = $InstallDir
    NonInteractive = $true
}
# Передаём только то, что реально определено: пустые значения не навязываем
if ($Channel) { $nativeArgs['Channel'] = $Channel }
if ($Branch)  { $nativeArgs['Branch'] = $Branch }
try {
    if ($IncludeDesktop) {
        & $scriptBlock @nativeArgs -IncludeDesktop
    } else {
        & $scriptBlock @nativeArgs
    }
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

# ---------------------------------------------------------------------------
#   ПОСТ-ПРОВЕРКА: какая версия реально установлена
#   Версия в UI берётся из install-stamp.json (baseVersion), а не из кода.
# ---------------------------------------------------------------------------
$stampFile = Join-Path $InstallDir "install-stamp.json"
$installedBase = $null
$installedBuilt = $null
if (Test-Path $stampFile) {
    try {
        $stamp = Get-Content $stampFile -Raw | ConvertFrom-Json
        $installedBase = $stamp.baseVersion
        $installedBuilt = $stamp.builtAt
        Write-Host ""
        Write-Host "  Установленная версия: $($stamp.displayVersion) (base $installedBase)" -ForegroundColor Green
        Write-Host "  Stamp записан: $installedBuilt" -ForegroundColor DarkGray
    } catch {
        Write-Host "  [!] не прочитать install-stamp.json: $_" -ForegroundColor Yellow
    }
}

if ((-not $Channel) -or ($Channel -eq "stable")) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/NousResearch/hermes-agent/releases/latest' `
            -Headers @{ 'User-Agent' = 'hermes-portable'; 'Accept' = 'application/vnd.github+json' } -TimeoutSec 25
        $latestTag = "$($release.tag_name)".TrimStart('v')
        if ($latestTag) {
            if ($installedBase -and ($latestTag -ne "$installedBase")) {
                Write-Host ""
                Write-Host "================================================================" -ForegroundColor Yellow
                Write-Host "  [!] ВЕРСИЯ НЕ ОБНОВИЛАСЬ" -ForegroundColor Yellow
                Write-Host "      установлено: $installedBase" -ForegroundColor Yellow
                Write-Host "      последний релиз на GitHub: v$latestTag" -ForegroundColor Yellow
                Write-Host "  Причины: нет доступа к releases/tags (квота GitHub API, VPN, прокси)," -ForegroundColor Yellow
                Write-Host "           git не смог применить тег (владение каталогом), либо" -ForegroundColor Yellow
                Write-Host "           установщик оставил checkout как есть." -ForegroundColor Yellow
                Write-Host "  Обход: запустить с -Channel main (tip ветки main)." -ForegroundColor Yellow
                Write-Host "================================================================" -ForegroundColor Yellow
                if ($exitCode -eq 0) { $exitCode = 1 }
            } elseif ($installedBase) {
                Write-Host "  Версия совпадает с последним релизом: v$latestTag" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host "  [!] не удалось проверить последний релиз на GitHub (квота/сеть): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

if ($exitCode -ne 0) {
    Write-Host "  install.ps1 завершился с кодом: $exitCode" -ForegroundColor Yellow
}
exit $exitCode
