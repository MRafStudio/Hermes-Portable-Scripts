# uninstall-memos.ps1 — полное удаление MemOS из Hermes Portable (безвозвратно).
# ============================================================================
# Что делает:
#   1. Останавливает bridge-процессы MemOS (только этого RuntimeHome!)
#   2. hermes plugins disable memtensor
#   3. hermes config unset memory.provider (если = memtensor)
#   4. Удаляет junction plugins\memtensor
#   5. Удаляет RuntimeHome целиком: БД памяти, config.yaml, модели — БЕЗВОЗВРАТНО
# Бэкапы не делаются: тема хранения бэкапов пока не решена (открытый вопрос).
# ============================================================================
param(
    [Parameter(Mandatory = $true)]
    [string]$RootDir
)

$ErrorActionPreference = "Stop"

$HermesHome   = Join-Path $RootDir "data\hermes"
$RuntimeHome  = Join-Path $HermesHome "memos-plugin"
$PluginDir    = Join-Path $HermesHome "plugins\memtensor"
$HermesExe    = Join-Path $HermesHome "hermes-agent\venv\Scripts\hermes.exe"

# MEMOS_HOME принудительно = RuntimeHome (resolveHome отдаёт приоритет env перед
# --home - иначе bridge-процессы и hermes-плагин могут открыть чужой home).
$env:MEMOS_HOME = $RuntimeHome
$env:MEMOS_CONFIG_FILE = ""

Write-Host "== MemOS uninstaller =="
Write-Host "Root      : $RootDir"
Write-Host "Runtime   : $RuntimeHome"

# --- 1. Остановить bridge-процессы этого RuntimeHome (иначе файлы залочены) ---
Write-Host "Stopping MemOS bridge processes (this runtime only)..."
$stopped = 0
try {
    $nodeProcs = Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue
    foreach ($p in @($nodeProcs)) {
        if ($p.CommandLine -and $p.CommandLine -like "*$RuntimeHome*") {
            Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
            Write-Host "  stopped PID $($p.ProcessId)"
            $stopped++
        }
    }
} catch { }
Start-Sleep -Seconds 2

# --- 2. Плагин memtensor: disable (штатно через hermes) ---
if (Test-Path $HermesExe) {
    try {
        $pluginStatus = & $HermesExe plugins list --json 2>$null | ConvertFrom-Json
        $mt = @($pluginStatus | Where-Object { $_.name -eq "memtensor" } | Select-Object -First 1)
        if ($mt.Count -gt 0 -and $mt[0].status -eq "enabled") {
            & $HermesExe plugins disable memtensor | Out-Null
            Write-Host "Plugin memtensor: disabled"
        } else {
            Write-Host "Plugin memtensor: not enabled (nothing to disable)"
        }
    } catch {
        Write-Host "WARNING: plugins disable failed: $($_.Exception.Message)"
    }
} else {
    Write-Host "WARNING: hermes.exe not found - disable memtensor manually."
}

# --- 3. memory.provider: сброс (если = memtensor) ---
if (Test-Path $HermesExe) {
    $provider = & $HermesExe config get memory.provider 2>$null
    if ($provider -match "memtensor") {
        & $HermesExe config unset memory.provider | Out-Null
        Write-Host "memory.provider: unset (memtensor removed)"
    } else {
        Write-Host "memory.provider: not memtensor (nothing to unset)"
    }
}

# --- 4. Junction plugins\memtensor ---
if (Test-Path $PluginDir) {
    Remove-Item -LiteralPath $PluginDir -Force -Recurse -ErrorAction SilentlyContinue
    Write-Host "Junction removed: $PluginDir"
} else {
    Write-Host "Junction not found: $PluginDir"
}

# --- 5. RuntimeHome: БД, конфиг, модели — БЕЗВОЗВРАТНО ---
if (Test-Path $RuntimeHome) {
    try {
        Remove-Item -LiteralPath $RuntimeHome -Force -Recurse -ErrorAction Stop
        Write-Host "Runtime removed: $RuntimeHome"
    } catch {
        Write-Host "ERROR: cannot remove $RuntimeHome - files may be locked by a running Hermes session."
        Write-Host "       Close Hermes completely, then run uninstall again."
        exit 1
    }
} else {
    Write-Host "Runtime not found: $RuntimeHome"
}

# --- 6. Проверка ---
$leftovers = @()
if (Test-Path $PluginDir) { $leftovers += "plugin dir" }
if (Test-Path $RuntimeHome) { $leftovers += "runtime" }
if ($leftovers.Count -eq 0) {
    Write-Host ""
    Write-Host "MemOS uninstalled. Hermes detached (plugin disabled, memory.provider cleared)."
    if ($stopped -gt 0) { Write-Host "Bridge processes stopped: $stopped" }
} else {
    Write-Host "WARNING: leftovers: $($leftovers -join ', ')"
    exit 1
}
