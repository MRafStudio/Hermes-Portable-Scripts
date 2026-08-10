# memos-fix.ps1 - FALLBACK: доводит установку MemOS до идеала (самодостаточный фиксер)
# Не является частью установщика: запускается ПОСЛЕ install-memos.ps1 (или отдельно),
# проверяет каждый критичный узел и чинит недостающее:
#   1. native bindings (better-sqlite3) - approve-scripts + npm rebuild + повторная проверка
#   2. config.yaml - endpoint kobold :5101, telemetry OFF
#   3. MEMOS_HOME в Start.bat (портабельный runtime home - БД не уходит в %LOCALAPPDATA%)
#   4. memory.provider = memtensor (hermes config set)
#   5. junction plugins\memtensor
#   6. тестовый запуск bridge -> БД в <MEMOS_HOME>\data\memos.db + viewer :18800 health
# Использование:  powershell -ExecutionPolicy Bypass -File memos-fix.ps1 -RootDir <root>
param(
    [string]$RootDir = ""
)

$ErrorActionPreference = "Stop"

if (-not $RootDir) { $RootDir = Split-Path -Parent $PSScriptRoot | Split-Path -Parent }
$HermesHome   = Join-Path $RootDir "data\hermes"
$RuntimeHome  = Join-Path $HermesHome "memos-plugin"
$PluginDir    = Join-Path $HermesHome "plugins\memtensor"
$AdapterDir   = Join-Path $RuntimeHome "adapters\hermes\memos_provider"
$HermesExe    = Join-Path $HermesHome "hermes-agent\venv\Scripts\hermes.exe"
$StartBat     = Join-Path $RootDir "Start.bat"
$NodeBin      = (Get-Command node -ErrorAction SilentlyContinue)
$NativePkgs   = @("better-sqlite3", "onnxruntime-node", "sharp", "protobufjs", "esbuild")

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

# --- 1. native bindings (better-sqlite3) ---
$dbTestExpr = "const D=require('better-sqlite3');const db=new D(':memory:');db.exec('CREATE TABLE t(x)');db.close();console.log('OK')"
Push-Location $RuntimeHome
try {
    $dbTest = & $NodeBin.Source -e $dbTestExpr 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[1/6] better-sqlite3 bindings: OK"
    } else {
        Write-Host "[1/6] bindings missing - approve-scripts + npm rebuild ..."
        & $NodeBin.Source (Join-Path (Split-Path -Parent $NodeBin.Source) "..\node_modules\npm\bin\npm-cli.js") approve-scripts --allow-scripts-pending 2>&1 | Out-Null
        $code = Invoke-Npm (@("rebuild", "--no-audit", "--no-fund") + $NativePkgs)
        $dbTest = & $NodeBin.Source -e $dbTestExpr 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[1/6] bindings fixed via approve-scripts + rebuild"
            $fixed += "bindings"
        } else {
            Write-Host "ERROR: better-sqlite3 still broken after rebuild - check network to github.com (prebuilds)."
            Pop-Location
            exit 1
        }
    }
} finally {
    Pop-Location
}

# --- 2. config.yaml: endpoint kobold :5101 + telemetry OFF ---
$pluginCfg = Join-Path $RuntimeHome "config.yaml"
$cfgChanged = $false
if (Test-Path $pluginCfg) {
    $cfg = Get-Content $pluginCfg -Raw
    if ($cfg -notmatch "endpoint: http://127\.0\.0\.1:5101/v1") {
        $cfg = $cfg -replace "endpoint: http://127\.0\.0\.1:\d+/v1", "endpoint: http://127.0.0.1:5101/v1"
        $cfgChanged = $true
    }
    if ($cfg -match "telemetry:\r?\n\s+enabled: true") {
        $cfg = $cfg -replace "telemetry:\r?\n\s+enabled: true", "telemetry:`n  enabled: false"
        $cfgChanged = $true
    }
    if ($cfgChanged) {
        [System.IO.File]::WriteAllText($pluginCfg, $cfg, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[2/6] config.yaml fixed (endpoint :5101, telemetry OFF)"
        $fixed += "config"
    } else {
        Write-Host "[2/6] config.yaml: OK (kobold :5101, telemetry OFF)"
    }
} else {
    Write-Host "WARNING: config.yaml missing - will be created by the bridge on first run (check endpoint after)."
}

# --- 3. MEMOS_HOME в Start.bat ---
if (Test-Path $StartBat) {
    $start = Get-Content $StartBat -Raw
    if ($start -notmatch "MEMOS_HOME") {
        $start = $start -replace 'set "HERMES_HOME=.*?\r?\n', "`$0set `"MEMOS_HOME=%HERMES_HOME%\memos-plugin`"`r`n"
        [System.IO.File]::WriteAllText($StartBat, $start, (New-Object System.Text.UTF8Encoding $false))
        Write-Host "[3/6] MEMOS_HOME added to Start.bat"
        $fixed += "MEMOS_HOME"
    } else {
        Write-Host "[3/6] MEMOS_HOME in Start.bat: OK"
    }
} else {
    Write-Host "WARNING: Start.bat not found at $StartBat"
}

# --- 4. memory.provider = memtensor ---
if (Test-Path $HermesExe) {
    $check = & $HermesExe config get memory.provider 2>$null
    if ($check -match "memtensor") {
        Write-Host "[4/6] memory.provider: OK (memtensor)"
    } else {
        & $HermesExe config set memory.provider memtensor | Out-Null
        Write-Host "[4/6] memory.provider set to memtensor"
        $fixed += "provider"
    }
} else {
    Write-Host "WARNING: hermes.exe not found - set memory.provider manually."
}

# --- 5. junction plugins\memtensor ---
if (-not (Test-Path (Join-Path $PluginDir "__init__.py"))) {
    if (Test-Path $PluginDir) { Remove-Item -LiteralPath $PluginDir -Force -Recurse -ErrorAction SilentlyContinue }
    New-Item -ItemType Junction -Path $PluginDir -Value $AdapterDir | Out-Null
    Write-Host "[5/6] junction recreated: $PluginDir"
    $fixed += "junction"
} else {
    Write-Host "[5/6] junction: OK"
}

# --- 6. тестовый запуск bridge -> БД + viewer health ---
$dataDir = Join-Path $RuntimeHome "data"
if (-not (Test-Path $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
$viewer = Start-Process -FilePath $NodeBin.Source `
    -ArgumentList @("dist\bridge.mjs", "--agent=hermes", "--home=$RuntimeHome", "--daemon") `
    -WorkingDirectory $RuntimeHome -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 15
$dbFile = Join-Path $dataDir "memos.db"
if (Test-Path $dbFile) {
    Write-Host "[6/6] MemOS DB OK: $dbFile"
} else {
    Write-Host "WARNING: DB not created yet - it will appear on the first Hermes session."
}
try {
    $resp = Invoke-WebRequest -Uri "http://127.0.0.1:18800/" -UseBasicParsing -TimeoutSec 5
    Write-Host "[6/6] viewer :18800 HTTP $($resp.StatusCode)"
} catch {
    Write-Host "[6/6] viewer health check failed - it will start with the next Hermes session"
}
Stop-Process -Id $viewer.Id -Force -ErrorAction SilentlyContinue

Write-Host ""
if ($fixed.Count -gt 0) {
    Write-Host "MemOS FIXED: $($fixed -join ', ')"
} else {
    Write-Host "MemOS FIX: everything is already OK"
}
exit 0
