# \scripts\patch\hermes_install_portable.ps1
# Hermes Portable — Wrapper для install.ps1
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

# Обновляем PATH для текущего процесса
$env:Path = "$HermesHome\node;$HermesHome\bin;C:\Program Files\Git\cmd;" + $env:Path

# КРИТИЧНО: Явно экспортируем PATH для дочерних процессов
[Environment]::SetEnvironmentVariable("Path", $env:Path, "Process")

# Скачиваем install.ps1
Write-Host "Downloading install.ps1..." -ForegroundColor Cyan
$installScript = Invoke-RestMethod -Uri "https://hermes-agent.nousresearch.com/install.ps1" -UseBasicParsing

Write-Host "Running install.ps1 with portable paths..." -ForegroundColor Cyan
Write-Host "  HERMES_HOME: $HermesHome" -ForegroundColor Gray
Write-Host "  InstallDir:  $InstallDir" -ForegroundColor Gray
Write-Host "  IncludeDesktop: $IncludeDesktop" -ForegroundColor Gray

# Выполняем скрипт с параметрами
$scriptBlock = [ScriptBlock]::Create($installScript)

if ($IncludeDesktop) {
    & $scriptBlock -HermesHome $HermesHome -InstallDir $InstallDir -IncludeDesktop -NonInteractive
} else {
    & $scriptBlock -HermesHome $HermesHome -InstallDir $InstallDir -NonInteractive
}