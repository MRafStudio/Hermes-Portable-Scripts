# memos-fix.ps1 - FALLBACK: доводит установку MemOS до идеала (самодостаточный фиксер)
# Не является частью установщика: запускается ПОСЛЕ install-memos.ps1 (или отдельно).
# Правило: скрипты вендора НЕ трогаем - проверяем недостающее и ДОУСТАНАВЛИВАЕМ.
#  1. native bindings (better-sqlite3) - approve-scripts (поштучно!) + npm rebuild
#  2. config.yaml - через ШТАТНЫЙ API bridge (GET/PATCH /api/v1/config):
#     endpoint kobold :5101, lightweightMemory=false, llmFilterEnabled=false,
#     embedding.model -> локальная модель (не HF из РФ!)
#  3. MEMOS_HOME в Start.bat (портабельный runtime home)
#  4. memory.provider = memtensor (hermes config set)
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
$HfExe        = Join-Path $HermesHome "hermes-agent\venv\Scripts\hf.exe"
$StartBat     = Join-Path $RootDir "Start.bat"
$NodeBin      = (Get-Command node -ErrorAction SilentlyContinue)
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
    & $NodeBin.Source (Join-Path (Split-Path -Parent $NodeBin.Source) "..\node_modules\npm\bin\npm-cli.js") @NpmArgs 2>&1 | Out-Null
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return $code
}

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
        & $NodeBin.Source (Join-Path (Split-Path -Parent $NodeBin.Source) "..\node_modules\npm\bin\npm-cli.js") approve-scripts $NativePkgs 2>&1 | Out-Null
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
if (Test-Path $embedModelOnnx) {
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
    if (-not (Test-Path $embedModelOnnx) -and (Test-Path $HfExe)) {
        & $HfExe download Xenova/all-MiniLM-L6-v2 --local-dir $EmbedModelDir 2>&1 | Out-Null
    }
    if (Test-Path $embedModelOnnx) {
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
        $endpoint = $cfg.config.llm.endpoint
        if ($endpoint -notmatch "127\.0\.0\.1:5101") {
            $patch.llm = @{ endpoint = "http://127.0.0.1:5101/v1" }
        }
        $lw = $cfg.config.algorithm.lightweightMemory.enabled
        if ($lw -ne $false) {
            if (-not $patch.algorithm) { $patch.algorithm = @{} }
            $patch.algorithm.lightweightMemory = @{ enabled = $false }
        }
        $lf = $cfg.config.retrieval.llmFilterEnabled
        if ($lf -ne $false) {
            if (-not $patch.retrieval) { $patch.retrieval = @{} }
            $patch.retrieval.llmFilterEnabled = $false
        }
        $emb = $cfg.config.embedding.model
        if ($emb -notmatch "all-MiniLM-L6-v2") {
            if (-not $patch.embedding) { $patch.embedding = @{} }
            $patch.embedding.model = $EmbedModelDir
        }
        if ($patch.Count -gt 0) {
            $body = $patch | ConvertTo-Json -Depth 6 -Compress
            try {
                Invoke-RestMethod -Uri "http://127.0.0.1:18800/api/v1/config" -Method Patch -Body $body -ContentType "application/json" -TimeoutSec 10 | Out-Null
                Write-Host "[2/7] config.yaml fixed via API (PATCH /api/v1/config): $($patch.Keys -join ', ')"
                $fixed += "config"
            } catch {
                Write-Host "WARNING: config PATCH failed: $($_.Exception.Message)"
            }
        } else {
            Write-Host "[2/7] config.yaml: OK (kobold :5101, lightweight OFF, llmFilter OFF, local embedder)"
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
} catch {
    Write-Host "[7/7] viewer health check failed - it will start with the next Hermes session"
}
if ($testBridge -and -not $testBridge.HasExited) { Stop-Process -Id $testBridge.Id -Force -ErrorAction SilentlyContinue }

Write-Host ""
if ($fixed.Count -gt 0) {
    Write-Host "MemOS FIXED: $($fixed -join ', ')"
} else {
    Write-Host "MemOS FIX: everything is already OK"
}
exit 0
