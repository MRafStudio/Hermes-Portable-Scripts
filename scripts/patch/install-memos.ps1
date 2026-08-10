# install-memos.ps1
# ============================================================================
# Установка/обновление MemOS (memos-local-plugin, @memtensor) в Hermes Portable.
# Универсален: работает для любого корня (дом C:\NEURO\Hermes и полигон D:\NEURO\Hermes).
# Источник: npm tarball (latest = стабильная 2.0.14; beta-тег не используется).
#
# Что делает:
#   1. npm pack @memtensor/memos-local-plugin@latest -> распаковка в %HERMES_HOME%\memos-plugin
#   2. npm install + сборка bridge и viewer (vite)
#   3. Junction: %HERMES_HOME%\plugins\memtensor -> ...\memos-plugin\adapters\hermes\memos_provider
#      (именно plugins\<name> БЕЗ memory\ — upstream discovery Hermes)
#   4. config.yaml плагина (только при НОВОЙ установке; при обновлении настройки сохраняются)
#   5. memory.provider: memtensor в config.yaml Hermes (hermes config set)
#
# При обновлении поверх работающего Hermes: файлы могут быть залочены службой —
# скрипт остановится с понятным сообщением (пользователь сам остановит службу).
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$RootDir
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# --- Пути (портируемая схема: HERMES_HOME = <root>\data\hermes) ---
$HermesHome  = Join-Path $RootDir "data\hermes"
$RuntimeHome = Join-Path $HermesHome "memos-plugin"
$PluginDir   = Join-Path $HermesHome "plugins\memtensor"
$AdapterDir  = Join-Path $RuntimeHome "adapters\hermes\memos_provider"
$HermesExe   = Join-Path $HermesHome "hermes-agent\venv\Scripts\hermes.exe"
$TempDir     = Join-Path $HermesHome "data\temp"   # резерв; обычно не нужен
if (-not (Test-Path $HermesHome)) { Write-Error "HERMES_HOME not found: $HermesHome"; exit 1 }

Write-Host "== MemOS (memos-local-plugin) installer =="
Write-Host "Root      : $RootDir"
Write-Host "Runtime   : $RuntimeHome"

# --- Проверка node/npm (PATH, затем системный AppData) ---
$npmCmd = (Get-Command npm.cmd -ErrorAction SilentlyContinue)
if (-not $npmCmd) {
    # .bat-окружение переопределяет APPDATA — берём СИСТЕМНЫЙ Roaming через .NET
    $sysAppData = [Environment]::GetFolderPath('ApplicationData')
    $candidate = Join-Path $sysAppData "npm\npm.cmd"
    if (Test-Path $candidate) { $npmCmd = Get-Item $candidate }
}
if (-not $npmCmd) { Write-Error "npm not found (PATH or %APPDATA%\npm). Install Node.js >= 20 first."; exit 1 }
$npmPath = $npmCmd.Path
Write-Host "npm       : $npmPath"

# --- Вызов npm: stderr от npm (notice/warn) НЕ должен ронять скрипт при $ErrorActionPreference=Stop ---
function Invoke-Npm {
    param([string[]]$NpmArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $npmPath @NpmArgs 2>&1 | Out-Host
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) { throw "npm failed (exit $($code)): $($NpmArgs -join ' ')" }
}

# --- Актуальная версия в npm (инфо) ---
$latest = (& $npmPath view @memtensor/memos-local-plugin version 2>$null | Select-Object -First 1)
if (-not $latest) { $latest = "latest" }
Write-Host "npm tag   : $latest"

# --- Режим: INSTALL или UPDATE ---
$isUpdate = Test-Path (Join-Path $RuntimeHome "package.json")
if ($isUpdate) {
    Write-Host "Mode      : UPDATE ($RuntimeHome exists)"
} else {
    Write-Host "Mode      : INSTALL"
}

# --- Удаление старого (только для UPDATE; junction снимаем заранее) ---
if ($isUpdate) {
    if (Test-Path $PluginDir) {
        Write-Host "Removing old junction $PluginDir ..."
        Remove-Item -LiteralPath $PluginDir -Force -Recurse -ErrorAction Stop
    }
    try {
        Remove-Item -LiteralPath $RuntimeHome -Force -Recurse -ErrorAction Stop
    } catch {
        Write-Host ""
        Write-Host "ERROR: cannot remove $RuntimeHome (files are locked)."
        Write-Host "       Stop the Hermes service / any running hermes process, then retry."
        exit 1
    }
}

# --- 1. npm pack -> распаковка в RuntimeHome ---
$packDir = Join-Path $env:TEMP "memos-pack"
if (Test-Path $packDir) { Remove-Item -LiteralPath $packDir -Force -Recurse -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Path $packDir -Force | Out-Null
Write-Host "Packing @memtensor/memos-local-plugin@$latest ..."
Push-Location $packDir
Invoke-Npm @("pack", "@memtensor/memos-local-plugin@$latest", "--pack-destination", $packDir)
$tgz = Get-ChildItem -Path $packDir -Filter "*.tgz" | Select-Object -First 1
if (-not $tgz) { Pop-Location; Write-Error "npm pack failed"; exit 1 }
Pop-Location

Write-Host "Extracting to $RuntimeHome ..."
# Системный bsdtar (Windows tar.exe) — GNU tar из git-bash не понимает C:\ пути
$tarExe = Join-Path $env:SystemRoot "System32\tar.exe"
if (-not (Test-Path $tarExe)) { Write-Error "Windows tar.exe not found: $tarExe"; exit 1 }
$extractDir = Join-Path $packDir "extract"
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
& $tarExe -xzf $tgz.FullName -C $extractDir
if ($LASTEXITCODE -ne 0) { Write-Error "tar extraction failed (exit $($LASTEXITCODE))"; exit 1 }
New-Item -ItemType Directory -Path $RuntimeHome -Force | Out-Null
Copy-Item -Path (Join-Path $extractDir "package\*") -Destination $RuntimeHome -Recurse -Force
Remove-Item -LiteralPath (Join-Path $extractDir "package\tests") -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $extractDir "package\website") -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $packDir -Force -Recurse -ErrorAction SilentlyContinue

# --- 2. npm install (+ build только если dist НЕ приложен к тарболу) ---
Write-Host "npm install (native modules, may take a while)..."
Push-Location $RuntimeHome
Invoke-Npm @("install", "--no-audit", "--no-fund")
$bridgeBundled = Test-Path (Join-Path $RuntimeHome "dist\bridge.mjs")
if (-not $bridgeBundled) {
    Write-Host "dist not bundled — building bridge + viewer ..."
    Invoke-Npm @("run", "build:package")
} else {
    Write-Host "dist already bundled in npm tarball — skipping build"
}
Pop-Location
if (-not (Test-Path (Join-Path $RuntimeHome "dist\bridge.mjs"))) {
    Write-Error "build failed: dist\bridge.mjs missing"; exit 1
}

# --- 3. Junction плагина ---
if (-not (Test-Path $PluginDir)) {
    New-Item -ItemType Junction -Path $PluginDir -Value $AdapterDir | Out-Null
    Write-Host "Junction created: $PluginDir"
} else {
    Write-Host "Junction already exists: $PluginDir"
}

# --- 4. config.yaml плагина (только при новой установке) ---
$pluginCfg = Join-Path $RuntimeHome "config.yaml"
if (-not (Test-Path $pluginCfg)) {
    Write-Host "Writing plugin config.yaml (local embedder, kobold :5001, lightweight, telemetry OFF)..."
    @"
version: 1
viewer:
  port: 18800
embedding:
  provider: local
  apiKey: ""
llm:
  provider: openai_compatible
  endpoint: http://127.0.0.1:5001/v1
  apiKey: ""
  model: ""
storage:
  ftsTokenizer: trigram
algorithm:
  lightweightMemory:
    enabled: true
hub:
  enabled: false
  address: ""
  teamToken: ""
telemetry:
  enabled: false
logging:
  level: info
  detailedView: false
"@ | Set-Content -Path $pluginCfg -Encoding UTF8
} else {
    Write-Host "Plugin config.yaml exists - keeping user settings."
}

# --- 5. Активация провайдера в Hermes ---
if (Test-Path $HermesExe) {
    $check = & $HermesExe config get memory.provider 2>$null
    if ($check -match "memtensor") {
        Write-Host "memory.provider already = memtensor."
    } else {
        Write-Host "Activating memory.provider: memtensor ..."
        & $HermesExe config set memory.provider memtensor | Out-Null
    }
} else {
    Write-Host "WARNING: hermes.exe not found - activate memory.provider manually."
}

Write-Host ""
Write-Host "=== DONE ==="
Write-Host "Runtime home : $RuntimeHome"
Write-Host "Plugin dir   : $PluginDir"
Write-Host "Viewer       : http://127.0.0.1:18800 (starts with Hermes session)"
