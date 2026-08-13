# scripts\ps1\install_rg.ps1
# Установка ripgrep (rg.exe) в портабельный каталог HERMES_HOME\bin
# Приоритет: глобальный rg из реестрового PATH (Machine+User) -> копирование в bin;
# если глобального нет или он невалиден - скачивание с GitHub (fallback).
param(
    [string]$HermesHome = $env:HERMES_HOME
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = "Tls12"

$binDir = "$HermesHome\bin"
$target = "$binDir\rg.exe"
if (Test-Path $target) {
    Write-Host "  +   ripgrep already installed: $target" -ForegroundColor Green
    exit 0
}

# Поиск глобального бинарника в реестровом PATH (Machine+User).
# НЕ используем $env:Path: в сессиях Hermes там первым идёт домашний bin
# (C:\NEURO\Hermes\data\hermes\bin) - нам нужны только ВНЕШНИЕ установки.
function Find-GlobalTool([string]$ExeName) {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    $dirs = @()
    foreach ($p in @($machinePath, $userPath)) {
        if (-not $p) { continue }
        $dirs += $p -split ";" | Where-Object { $_ -and (Test-Path $_) }
    }
    foreach ($d in ($dirs | Select-Object -Unique)) {
        # Исключаем каталоги Hermes (дом/полигон) - берём только внешние установки
        if ($d -like "*hermes*" -or $d -like "*$HermesHome*") { continue }
        $candidate = Join-Path $d $ExeName
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

# --- Копирование глобального rg (экономия трафика, свежая версия) ---
$globalRg = Find-GlobalTool "rg.exe"
if ($globalRg) {
    Write-Host "    Found global ripgrep: $globalRg" -ForegroundColor Gray
    # Валидируем ИСТОЧНИК: запускается ли он вообще
    $srcOk = $false
    try { & $globalRg --version *> $null; if ($LASTEXITCODE -eq 0) { $srcOk = $true } } catch { $srcOk = $false }
    if ($srcOk) {
        if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Force -Path $binDir | Out-Null }
        Copy-Item $globalRg -Destination $target -Force
        # Валидируем КОПИЮ: битая копия (несовместимость, повреждение) -> fallback на скачивание
        $copyOk = $false
        try { & $target --version *> $null; if ($LASTEXITCODE -eq 0) { $copyOk = $true } } catch { $copyOk = $false }
        if ($copyOk) {
            Write-Host "  +   ripgrep copied from global: $target" -ForegroundColor Green
            exit 0
        }
        Write-Host "  .   copied rg.exe failed validation, removing and falling back to download..." -ForegroundColor Yellow
        Remove-Item $target -Force -ErrorAction SilentlyContinue
    } else {
        Write-Host "  .   global rg.exe failed validation, falling back to download..." -ForegroundColor Yellow
    }
}

# --- Fallback: скачивание с GitHub ---
$url = "https://github.com/BurntSushi/ripgrep/releases/download/15.1.0/ripgrep-15.1.0-x86_64-pc-windows-msvc.zip"
$zip = "$env:TEMP\rg.zip"

Write-Host "    Downloading ripgrep 15.1.0..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
    $entry = $z.Entries | Where-Object { $_.Name -eq "rg.exe" } | Select-Object -First 1
    if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Force -Path $binDir | Out-Null }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
    $z.Dispose()
    Remove-Item $zip -Force
    Write-Host "  +   ripgrep installed: $target" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "  .   ripgrep install failed: $_" -ForegroundColor Yellow
    if (Test-Path $zip) { Remove-Item $zip -Force }
    exit 1
}
