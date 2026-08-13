# memos-fix.ps1 - FALLBACK: доводит установку MemOS до идеала (самодостаточный фиксер)
# Не является частью установщика: запускается ПОСЛЕ install-memos.ps1 (или отдельно).
# Правило: скрипты вендора НЕ трогаем - проверяем недостающее и ДОУСТАНАВЛИВАЕМ.
#  1. native bindings (better-sqlite3) - approve-scripts (поштучно!) + npm rebuild
#  2. config.yaml - через ШТАТНЫЙ API bridge (GET/PATCH /api/v1/config):
#     llm local_only (НЕ впихиваем LLM), lightweightMemory=true, llmFilterEnabled=false,
#     embedTraces=true (семантический поиск), embedding.model -> локальная модель (не HF из РФ!)
#  3. MEMOS_HOME в Start.bat (портабельный runtime home)
#  4. memory.provider = memtensor (hermes config set)
#  4a. Плагин memtensor = enabled (hermes plugins enable) - без этого memory tool недоступен!
#  4b. memory.memory_enabled + user_profile_enabled = true (hermes config set)
#  5. junction plugins\memtensor
#  6. embedding-модель Xenova/all-MiniLM-L6-v2 (hf download + локальный прокси)
#  7. тестовый bridge: БД + viewer + реальный поиск (UTF-8) через API
# Использование:  powershell -ExecutionPolicy Bypass -File memos-fix.ps1 -RootDir <root>
param(
    [string]$RootDir = ""
)

$ErrorActionPreference = "Continue"

if (-not $RootDir) { $RootDir = Split-Path -Parent $PSScriptRoot | Split-Path -Parent }
$HermesHome   = Join-Path $RootDir "data\hermes"
$RuntimeHome  = Join-Path $HermesHome "memos-plugin"
$PluginDir    = Join-Path $HermesHome "plugins\memtensor"
$AdapterDir   = Join-Path $RuntimeHome "adapters\hermes\memos_provider"
$HermesExe    = Join-Path $HermesHome "hermes-agent\venv\Scripts\hermes.exe"
$PythonExe    = Join-Path $HermesHome "hermes-agent\venv\Scripts\python.exe"
$HfExe        = Join-Path $HermesHome "hermes-agent\venv\Scripts\hf.exe"
$StartBat     = Join-Path $RootDir "Start.bat"
$NodeBin      = (Get-Command node -ErrorAction SilentlyContinue)
# npm: приоритет 1 - портабельный/пользовательский npm из APPDATA (Start.bat: APPDATA=%DATA_DIR%\appdata;
# там стоит npm 12, а системный npm.cmd в Program Files может вести на сломанный встроенный npm-cli.js ->
# MODULE_NOT_FOUND). Логика как в InstallOrUpdate-Deps.bat (REAL_NPM_DIR).
$NpmCmd       = $null
$appdataNpm   = Join-Path $env:APPDATA "npm\npm.cmd"
if (Test-Path $appdataNpm) { $NpmCmd = Get-Item $appdataNpm }
if (-not $NpmCmd) {
    $realNpmDir   = Join-Path (Join-Path (Join-Path $env:SystemDrive "Users\$env:USERNAME") "AppData\Roaming") "npm"
    if (Test-Path (Join-Path $realNpmDir "npm.cmd")) { $NpmCmd = Get-Item (Join-Path $realNpmDir "npm.cmd") }
}
if (-not $NpmCmd) {
    foreach ($prof in Get-ChildItem (Join-Path $env:SystemDrive "Users") -Directory -Filter "$env:USERNAME.*" -ErrorAction SilentlyContinue) {
        $cand = Join-Path (Join-Path (Join-Path $prof.FullName "AppData\Roaming") "npm") "npm.cmd"
        if (Test-Path $cand) { $NpmCmd = Get-Item $cand; break }
    }
}
if (-not $NpmCmd) { $NpmCmd = Get-Command npm.cmd -ErrorAction SilentlyContinue }
if (-not $NpmCmd) { $NpmCmd = Get-Command npm -ErrorAction SilentlyContinue }
# нормализация: Get-Item -> FileInfo (.FullName), Get-Command -> ApplicationInfo (.Source)
$NpmCmdPath = ""
if ($NpmCmd -is [System.IO.FileInfo]) { $NpmCmdPath = $NpmCmd.FullName }
elseif ($NpmCmd) { $NpmCmdPath = $NpmCmd.Source }
$NativePkgs   = @("better-sqlite3", "onnxruntime-node", "sharp", "protobufjs", "esbuild")
$EmbedModelDir = Join-Path $RuntimeHome "models\all-MiniLM-L6-v2"

$fixed = @()

Write-Host "== MemOS fallback fixer =="
Write-Host "Root       : $RootDir"
Write-Host "Runtime    : $RuntimeHome"

if (-not (Test-Path (Join-Path $RuntimeHome "dist\bridge.mjs"))) {
    Write-Host "ERROR: MemOS runtime not found at $RuntimeHome - run the installer first."
    exit 1
}

function Invoke-Npm {
    param([string[]]$NpmArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $NpmCmdPath @NpmArgs 2>&1 | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return $code
}

# --- 0. ВЕРСИЯ ПАКЕТА: НЕ ПРОВЕРЯЕМ (правило пользователя: какая пришла, такая и пришла!
#     фикс только докачивает недостающее и настраивает конфиг по умолчанию). ---

# --- 1. node_modules + native bindings (пошагово, как вендорский install.hermes.sh) ---
Push-Location $RuntimeHome
try {
    if (-not (Test-Path (Join-Path $RuntimeHome "node_modules"))) {
        Write-Host "[1/7] node_modules missing - npm install (as vendor installer does)..."
        $code = Invoke-Npm @("install", "--no-audit", "--no-fund", "--prefer-offline")
        if ($code -ne 0) {
            Write-Host "ERROR: npm install failed."
            Pop-Location
            exit 1
        }
        $fixed += "node_modules"
    }
    $dbTestExpr = "const D=require('better-sqlite3');const db=new D(':memory:');db.exec('CREATE TABLE t(x)');db.close();console.log('OK')"
    $dbTest = & $NodeBin.Source -e $dbTestExpr 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[1/7] better-sqlite3 bindings: OK"
    } else {
        Write-Host "[1/7] bindings missing - approve-scripts (per-package) + npm rebuild ..."
        & $NpmCmdPath approve-scripts $NativePkgs 2>&1 | Out-Null
        $code = Invoke-Npm (@("rebuild", "--no-audit", "--no-fund") + $NativePkgs)
        $dbTest = & $NodeBin.Source -e $dbTestExpr 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[1/7] bindings fixed via approve-scripts + rebuild"
            $fixed += "bindings"
        } else {
            Write-Host "ERROR: better-sqlite3 still broken after rebuild - check network to github.com (prebuilds)."
            Pop-Location
            exit 1
        }
    }
    # 1b. Манифест plugin.yaml -> memos_provider/ (вендорский install.hermes.sh шаг 0)
    $providerManifest = Join-Path $AdapterDir "plugin.yaml"
    $adapterManifest = Join-Path $RuntimeHome "adapters\hermes\plugin.yaml"
    if (-not (Test-Path $providerManifest) -and (Test-Path $adapterManifest)) {
        Copy-Item $adapterManifest $providerManifest -Force
        Write-Host "[1/7] plugin.yaml copied to memos_provider/"
        $fixed += "plugin.yaml"
    }
} finally {
    Pop-Location
}

# --- 6. embedding-модель (проверяем ДО конфига: путь в PATCH зависит от неё) ---
$embedModelOnnx = Join-Path $EmbedModelDir "onnx\model.onnx"
$embedModelTok = Join-Path $EmbedModelDir "tokenizer.json"
if ((Test-Path $embedModelOnnx) -and (Test-Path $embedModelTok)) {
    Write-Host "[6/7] embedding model: OK"
} else {
    Write-Host "  -   embedding model (Xenova/all-MiniLM-L6-v2)..."
    # 6a. Копия из локального HF-кэша, если модель уже скачана туда
    $hfCacheRoot = Join-Path $env:USERPROFILE ".cache\huggingface"
    $snap = Get-ChildItem -Path (Join-Path $hfCacheRoot "hub\models--Xenova--all-MiniLM-L6-v2\snapshots") -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($snap) {
        Copy-Item -Path (Join-Path $snap.FullName "*") -Destination $EmbedModelDir -Recurse -Force
        Write-Host "  +   embedding model copied from HF cache."
        $fixed += "embedding-model"
    }
    # 6b. Каскад скачивания: hf.exe + прокси -> hf.exe + hf-mirror -> прямой hf
    if (-not (Test-Path $embedModelOnnx) -and (Test-Path $HfExe)) {
        $env:HTTPS_PROXY = "http://127.0.0.1:10809"
        $env:HTTP_PROXY  = "http://127.0.0.1:10809"
        & $HfExe download Xenova/all-MiniLM-L6-v2 --local-dir $EmbedModelDir 2>&1 | Out-Null
        Remove-Item Env:HTTPS_PROXY -ErrorAction SilentlyContinue
        Remove-Item Env:HTTP_PROXY -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path $embedModelOnnx) -and (Test-Path $HfExe)) {
        $env:HF_ENDPOINT = "https://hf-mirror.com"
        & $HfExe download Xenova/all-MiniLM-L6-v2 --local-dir $EmbedModelDir 2>&1 | Out-Null
        Remove-Item Env:HF_ENDPOINT -ErrorAction SilentlyContinue
    }
    if (((-not (Test-Path $embedModelOnnx)) -or (-not (Test-Path $embedModelTok))) -and (Test-Path $HfExe)) {
        & $HfExe download Xenova/all-MiniLM-L6-v2 --local-dir $EmbedModelDir 2>&1 | Out-Null
    }
    if ((Test-Path $embedModelOnnx) -and (Test-Path $embedModelTok)) {
        Write-Host "  +   embedding model installed: $EmbedModelDir"
        $fixed += "embedding-model"
    } else {
        Write-Host "  .   embedding model NOT installed (vector search will be empty until fixed)"
    }
}

# --- 2. config.yaml через штатный API bridge (GET/PATCH /api/v1/config) ---
$testBridge = $null
try {
    $testBridge = Start-Process -FilePath $NodeBin.Source `
        -ArgumentList @("dist\bridge.mjs", "--agent=hermes", "--home=$RuntimeHome", "--daemon") `
        -WorkingDirectory $RuntimeHome -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 15
} catch {
    Write-Host "WARNING: bridge start failed - config check skipped (will retry on next Hermes session)."
}
$viewerOk = $false
try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:18800/" -UseBasicParsing -TimeoutSec 5
    $viewerOk = ($resp.StatusCode -eq 200)
} catch { }

if ($viewerOk) {
    # 2a. Читаем текущий resolved конфиг
    $cfg = $null
    try {
        $cfg = (Invoke-RestMethod -Uri "http://127.0.0.1:18800/api/v1/config" -Method Get -TimeoutSec 10)
    } catch { }
    if ($cfg) {
        $patch = @{}
        # --- 2b. Кристаллизация через deepseek (по желанию пользователя!) ---
        # (а) ключ из окружения DEEPSEEK_API_KEY (если есть) - без вопросов;
        # (б) иначе спросить: ввести ключ (кристаллизация через deepseek) или отказаться (local_only).
        $useDeepSeek = $false
        $dsKey = ""
        # Ключ уже настроен в config.yaml? (реальный, не маскировка '***')
        $existingKey = ""
        $cfgPath2 = Join-Path $RuntimeHome "config.yaml"
        if (Test-Path $cfgPath2) {
            $rawCfg = Get-Content -Path $cfgPath2 -Raw -Encoding UTF8
            if ($rawCfg -match 'apiKey:\s*"?(sk-[^"
\n]+)"?') { $existingKey = $Matches[1].Trim() }
        }
        if ($existingKey.Length -gt 10) {
            $useDeepSeek = $true
            $dsKey = $existingKey
            $tail = $existingKey.Substring([Math]::Max(0, $existingKey.Length - 4))
            Write-Host "  Crystallization: deepseek key already configured (sk-...$tail) - keeping it"
            $resp2 = Read-Host "  Replace deepseek key? (Y - enter new, N - keep existing) [N]"
            if ($resp2 -match "^[yY]") {
                $dsKey = Read-Host "  Enter new deepseek API key (sk-...):"
                if ($dsKey.Trim() -eq "") { $dsKey = $existingKey; Write-Host "  Empty input - keeping existing key." }
            }
        } elseif ($env:DEEPSEEK_API_KEY -and $env:DEEPSEEK_API_KEY.Trim() -ne "") {
            $useDeepSeek = $true
            $dsKey = $env:DEEPSEEK_API_KEY.Trim()
            Write-Host "  Crystallization: deepseek (DEEPSEEK_API_KEY from env)"
        } else {
            $resp = Read-Host "  Crystallization via deepseek? (Y - enter key, N - autonomous without LLM) [N]"
            if ($resp -match "^[yY]") {
                $dsKey = Read-Host "  Enter deepseek API key (sk-...):"
                if ($dsKey.Trim() -ne "") { $useDeepSeek = $true }
            }
        }
        # llm: deepseek (если пользователь дал ключ) ИЛИ local_only (автономный режим - без LLM).
        $llmProvider = $cfg.config.llm.provider
        if ($useDeepSeek) {
            $patch.llm = @{
                provider = "openai_compatible"
                endpoint = "https://api.deepseek.com/v1"
                # apiKey НЕ шлём в PATCH: writer плагина МАСКИРУЕТ его (пишет '***' -
                # невалидный YAML для 2.0.15 - daemon падает!). Ключ пишем НАПРЯМУЮ после PATCH.
                model = "deepseek-v4-flash"
            }
            Write-Host "  Crystallization: deepseek (openai_compatible, model=deepseek-v4-flash)"
        } elseif ($llmProvider -ne "local_only") {
            $patch.llm = @{ provider = "local_only" }
        }
        # fallbackToHost=false: summarizer/кристаллизация НЕ падают в fallback на host-LLM (локальную!)
        # (иначе local_only всё равно мучает локальную LLM через Hermes-bridge - проверено 12.08)
        $patch.llm.fallbackToHost = $false
        # lightweight=true: только summarize+embed+retrieval, нет фоновых LLM-задач
        # (с local_only поиск по трассам работает - проверено стресс-тестом 1000 запросов)
        $lw = $cfg.config.algorithm.lightweightMemory.enabled
        if ($lw -ne $true) {
            if (-not $patch.algorithm) { $patch.algorithm = @{} }
            $patch.algorithm.lightweightMemory = @{ enabled = $true }
        }
        # embedTraces=true: эмбеддинги пишутся на каждый ход - новый trace сразу
        # находится по смыслу (семантический поиск), ручной rebuild не нужен.
        # Старые трассы (созданные при embedTraces=false) добиваем rebuild'ом в шаге 7b.
        $et = $cfg.config.algorithm.capture.embedTraces
        if ($et -ne $true) {
            if (-not $patch.algorithm) { $patch.algorithm = @{} }
            if (-not $patch.algorithm.capture) { $patch.algorithm.capture = @{} }
            $patch.algorithm.capture.embedTraces = $true
        }
        # финальный LLM-фильтр поиска: выключен + не запускается при <50 кандидатов
        $lf = $cfg.config.algorithm.retrieval.llmFilterEnabled
        if ($lf -ne $false) {
            if (-not $patch.algorithm) { $patch.algorithm = @{} }
            if (-not $patch.algorithm.retrieval) { $patch.algorithm.retrieval = @{} }
            $patch.algorithm.retrieval.llmFilterEnabled = $false
        }
        $mc = $cfg.config.algorithm.retrieval.llmFilterMinCandidates
        if ($mc -lt 50) {
            if (-not $patch.algorithm) { $patch.algorithm = @{} }
            if (-not $patch.algorithm.retrieval) { $patch.algorithm.retrieval = @{} }
            $patch.algorithm.retrieval.llmFilterMinCandidates = 50
        }
        $emb = $cfg.config.embedding.model
        if ($emb -notmatch "all-MiniLM-L6-v2") {
            if (-not $patch.embedding) { $patch.embedding = @{} }
            $patch.embedding.model = $EmbedModelDir
        }
        if ($patch.Count -gt 0) {
            $body = $patch | ConvertTo-Json -Depth 6 -Compress
            # БЭКАП config.yaml перед правкой (минное поле - откат при поломке!)
            Copy-Item -Path (Join-Path $RuntimeHome "config.yaml") -Destination (Join-Path $RuntimeHome "config.yaml.bak") -Force
            try {
                Invoke-RestMethod -Uri "http://127.0.0.1:18800/api/v1/config" -Method Patch -Body $body -ContentType "application/json" -TimeoutSec 10 | Out-Null
                Write-Host "[2/7] config.yaml fixed via API (PATCH /api/v1/config): $($patch.Keys -join ', ')"
                $fixed += "config"
            } catch {
                Write-Host "WARNING: config PATCH failed: $($_.Exception.Message)"
            }
        } else {
            Write-Host "[2/7] config.yaml: OK (llm local_only, lightweight ON, llmFilter OFF, embedTraces=true, local embedder)"
        }
        # apiKey ПИШЕМ НАПРЯМУЮ (writer маскирует -> '***' ломает YAML 2.0.15!):
        # строка apiKey: "реальный" - в кавычках (YAML-строка, не alias!)
        if ($useDeepSeek -and $dsKey) {
            $cfgPath = Join-Path $RuntimeHome "config.yaml"
            $raw = Get-Content -Path $cfgPath -Raw -Encoding UTF8
            $raw = [regex]::Replace($raw, '(apiKey:[ \t]*)"?\*{3}"?', ('${1}"' + $dsKey + '"'))
            Set-Content -Path $cfgPath -Value $raw -Encoding UTF8 -NoNewline
            Write-Host "  apiKey: written directly (bypass writer masking)"
            $fixed += "apikey"
        }
        # ВАЛИДАЦИЯ YAML после любых правок (минное поле!): python + pyyaml (venv Hermes - js-yaml в node_modules плагина нет)
        & $PythonExe -c "import yaml,sys; yaml.safe_load(open(sys.argv[1],encoding='utf-8'))" (Join-Path $RuntimeHome "config.yaml")
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  config.yaml: YAML valid"
        } else {
            Write-Host "  ERROR: config.yaml INVALID after fix - restoring backup!"
            Copy-Item -Path (Join-Path $RuntimeHome "config.yaml.bak") -Destination (Join-Path $RuntimeHome "config.yaml") -Force
        }
    }
} else {
    Write-Host "WARNING: viewer not reachable - config check skipped."
}

# --- 3. MEMOS_HOME в Start.bat ---
if (Test-Path $StartBat) {
    $start = Get-Content $StartBat -Raw
    if ($start -notmatch "MEMOS_HOME") {
        $start = $start -replace 'set "HERMES_HOME=.*?\r?\n', "`$0set `"MEMOS_HOME=%HERMES_HOME%\memos-plugin`"`r`n"
        [System.IO.File]::WriteAllText($StartBat, $start, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[3/7] MEMOS_HOME added to Start.bat"
        $fixed += "MEMOS_HOME"
    } else {
        Write-Host "[3/7] MEMOS_HOME in Start.bat: OK"
    }
} else {
    Write-Host "WARNING: Start.bat not found at $StartBat"
}

# --- 4. memory.provider = memtensor ---
if (Test-Path $HermesExe) {
    $check = & $HermesExe config get memory.provider 2>$null
    if ($check -match "memtensor") {
        Write-Host "[4/7] memory.provider: OK (memtensor)"
    } else {
        & $HermesExe config set memory.provider memtensor | Out-Null
        Write-Host "[4/7] memory.provider set to memtensor"
        $fixed += "provider"
    }
} else {
    Write-Host "WARNING: hermes.exe not found - set memory.provider manually."
}

# --- 4a. Плагин memtensor: enabled (без этого memory tool недоступен!) ---
if (Test-Path $HermesExe) {
    $pluginStatus = & $HermesExe plugins list --json 2>$null | ConvertFrom-Json
    $mt = @($pluginStatus | Where-Object { $_.name -eq "memtensor" } | Select-Object -First 1)
    if ($mt.Count -eq 0 -or $mt[0].status -ne "enabled") {
        Write-Host "[4a/7] memtensor plugin not enabled - enabling (hermes plugins enable memtensor)..."
        & $HermesExe plugins enable memtensor | Out-Null
        $after = & $HermesExe plugins list --json 2>$null | ConvertFrom-Json
        $mtAfter = @($after | Where-Object { $_.name -eq "memtensor" } | Select-Object -First 1)
        if ($mtAfter.Count -gt 0 -and $mtAfter[0].status -eq "enabled") {
            Write-Host "[4a/7] memtensor plugin enabled (verified)"
            $fixed += "plugin-enabled"
        } else {
            Write-Host "WARNING: memtensor plugin still not enabled - check 'hermes plugins list'."
        }
    } else {
        Write-Host "[4a/7] memtensor plugin: OK (enabled)"
    }
} else {
    Write-Host "WARNING: hermes.exe not found - enable memtensor manually (hermes plugins enable memtensor)."
}

# --- 4b. Память Hermes: memory_enabled + user_profile_enabled (штатный hermes config set!) ---
if (Test-Path $HermesExe) {
    $memEnabled = & $HermesExe config get memory.memory_enabled 2>$null
    if ($memEnabled -match "true") {
        Write-Host "[4b/7] memory.memory_enabled: OK (true)"
    } else {
        & $HermesExe config set memory.memory_enabled true | Out-Null
        Write-Host "[4b/7] memory.memory_enabled set to true"
        $fixed += "memory-enabled"
    }
    $userProfEnabled = & $HermesExe config get memory.user_profile_enabled 2>$null
    if ($userProfEnabled -match "true") {
        Write-Host "[4b/7] memory.user_profile_enabled: OK (true)"
    } else {
        & $HermesExe config set memory.user_profile_enabled true | Out-Null
        Write-Host "[4b/7] memory.user_profile_enabled set to true"
        $fixed += "user-profile-enabled"
    }
} else {
    Write-Host "WARNING: hermes.exe not found - enable memory manually (hermes config set memory.memory_enabled true)."
}

# --- 5. junction plugins\memtensor ---
if (-not (Test-Path (Join-Path $PluginDir "__init__.py"))) {
    if (Test-Path $PluginDir) { Remove-Item -LiteralPath $PluginDir -Force -Recurse -ErrorAction SilentlyContinue }
    New-Item -ItemType Junction -Path $PluginDir -Value $AdapterDir | Out-Null
    Write-Host "[5/7] junction recreated: $PluginDir"
    $fixed += "junction"
} else {
    Write-Host "[5/7] junction: OK"
}

# --- 7. ФИНАЛЬНЫЙ SELF-TEST (после всех фиксов): БД + viewer + реальный поиск ---
Write-Host ""
Write-Host "Running self-test ..."
$dataDir = Join-Path $RuntimeHome "data"
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$dbFile = Join-Path $dataDir "memos.db"
# 6b. Если БД ещё нет - создаём схему ДО первого запуска Hermes (иначе self-test ругается)
if (-not (Test-Path $dbFile)) {
    $initScript = Join-Path $dataDir "init-db.mjs"
    [System.IO.File]::WriteAllText($initScript, @'
import { openDb, runMigrations } from "../dist/core/storage/index.js";
const dbPath = new URL("./memos.db", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");
const db = openDb({ filepath: dbPath, agent: "hermes" });
runMigrations(db);
db.close();
console.log("DB init OK");
'@, (New-Object System.Text.UTF8Encoding $false))
    & $NodeBin.Source $initScript 2>&1 | Out-Null
    Remove-Item $initScript -Force -ErrorAction SilentlyContinue
}
if (Test-Path $dbFile) {
    Write-Host "[7/7] MemOS DB OK: $dbFile"
} else {
    Write-Host "WARNING: DB not created yet - it will appear on the first Hermes session."
}
try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:18800/" -UseBasicParsing -TimeoutSec 5
    Write-Host "[7/7] viewer :18800 HTTP $($resp.StatusCode)"
    # тестовый поиск через API (UTF-8 JSON) - реальная проверка vector search
    $q = @{ query = "любимая страна для путешествий" } | ConvertTo-Json -Compress
    try {
        $sr = Invoke-RestMethod -Uri "http://127.0.0.1:18800/api/v1/memory/search" -Method Post -Body $q -ContentType "application/json" -TimeoutSec 30
        $n = @($sr.hits).Count
        if ($n -gt 0) {
            Write-Host "[7/7] memory search: OK ($n hit(s))"
        } else {
            Write-Host "[7/7] memory search: 0 hits (embeddings may still be building - wait 1-3 min and retry)"
        }
    } catch {
        Write-Host "[7/7] memory search: skipped ($($_.Exception.Message))"
    }
    # 7b. Пересчёт эмбеддингов (локально, БЕЗ LLM): покрывает трассы, созданные при
    #     embedTraces=false (массовая загрузка) и старые трассы после UPDATE
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:18800/api/v1/embeddings/rebuild" -Method Post -Body "{}" -ContentType "application/json" -TimeoutSec 10 | Out-Null
        Write-Host "[7/7] embeddings rebuild: launched (local, no LLM)"
    } catch {
        Write-Host "WARNING: embeddings rebuild failed: $($_.Exception.Message)"
    }
} catch {
    Write-Host "[7/7] viewer health check failed - it will start with the next Hermes session"
}
# --- Финальный вердикт: self-test должен быть успешен, иначе ОШИБКА ---
$dbOk = Test-Path $dbFile
$viewerOkFinal = $false
try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:18800/" -UseBasicParsing -TimeoutSec 5
    $viewerOkFinal = ($resp.StatusCode -eq 200)
} catch { }
if ($testBridge -and -not $testBridge.HasExited) { Stop-Process -Id $testBridge.Id -Force -ErrorAction SilentlyContinue }

Write-Host ""
if ($dbOk -and $viewerOkFinal) {
    if ($fixed.Count -gt 0) {
        Write-Host "MemOS FIXED: $($fixed -join ', ') - all checks passed"
    } else {
        Write-Host "MemOS FIX: everything is already OK - all checks passed"
    }
    exit 0
} else {
    Write-Host "ERROR: self-test failed (DB: $dbOk, viewer: $viewerOkFinal) - see messages above"
    exit 1
}
