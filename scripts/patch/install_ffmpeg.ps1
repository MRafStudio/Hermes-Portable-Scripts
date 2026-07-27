# scripts\patch\install_ffmpeg.ps1
# Установка ffmpeg.exe в портабельный каталог HERMES_HOME\bin
param(
    [string]$HermesHome = $env:HERMES_HOME
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = "Tls12"

$target = "$HermesHome\bin\ffmpeg.exe"
if (Test-Path $target) {
    Write-Host "  +   ffmpeg already installed: $target" -ForegroundColor Green
    exit 0
}

$url = "https://www.gyan.dev/ffmpeg/builds/packages/ffmpeg-7.1-essentials_build.zip"
$zip = "$env:TEMP\ffmpeg.zip"

Write-Host "    Downloading ffmpeg 7.1..." -ForegroundColor Gray
try {
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
    $entry = $z.Entries | Where-Object { $_.Name -eq "ffmpeg.exe" } | Select-Object -First 1
    if (-not (Test-Path "$HermesHome\bin")) { New-Item -ItemType Directory -Force -Path "$HermesHome\bin" | Out-Null }
    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
    $z.Dispose()
    Remove-Item $zip -Force
    Write-Host "  +   ffmpeg installed: $target" -ForegroundColor Green
    exit 0
} catch {
    Write-Host "  .   ffmpeg install failed: $_" -ForegroundColor Yellow
    if (Test-Path $zip) { Remove-Item $zip -Force }
    exit 1
}
