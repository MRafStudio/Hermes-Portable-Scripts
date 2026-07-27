# scripts\patch\install_rg.ps1
# Установка ripgrep (rg.exe) в портабельный каталог HERMES_HOME\bin
param(
    [string]$HermesHome = $env:HERMES_HOME
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = "Tls12"

$target = "$HermesHome\bin\rg.exe"
if (Test-Path $target) {
    Write-Host "  +   ripgrep already installed: $target" -ForegroundColor Green
    exit 0
}

$url = "https://github.com/BurntSushi/ripgrep/releases/download/14.1.1/ripgrep-14.1.1-x86_64-pc-windows-msvc.zip"
$zip = "$env:TEMP\rg.zip"

Write-Host "    Downloading ripgrep 14.1.1..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
    $entry = $z.Entries | Where-Object { $_.Name -eq "rg.exe" } | Select-Object -First 1
    if (-not (Test-Path "$HermesHome\bin")) { New-Item -ItemType Directory -Force -Path "$HermesHome\bin" | Out-Null }
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
