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
#      (именно plugins\<name> БЕЗ memory\ - upstream discovery Hermes)
#   4. config.yaml плагина (только при НОВОЙ установке; при обновлении настройки сохраняются):
#      local embedding (all-MiniLM-L6-v2), embedTraces=true (семантический поиск),
#      llm=local_only (LLM НЕ впихиваем - кристаллизация включается пользователем отдельно)
#   5. memory.provider: memtensor в config.yaml Hermes (hermes config set)
#   5a. Активация плагина: hermes plugins enable memtensor (иначе плагин виден, но не загружается)
#   5b. Включение памяти: hermes config set memory.memory_enabled true
#       + memory.user_profile_enabled true (без этого memory tool: "Memory is not available")
#
# При обновлении поверх работающего Hermes: файлы могут быть залочены службой -
# скрипт остановится с понятным сообщением (пользователь сам остановит службу).
# ============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$RootDir,
    [string]$LlmMode = ""
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# --- Пути (портируемая схема: HERMES_HOME = <root>\data\hermes) ---
$HermesHome  = Join-Path $RootDir "data\hermes"
$RuntimeHome = Join-Path $HermesHome "memos-plugin"
$PluginDir   = Join-Path $HermesHome "plugins\memtensor"
$AdapterDir  = Join-Path $RuntimeHome "adapters\hermes\memos_provider"
$HermesExe   = Join-Path $HermesHome "hermes-agent\venv\Scripts\hermes.exe"
# MEMOS_HOME принудительно = RuntimeHome (resolveHome в bridge отдаёт env-приоритет
# перед --home - иначе node-вызовы могут открыть чужой home из окружения).
$env:MEMOS_HOME = $RuntimeHome
$env:MEMOS_CONFIG_FILE = ""
$TempDir     = Join-Path $HermesHome "data\temp"   # резерв; обычно не нужен
if (-not (Test-Path $HermesHome)) { Write-Error "HERMES_HOME not found: $HermesHome"; exit 1 }

Write-Host "== MemOS (memos-local-plugin) installer =="
Write-Host "Root      : $RootDir"
Write-Host "Runtime   : $RuntimeHome"

# --- Проверка node/npm (PATH, затем системный AppData) ---
$npmCmd = (Get-Command npm.cmd -ErrorAction SilentlyContinue)
if (-not $npmCmd) {
    # .bat-окружение переопределяет APPDATA - берём СИСТЕМНЫЙ Roaming через .NET
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
# UPDATE: НЕ сносим RuntimeHome! data\ (БД), config.yaml, models\ и junction
# сохраняются как есть - распаковка свежего тарбола идёт ПОВЕРХ (только код).
$isUpdate = Test-Path (Join-Path $RuntimeHome "package.json")
if ($isUpdate) {
    Write-Host "Mode      : UPDATE ($RuntimeHome exists) - code update only, data/config/models kept"
} else {
    Write-Host "Mode      : INSTALL"
}

# UPDATE: остановить работающий daemon (bridge node.exe этого RuntimeHome) перед
# перезаписью кода - иначе daemon держит старый код/файлы в памяти до рестарта.
if ($isUpdate) {
    Write-Host "Stopping MemOS bridge processes (code update)..."
    try {
        $nodeProcs = Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue
        foreach ($p in @($nodeProcs)) {
            if ($p.CommandLine -and $p.CommandLine -like "*$RuntimeHome*") {
                Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
                Write-Host "  stopped PID $($p.ProcessId)"
            }
        }
    } catch { }
    Start-Sleep -Seconds 2
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
# Системный bsdtar (Windows tar.exe) - GNU tar из git-bash не понимает C:\ пути
$tarExe = Join-Path $env:SystemRoot "System32\tar.exe"
if (-not (Test-Path $tarExe)) { Write-Error "Windows tar.exe not found: $tarExe"; exit 1 }
$extractDir = Join-Path $packDir "extract"
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
& $tarExe -xzf $tgz.FullName -C $extractDir
if ($LASTEXITCODE -ne 0) { Write-Error "tar extraction failed (exit $($LASTEXITCODE))"; exit 1 }
New-Item -ItemType Directory -Path $RuntimeHome -Force | Out-Null
Copy-Item -Path (Join-Path $extractDir "package\*") -Destination $RuntimeHome -Recurse -Force
# Страховка: адаптер Hermes (adapters\hermes\memos_provider) декларируется в files
# npm-пакета, но при сбоях копирования может потеряться - проверяем и докопируем.
$adapterMarker = Join-Path $RuntimeHome "adapters\hermes\memos_provider\__init__.py"
if (-not (Test-Path $adapterMarker)) {
    Write-Host "WARNING: Hermes adapter missing after extract - re-copying adapters from package..."
    Copy-Item -Path (Join-Path $extractDir "package\adapters") -Destination $RuntimeHome -Recurse -Force
}
if (-not (Test-Path $adapterMarker)) {
    Write-Error "Hermes adapter STILL missing after re-copy: $adapterMarker"; exit 1
}
Write-Host "Hermes adapter OK: $RuntimeHome\adapters\hermes\memos_provider"
Remove-Item -LiteralPath (Join-Path $extractDir "package\tests") -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $extractDir "package\website") -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $packDir -Force -Recurse -ErrorAction SilentlyContinue

# --- 2. npm install (+ build только если dist НЕ приложен к тарболу) ---
Write-Host "npm install (native modules, may take a while)..."
Push-Location $RuntimeHome
# ERESOLVE upstream-баг (2.0.18): dsh-tools@rc.6 тянет dsh-user-approval@^0.1.0-rc.6,
# npm берёт rc.8, а тот требует peer dsh-agent@^0.1.0-rc.8 (в devDeps пинится rc.6).
# dsh-* — dev-инструменты DeepSeek harness, для Hermes-адаптера не нужны.
Invoke-Npm @("install", "--no-audit", "--no-fund", "--legacy-peer-deps")
# --- npm 11+ блокирует install-скрипты native-модулей по умолчанию: без prebuild-бинарей
#     better-sqlite3 / onnxruntime / sharp не работают - rebuild скачает prebuilds ---
$nativePkgs = @("better-sqlite3", "onnxruntime-node", "sharp", "protobufjs", "esbuild")
try {
    & $npmPath approve-scripts $nativePkgs 2>&1 | Out-Null
} catch {
    Write-Host "npm approve-scripts: skipped (npm < 11.16)"
}
try {
    Invoke-Npm (@("rebuild", "--no-audit", "--no-fund", "--legacy-peer-deps") + $nativePkgs)
} catch {
    Write-Host "npm rebuild (native prebuilds): skipped"
}
$bridgeBundled = Test-Path (Join-Path $RuntimeHome "dist\bridge.mjs")
if (-not $bridgeBundled) {
    Write-Host "dist not bundled - building bridge + viewer ..."
    Invoke-Npm @("run", "build:package")
} else {
    Write-Host "dist already bundled in npm tarball - skipping build"
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
# Целевая конфигурация (согласована с memos-fix.ps1):
#   * embedding.model -> ЛОКАЛЬНАЯ all-MiniLM-L6-v2 (не HF из РФ) - семантический поиск
#   * capture.embedTraces: true - эмбеддинги пишутся на каждый ход: новый trace
#     сразу находится по смыслу, ручной rebuild не нужен
#   * llm.provider: local_only - LLM НЕ настраиваем принудительно (автономный
#     режим: базовая память работает без LLM). Кристаллизация L2/L3 требует LLM -
#     включить при желании через viewer (:18800, Config) или вручную:
#     openai_compatible + внешний endpoint (deepseek и т.п.) либо provider: host
#     (LLM через сам Hermes). Локальная LLM для этого НЕ используется (медленно).
$pluginCfg = Join-Path $RuntimeHome "config.yaml"
if (-not (Test-Path $pluginCfg)) {
    # --- LLM для кристаллизации L2/L3 (по желанию): DeepSeek / локальная OpenAI-совместимая (Ollama) / нет ---
    $LlmProvider = "local_only"
    $LlmEndpoint = ""
    $LlmApiKey = "***"
    $LlmModel = ""
    $LlmExtra = ""
    if (-not $LlmMode -and -not [Console]::IsInputRedirected) {
        $LlmChoice = Read-Host "Кристаллизация L2/L3 через LLM? [D]eepSeek / [O]llama / [N]ет (по умолчанию N)"
        $LlmMode = $LlmChoice.ToUpper()
    }
    if ($LlmMode -eq "D" -or $LlmMode -eq "DEEPSEEK") {
        $LlmProvider = "openai_compatible"
        $LlmEndpoint = "https://api.deepseek.com/v1"
        $LlmModel = Read-Host "DeepSeek модель (Enter = deepseek-chat)"
        if (-not $LlmModel) { $LlmModel = "deepseek-chat" }
        $LlmApiKey = Read-Host "DeepSeek API ключ (sk-...)"
    } elseif ($LlmMode -eq "O" -or $LlmMode -eq "OLLAMA") {
        $LlmProvider = "openai_compatible"
        $LlmEndpoint = Read-Host "Ollama endpoint (Enter = http://localhost:11434/v1)"
        if (-not $LlmEndpoint) { $LlmEndpoint = "http://localhost:11434/v1" }
        $LlmModel = Read-Host "Ollama модель (например qwen2.5:14b)"
        $LlmApiKey = "ollama"
    }
    if ($LlmProvider -eq "openai_compatible") {
        $LlmExtra = @"
skillEvolver:
  fallbackToHost: false
  timeoutMs: 600000
  maxTokens: 8192
  model: $LlmModel
  provider: openai_compatible
  apiKey: "$LlmApiKey"
  endpoint: $LlmEndpoint
l3Llm:
  fallbackToHost: false
  timeoutMs: 600000
  maxTokens: 8192
  model: $LlmModel
  provider: openai_compatible
  apiKey: "$LlmApiKey"
  endpoint: $LlmEndpoint
"@
    }
    Write-Host "Writing plugin config.yaml (local embedder, no forced LLM, embedTraces=true, lightweight, telemetry OFF)..."
    @"
version: 1
viewer:
  port: 18800
embedding:
  provider: local
  apiKey: ""
  model: ${RuntimeHome}\models\all-MiniLM-L6-v2
llm:
  provider: $LlmProvider
  endpoint: "$LlmEndpoint"
  apiKey: $LlmApiKey
  model: "$LlmModel"
  maxTokens: 65536
  timeoutMs: 180000
storage:
  ftsTokenizer: trigram
algorithm:
  lightweightMemory:
    enabled: true
  capture:
    embedTraces: true
  retrieval:
    llmFilterEnabled: false
    llmFilterMinCandidates: 50
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
    if ($LlmExtra) { Add-Content -Path $pluginCfg -Value "`n$LlmExtra" -Encoding UTF8 }
} else {
    Write-Host "Plugin config.yaml exists - keeping user settings (re-run memos-fix.ps1 to realign)."
}

# --- 5. Активация провайдера в Hermes ---
# Уважаем состояние Hermes: включаем MemOS только при новой установке (INSTALL)
# или если она уже была включена (memory.provider=memtensor). При UPDATE
# выключенной MemOS состояние НЕ меняем - пользователь отключил её сознательно.
$wantActivate = $true
if ($isUpdate) {
    $curProvider = ""
    if (Test-Path $HermesExe) {
        $curProvider = (& $HermesExe config get memory.provider 2>$null | Out-String).Trim()
    }
    if ($curProvider -and $curProvider -notmatch "memtensor") {
        $wantActivate = $false
        Write-Host "MemOS installed but DISABLED in Hermes (memory.provider=$curProvider) - skipping activation."
        Write-Host "Enable later with: hermes config set memory.provider memtensor"
    }
}
if ($wantActivate) {
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

# --- 5a. Активация плагина memtensor в Hermes (plugins enable) ---
# Установщик ставит junction, но НЕ включает плагин: без этого Hermes видит
# плагин в списке, но не загружает его, и memory tool остаётся недоступным.
if (Test-Path $HermesExe) {
    $pluginStatus = & $HermesExe plugins list --json 2>$null | ConvertFrom-Json
    $mt = @($pluginStatus | Where-Object { $_.name -eq "memtensor" } | Select-Object -First 1)
    if ($mt.Count -eq 0 -or $mt[0].status -ne "enabled") {
        Write-Host "Enabling memtensor plugin (hermes plugins enable) ..."
        & $HermesExe plugins enable memtensor --no-allow-tool-override | Out-Null
        # Верификация (не верим коду на слово)
        $after = & $HermesExe plugins list --json 2>$null | ConvertFrom-Json
        $mtAfter = @($after | Where-Object { $_.name -eq "memtensor" } | Select-Object -First 1)
        if ($mtAfter.Count -gt 0 -and $mtAfter[0].status -eq "enabled") {
            Write-Host "memtensor plugin enabled (verified)."
        } else {
            Write-Host "WARNING: memtensor plugin still not enabled - check 'hermes plugins list'."
        }
    } else {
        Write-Host "memtensor plugin already enabled."
    }
} else {
    Write-Host "WARNING: hermes.exe not found - enable memtensor plugin manually (hermes plugins enable memtensor)."
}

# --- 5b. Включение памяти Hermes (memory_enabled + user_profile_enabled) ---
# Без memory_enabled=true память выключена даже при активном провайдере:
# memory tool отвечает "Memory is not available". Включаем через штатный
# hermes config set (никаких ручных правок config.yaml!).
if (Test-Path $HermesExe) {
    $memEnabled = & $HermesExe config get memory.memory_enabled 2>$null
    if ($memEnabled -match "true") {
        Write-Host "memory.memory_enabled already = true."
    } else {
        Write-Host "Enabling memory.memory_enabled ..."
        & $HermesExe config set memory.memory_enabled true | Out-Null
    }
    $userProfEnabled = & $HermesExe config get memory.user_profile_enabled 2>$null
    if ($userProfEnabled -match "true") {
        Write-Host "memory.user_profile_enabled already = true."
    } else {
        Write-Host "Enabling memory.user_profile_enabled ..."
        & $HermesExe config set memory.user_profile_enabled true | Out-Null
    }
} else {
    Write-Host "WARNING: hermes.exe not found - enable memory manually (hermes config set memory.memory_enabled true)."
}
}   # end if ($wantActivate)

# --- 6. Самотест (self-test) ---
Write-Host ""
Write-Host "Running self-test ..."
$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) { Write-Error "node not found - bridge runtime requires Node.js >= 20"; exit 1 }
$nodeExe = $nodeCmd.Source
$dbTestExpr = "const D=require('better-sqlite3');const db=new D(':memory:');db.exec('CREATE TABLE t(x)');db.prepare('INSERT INTO t VALUES(1)').run();db.close();console.log('OK')"
# 6.1 native bindings (better-sqlite3): без prebuild bridge падает на new Database()
Push-Location $RuntimeHome
$dbTest = & $nodeExe -e $dbTestExpr 2>&1
$attempt = 0
while ($LASTEXITCODE -ne 0 -and $attempt -lt 3) {
    $attempt++
    if ($attempt -eq 1) {
        Write-Host "native bindings missing - attempt ${attempt}: approve-scripts + rebuild ..."
        try { & $npmPath approve-scripts $nativePkgs 2>&1 | Out-Null } catch { }
        Invoke-Npm (@("rebuild", "--no-audit", "--no-fund") + $nativePkgs)
    } else {
        Write-Host "bindings still missing - attempt ${attempt}: npm rebuild again ..."
        Invoke-Npm (@("rebuild", "--no-audit", "--no-fund") + $nativePkgs)
    }
    $dbTest = & $nodeExe -e $dbTestExpr 2>&1
}
if ($LASTEXITCODE -eq 0) {
    Write-Host "self-test: better-sqlite3 bindings OK"
} else {
    Write-Error "better-sqlite3 broken after rebuild ($($dbTest | Select-Object -Last 1)) - retry installer"
    Pop-Location; exit 1
}
Pop-Location
# 6.2 MEMOS_HOME должен жить в Start.bat (портабельный runtime home)
$startBat = Join-Path $RootDir "Start.bat"
if (Test-Path $startBat) {
    $startContent = [IO.File]::ReadAllText($startBat)
    if ($startContent -notmatch "MEMOS_HOME") {
        $startContent = $startContent -replace 'set "HERMES_HOME=([^\r\n]*)\r?\n', "`$&set `"MEMOS_HOME=%HERMES_HOME%\memos-plugin`"`r`n"
        [IO.File]::WriteAllText($startBat, $startContent)
        Write-Host "self-test: MEMOS_HOME added to Start.bat"
    } else {
        Write-Host "self-test: MEMOS_HOME already in Start.bat"
    }
}
# 6.3 data dir + тестовый запуск bridge: БД должна создаться В runtime home (портабельно)
$dataDir = Join-Path $RuntimeHome "data"
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$testBridge = $null
try {
    $testBridge = Start-Process -FilePath $nodeExe -ArgumentList @("dist\bridge.mjs", "--agent=hermes", "--home=$RuntimeHome", "--daemon") -WorkingDirectory $RuntimeHome -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 12
} catch {
    Write-Host "WARNING: test bridge start failed - will start with the next Hermes session"
}
try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:18800/" -UseBasicParsing -TimeoutSec 5
    Write-Host "self-test: viewer http://127.0.0.1:18800 HTTP $($resp.StatusCode)"
} catch {
    Write-Host "WARNING: viewer health check failed - it will start with the next Hermes session"
}
$dbFile = Join-Path $dataDir "memos.db"
if (Test-Path $dbFile) {
    Write-Host "self-test: MemOS DB OK: $dbFile"
} else {
    Write-Host "WARNING: DB not created yet - it will be created on the first Hermes session (ensure MEMOS_HOME is set)"
}
if ($testBridge -and -not $testBridge.HasExited) { Stop-Process -Id $testBridge.Id -Force -ErrorAction SilentlyContinue }

Write-Host ""
Write-Host "=== DONE ==="
Write-Host "Runtime home : $RuntimeHome"
Write-Host "Plugin dir   : $PluginDir"
Write-Host "Viewer       : http://127.0.0.1:18800 (starts with Hermes session)"
