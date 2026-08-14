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
# MEMOS_HOME: принудительно = RuntimeHome! resolveHome (core/config/paths.js)
# отдаёт приоритет env MEMOS_HOME перед --home: без этого daemon, запущенный
# из fix, открывает ЧУЖОЙ home (напр. домский C:\ из окружения desktop).
$env:MEMOS_HOME = $RuntimeHome
$env:MEMOS_CONFIG_FILE = ""
$HermesExe    = Join-Path $HermesHome "hermes-agent\venv\Scripts\hermes.exe"
$PythonExe    = Join-Path $HermesHome "hermes-agent\venv\Scripts\python.exe"
$HfExe        = Join-Path $HermesHome "hermes-agent\venv\Scripts\hf.exe"
$StartBat     = Join-Path $RootDir "Start.bat"
# Состояние MemOS в Hermes: включена (memory.provider=memtensor) или выключена.
# Скрипт УВАЖАЕТ его: активацию и кристаллизацию делает только при включённой
# MemOS; иначе пользователь отключил её сознательно (дом при полигоне на :18800).
$memActive = $false
if (Test-Path $HermesExe) {
    $memProvider = (& $HermesExe config get memory.provider 2>$null | Out-String).Trim()
    if ($memProvider -match "memtensor") { $memActive = $true }
}
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

# --- 2a. apiKey: *** (голая маскировка writer'а) ломает YAML-парсер bridge ---
# ("Unresolved alias: **") - чиним НАПРЯМУЮ в файле, ДО старта daemon, иначе
# viewer не поднимется и шаг 2 (PATCH через API) станет недостижимым.
$cfgPathRaw = Join-Path $RuntimeHome "config.yaml"
if (Test-Path $cfgPathRaw) {
    $rawCfg = Get-Content -Path $cfgPathRaw -Raw -Encoding UTF8
    if ($rawCfg -match 'apiKey:\s*\*{3}') {
        $rawCfg = [regex]::Replace($rawCfg, 'apiKey:\s*\*{3}', 'apiKey: ""')
        [System.IO.File]::WriteAllText($cfgPathRaw, $rawCfg, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[2a/7] config.yaml: fixed bare 'apiKey: ***' -> 'apiKey: \"\"' (invalid YAML alias)"
        $fixed += "apikey-invalid"
    }
}

# --- 2. config.yaml через штатный API bridge (GET/PATCH /api/v1/config) ---
# Обеспечиваем viewer daemon на :18800: если не отвечает - поднимаем сами
# (как в install-memos.ps1 dd275b7) и оставляем работать, без "next session".
$viewerOk = $false
try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:18800/api/v1/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
    $viewerOk = ($resp.StatusCode -eq 200)
} catch { }
if (-not $viewerOk) {
    Write-Host "[2/7] viewer :18800 not running - starting daemon for verification..."
    try {
        $daemonLogOut = Join-Path $RuntimeHome "logs\fixer-daemon.out.log"
        $daemonLogErr = Join-Path $RuntimeHome "logs\fixer-daemon.err.log"
        $null = Start-Process -FilePath $NodeBin.Source `
            -ArgumentList @("dist\bridge.mjs", "--agent=hermes", "--home=$RuntimeHome", "--daemon") `
            -WorkingDirectory $RuntimeHome -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $daemonLogOut -RedirectStandardError $daemonLogErr
        $waitSec = 0
        for ($i = 0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 1
            $waitSec = $i + 1
            try {
                $resp = Invoke-WebRequest -Uri "http://127.0.0.1:18800/api/v1/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction Stop
                if ($resp.StatusCode -eq 200) { $viewerOk = $true; break }
            } catch { }
        }
        if ($viewerOk) {
            Write-Host "[2/7] viewer daemon started, health OK (waited ${waitSec}s) - viewer stays up on :18800"
        } else {
            Write-Host "WARNING: viewer daemon did not become healthy in 30s - see logs\fixer-daemon.err.log"
        }
    } catch {
        Write-Host "WARNING: viewer daemon start failed - config check skipped (will retry on next Hermes session)."
    }
}

if ($viewerOk) {
    # 2a. Читаем текущий resolved конфиг
    $cfg = $null
    try {
        $cfg = (Invoke-RestMethod -Uri "http://127.0.0.1:18800/api/v1/config" -Method Get -TimeoutSec 10)
    } catch { }
    if ($cfg) {
        $patch = @{}
        if (-not $memActive) {
            Write-Host "[2/7] MemOS disabled in Hermes (memory.provider not set) - LLM/crystallization settings skipped (applied on enable)."
        } else {
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
            $tail = $existingKey.Substring([Math]::Max(0, $existingKey.Length - 4))
            Write-Host "  Crystallization: deepseek key already configured (sk-...$tail)"
            Write-Host "  Use deepseek? (Y - yes, N - switch to local llama-server) [Y]: " -ForegroundColor Yellow -NoNewline
            $resp2 = Read-Host
            if ($resp2 -match "^[nN]") {
                Write-Host "  Switching crystallization to local llama-server"
            } else {
                $useDeepSeek = $true
                $dsKey = $existingKey
                Write-Host "  Replace deepseek key? (Y - enter new, N - keep existing) [N]: " -ForegroundColor Yellow -NoNewline
                $resp2b = Read-Host
                if ($resp2b -match "^[yY]") {
                    Write-Host "  Enter new deepseek API key (sk-...): " -ForegroundColor Yellow -NoNewline
                    $dsKey = Read-Host
                    if ($dsKey.Trim() -eq "") { $dsKey = $existingKey; Write-Host "  Empty input - keeping existing key." }
                }
            }
        } elseif ($env:DEEPSEEK_API_KEY -and $env:DEEPSEEK_API_KEY.Trim() -ne "") {
            $useDeepSeek = $true
            $dsKey = $env:DEEPSEEK_API_KEY.Trim()
            Write-Host "  Crystallization: deepseek (DEEPSEEK_API_KEY from env)"
        } else {
            Write-Host "  Crystallization via deepseek? (Y - enter key, N - use local llama-server) [N]: " -ForegroundColor Yellow -NoNewline
            $resp = Read-Host
            if ($resp -match "^[yY]") {
                Write-Host "  Enter deepseek API key (sk-...): " -ForegroundColor Yellow -NoNewline
                $dsKey = Read-Host
                if ($dsKey.Trim() -ne "") { $useDeepSeek = $true }
            }
        }
        # LLM-схема кристаллизации (важно! по архитектуре MemOS):
        #   llm  = deepseek/llama -> L1 scoring/reward + L2-индукция (политики) + skills + feedback
        #                      (ВСЕ эти подсистемы идут через единый llm-клиент; l3Llm - только L3)
        #   l3Llm = то же -> L3 world models
        #   skillEvolver = то же -> эволюция навыков
        #   lightweight=false -> фоновые LLM-задачи (кристаллизация) НЕ скипаются!
        #                        (lightweight=true скипает L2/L3/skills - кристаллизация мертва)
        #   fallbackToHost=false -> НЕ падать на host-LLM (kobold думал 42с на кристаллизации!)
        #   Приоритет: deepseek (ключ введён) -> local_only (llama-подключение пропишет sync-memos-llm.ps1 при первом запуске Hermes).
        $llmProvider = $cfg.config.llm.provider
        $cryLlm = $null
        if ($useDeepSeek) {
            $cryLlm = @{
                provider = "openai_compatible"
                endpoint = "https://api.deepseek.com/v1"
                # apiKey НЕ шлём в PATCH: writer плагина МАСКИРУЕТ его (пишет '***' -
                # невалидный YAML для 2.0.15 - daemon падает!). Ключ пишем НАПРЯМУЮ после PATCH.
                model = "deepseek-v4-flash"
            }
            Write-Host "  Crystallization: deepseek (llm + l3Llm + skillEvolver, model=deepseek-v4-flash)"
        } else {
            # Локальную llama при установке НЕ настраиваем: конфиг Hermes ещё пуст
            # (или пользователь не выбрал локальную LLM). Параметры LLM (llm/l3Llm/skillEvolver)
            # пропишет Start-Llama-IfNeeded.bat при первом запуске Hermes (через sync-memos-llm.ps1).
            Write-Host "  LLM parameters will be configured on first Hermes launch (Start-Llama-IfNeeded.bat)."
        }
        if ($cryLlm) {
            $patch.llm = $cryLlm
            $patch.l3Llm = $cryLlm
            $patch.skillEvolver = $cryLlm
        } elseif ($llmProvider -ne "local_only") {
            $patch.llm = @{ provider = "local_only" }
        }
        # fallbackToHost=false: кристаллизация НЕ падает в fallback на host-LLM (локальную kobold!)
        # (иначе local_only всё равно мучает локальную LLM через Hermes-bridge - проверено 12.08)
        $patch.llm.fallbackToHost = $false
        # lightweight: при кристаллизации (deepseek ИЛИ llama) ОБЯЗАТЕЛЬНО false (иначе pipeline
        # скипает L2/L3/skills и кристаллизация не работает); при автономном local_only - true
        $lw = $cfg.config.algorithm.lightweightMemory.enabled
        $lwTarget = if ($cryLlm) { $false } else { $true }
        if ($lw -ne $lwTarget) {
            if (-not $patch.algorithm) { $patch.algorithm = @{} }
            $patch.algorithm.lightweightMemory = @{ enabled = $lwTarget }
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
        # Тюнинг кристаллизации (для ЛЮБОЙ LLM - deepseek ИЛИ локальная llama):
        #   maxTokens: reasoning-модели (Qwen/deepseek) съедают дефолтные 1024 токенов
        #     на думание -> пустой content -> "empty response" (L2/skills/L3 падали);
        #   timeoutMs=180000: длинные batch-рефлексии рвутся на дефолтных 45-60с.
        #   ВАЖНО (MemOS 2.0.15): l3Llm-клиент создаётся БЕЗ maxTokens из конфига
        #     (всегда 1024) -> L3-абстракция обрывается на думании. Поэтому L3 гоняем
        #     через ОСНОВНОЙ llm-клиент: l3Llm.model/provider="" (клиент не создаётся,
        #     штатный fallback на llm) и llm.maxTokens=65536 (Qwen думает 20-60k токенов
        #     на world model; замер 14.08: 19.5k на 3 политики, обрывы до 121с).
        foreach ($sec in @("llm", "skillEvolver")) {
            if (-not $patch.$sec) { $patch.$sec = @{} }
            if ($sec -eq "llm") { $patch.$sec.maxTokens = 65536 } else { $patch.$sec.maxTokens = 8192 }
            $patch.$sec.timeoutMs = 180000
        }
        if (-not $patch.l3Llm) { $patch.l3Llm = @{} }
        $patch.l3Llm.model = ""
        $patch.l3Llm.provider = ""
        $patch.l3Llm.timeoutMs = 600000
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
            $raw = [regex]::Replace($raw, '(apiKey:\s*)(?:\*{3}|"")', ('${1}"' + $dsKey + '"'))
            Set-Content -Path $cfgPath -Value $raw -Encoding UTF8 -NoNewline
            Write-Host "  apiKey: written directly (bypass writer masking)"
            $fixed += "apikey"
        } elseif (-not $useDeepSeek) {
            # Режим без deepseek (llama-server / local_only): writer после PATCH может
            # замаскировать apiKey в голый '***' - невалидный YAML - чистим в "".
            $cfgPath = Join-Path $RuntimeHome "config.yaml"
            $raw = Get-Content -Path $cfgPath -Raw -Encoding UTF8
            if ($raw -match 'apiKey:\s*\*{3}') {
                $raw = [regex]::Replace($raw, 'apiKey:\s*\*{3}', 'apiKey: ""')
                Set-Content -Path $cfgPath -Value $raw -Encoding UTF8 -NoNewline
                Write-Host "  apiKey: masked '***' cleared (no deepseek)"
            }
        }
        # ВАЛИДАЦИЯ YAML после любых правок (минное поле!): python + pyyaml (venv Hermes - js-yaml в node_modules плагина нет)
        & $PythonExe -c "import yaml,sys; yaml.safe_load(open(sys.argv[1],encoding='utf-8'))" (Join-Path $RuntimeHome "config.yaml")
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  config.yaml: YAML valid"
        } else {
            Write-Host "  ERROR: config.yaml INVALID after fix - restoring backup!"
            Copy-Item -Path (Join-Path $RuntimeHome "config.yaml.bak") -Destination (Join-Path $RuntimeHome "config.yaml") -Force
        }
        }   # end if ($memActive) - crystallization block
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

# --- 4. Активация в Hermes: provider + плагин + память ---
if (-not $memActive) {
    Write-Host "[4/7] MemOS disabled in Hermes (memory.provider not set) - skipping activation."
    Write-Host "      Enable with: hermes config set memory.provider memtensor"
} else {
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
        & $HermesExe plugins enable memtensor --no-allow-tool-override | Out-Null
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
}   # end if ($memActive) - activation block

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
# viewer daemon оставляем работать (не убиваем): при старте Hermes-сессии
# ensure_viewer_daemon увидит :18800 занятым MemOS и не запустит второй.

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
