# sync-memos-llm.ps1 - синхронизация активной LLM Hermes в конфиг MemOS (llm/l3Llm/skillEvolver).
# Единая функция настройки кристаллизации памяти под ТЕКУЩУЮ модель Hermes (источник истины =
# конфиг Hermes: model.provider / model.default / model.base_url). Вызывается из
# Start-Llama-IfNeeded.bat ПОСЛЕ синхронизации конфига Hermes (сценарии А и Б2).
#   provider=llama      -> openai_compatible(endpoint=model.base_url, model=model.default)
#   provider=<external> -> openai_compatible(endpoint=providers.<p>.base_url, model, apiKey напрямую)
#   provider=<пусто>    -> ничего не настраиваем (тихий выход)
# daemon :18800 останавливается перед изменением настроек и поднимается заново (читает свежий config.yaml).
param(
    [string]$RootDir = ""
)

$ErrorActionPreference = "Continue"

if (-not $RootDir) { $RootDir = Split-Path -Parent $PSScriptRoot | Split-Path -Parent }
$HermesHome  = Join-Path $RootDir "data\hermes"
$RuntimeHome = Join-Path $HermesHome "memos-plugin"
$HermesExe   = Join-Path $HermesHome "hermes-agent\venv\Scripts\hermes.exe"
# HERMES_HOME + MEMOS_HOME принудительно (портабельно: hermes.exe иначе читает чужой конфиг/home).
$env:HERMES_HOME = $HermesHome
$env:MEMOS_HOME = $RuntimeHome
$env:MEMOS_CONFIG_FILE = ""

function Test-MemosDaemon {
    try {
        $resp = Invoke-WebRequest -Uri "http://127.0.0.1:18800/api/v1/health" -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        return ($resp.StatusCode -eq 200)
    } catch { return $false }
}

function Stop-MemosDaemon {
    # остановка bridge-процессов ЭТОГО RuntimeHome (node.exe с --home=$RuntimeHome)
    try {
        $nodeProcs = Get-CimInstance Win32_Process -Filter "Name='node.exe'" -ErrorAction SilentlyContinue
        foreach ($p in @($nodeProcs)) {
            if ($p.CommandLine -and $p.CommandLine -like "*$RuntimeHome*") {
                Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
    } catch { }
    Start-Sleep -Seconds 2
}

function Start-MemosDaemon {
    $nodeBin = Get-Command node -ErrorAction SilentlyContinue
    if (-not $nodeBin) { Write-Host "WARNING: node not found - cannot start MemOS daemon."; return $false }
    $daemonLogOut = Join-Path $RuntimeHome "logs\sync-daemon.out.log"
    $daemonLogErr = Join-Path $RuntimeHome "logs\sync-daemon.err.log"
    try {
        $null = Start-Process -FilePath $nodeBin.Source `
            -ArgumentList @("dist\bridge.mjs", "--agent=hermes", "--home=$RuntimeHome", "--daemon") `
            -WorkingDirectory $RuntimeHome -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $daemonLogOut -RedirectStandardError $daemonLogErr
    } catch {
        Write-Host "WARNING: MemOS daemon start failed: $($_.Exception.Message)"
        return $false
    }
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-MemosDaemon) { return $true }
    }
    return $false
}

function Set-MemosApiKey([string]$Key) {
    # apiKey ПИШЕМ НАПРЯМУЮ в config.yaml (writer маскирует его в '***' - невалидный YAML 2.0.15),
    # пока daemon ОСТАНОВЛЕН - иначе тот держит конфиг в памяти и перезапишет файл.
    $cfgPath = Join-Path $RuntimeHome "config.yaml"
    if (-not (Test-Path $cfgPath)) { return }
    $raw = Get-Content -Path $cfgPath -Raw -Encoding UTF8
                foreach ($secKey in @("llm", "skillEvolver", "l3Llm")) {
                $raw = [regex]::Replace($raw, ('(?s)(' + $secKey + ':.*?apiKey:\s*)([^\r\n]*)'), ('${1}"' + $Key + '"'))
            }
    [System.IO.File]::WriteAllText($cfgPath, $raw, (New-Object System.Text.UTF8Encoding $false))
}

# --- 1. MemOS включена? ---
if (-not (Test-Path $HermesExe)) { exit 0 }
$memProvider = (& $HermesExe config get memory.provider 2>$null | Out-String).Trim()
if ($memProvider -ne "memtensor") { exit 0 }

# --- 2. Источник истины: активная LLM Hermes ---
$modelProvider = (& $HermesExe config get model.provider 2>$null | Out-String).Trim()
$modelDefault  = (& $HermesExe config get model.default 2>$null | Out-String).Trim()
$modelBaseUrl  = (& $HermesExe config get model.base_url 2>$null | Out-String).Trim()

$cry = $null
$extKey = ""
if ($modelProvider -eq "llama" -and $modelBaseUrl -ne "") {
    $cry = @{ provider = "openai_compatible"; endpoint = $modelBaseUrl; model = $modelDefault; fallbackToHost = $false }
} elseif ($modelProvider -ne "" -and $modelProvider -ne "llama") {
    # внешний провайдер (deepseek/openai/...): endpoint + apiKey из providers.<name>
    $ep = (& $HermesExe config get "providers.$modelProvider.base_url" 2>$null | Out-String).Trim()
    $extKey = (& $HermesExe config get "providers.$modelProvider.api_key" 2>$null | Out-String).Trim()
    if ($ep -eq "") {
        switch ($modelProvider.ToLower()) {
            "deepseek" { $ep = "https://api.deepseek.com/v1" }
            "openai"   { $ep = "https://api.openai.com/v1" }
            default    { $ep = "" }
        }
    }
    if ($ep -ne "") {
        $cry = @{ provider = "openai_compatible"; endpoint = $ep; model = "deepseek-chat"; fallbackToHost = $false }
    }
}
if ($null -eq $cry) {
    Write-Host "MemOS sync: no active LLM to configure - skip."
    exit 0
}

# --- 3. Текущее состояние daemon ---
$daemonAlive = Test-MemosDaemon

# --- 4. Уже на целевой конфигурации? (endpoint + model + provider совпадают) ---
if ($daemonAlive) {
    try {
        $cur = Invoke-RestMethod -Uri "http://127.0.0.1:18800/api/v1/config" -Method Get -TimeoutSec 10
        if ($cur -and
            "$($cur.llm.provider)" -eq "$($cry.provider)" -and
            "$($cur.llm.endpoint)" -eq "$($cry.endpoint)" -and
            "$($cur.llm.model)" -eq "$($cry.model)") {
            Write-Host "MemOS sync: already on $($cry.endpoint) / $($cry.model) - no change."
            exit 0
        }
    } catch { }
}

# --- 5. Остановить daemon перед изменением настроек ---
if ($daemonAlive) {
    Write-Host "MemOS sync: stopping daemon before config change..."
    Stop-MemosDaemon
}

# --- 6. apiKey напрямую (только внешний провайдер), пока daemon остановлен ---
if ($extKey -ne "") { Set-MemosApiKey $extKey }

# --- 7. Поднять daemon (прочитает свежий config.yaml) ---
if (-not (Test-MemosDaemon)) {
    if (-not (Start-MemosDaemon)) {
        Write-Host "WARNING: MemOS daemon did not start - LLM sync skipped (config will apply next session)."
        exit 0
    }
}

# --- 8. PATCH llm/skillEvolver (БЕЗ apiKey - writer маскирует его) ---
# l3Llm сознательно НЕ синхронизируем: в MemOS 2.0.15 l3Llm-клиент создаётся
# без maxTokens (всегда 1024) и L3 падает; fix держит l3Llm.model="" -
# L3-абстракция идёт через ОСНОВНОЙ llm (maxTokens=65536).
try {
    $patch = @{}
    $patch.llm = $cry
    $patch.skillEvolver = $cry
    $patch.algorithm = @{ lightweightMemory = @{ enabled = $false } }
    $body = $patch | ConvertTo-Json -Depth 6 -Compress
    Invoke-RestMethod -Uri "http://127.0.0.1:18800/api/v1/config" -Method Patch -Body $body -ContentType "application/json" -TimeoutSec 10 | Out-Null
    Write-Host "MemOS sync: crystallization -> $($cry.endpoint) / $($cry.model) (llm + l3Llm + skillEvolver)"
} catch {
    Write-Host "WARNING: MemOS config PATCH failed: $($_.Exception.Message)"
}
