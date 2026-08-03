# scripts\patch\install_ffmpeg.ps1
# Установка ffmpeg.exe в портабельный каталог HERMES_HOME\bin.
# Надёжная цепочка скачивания (как NSSM): git-curl -> bitsadmin -> certutil -> PS TLS12.
# Зеркала: BtbN gpl -> BtbN lgpl -> gyan.dev essentials.
param(
    [string]$HermesHome = $env:HERMES_HOME
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$binDir = "$HermesHome\bin"
$target = "$binDir\ffmpeg.exe"
if (Test-Path $target) {
    Write-Host "  +   ffmpeg already installed: $target" -ForegroundColor Green
    exit 0
}

if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Force -Path $binDir | Out-Null }

# Зеркала: 1) BtbN gpl (большой, полный) 2) BtbN lgpl 3) gyan.dev essentials (меньше)
$mirrors = @(
    "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip",
    "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-lgpl.zip"
)

$zip = "$env:TEMP\ffmpeg.zip"

# Ищем git-curl (mingw64) — на Win10 1607 системного curl нет
$curlCandidates = @(
    "$env:ProgramFiles\Git\mingw64\bin\curl.exe",
    "${env:ProgramFiles(x86)}\Git\mingw64\bin\curl.exe",
    "$env:LOCALAPPDATA\Programs\Git\mingw64\bin\curl.exe"
)
$gitCurl = $curlCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

function Download-With($url, $out) {
    # 1) git-curl (самый надёжный: TLS + редиректы)
    if ($gitCurl) {
        & $gitCurl -L --fail -C - --retry 5 --retry-all-errors --retry-delay 2 --connect-timeout 30 --max-time 900 -o $out $url
        if ($LASTEXITCODE -eq 0 -and (Test-Path $out) -and ((Get-Item $out).Length -gt 10000000)) { return $true }
        if (Test-Path $out) { Remove-Item $out -Force }
    }
    # 2) bitsadmin (системный, не требует прав)
    $bits = "$env:windir\System32\bitsadmin.exe"
    if (Test-Path $bits) {
        & $bits /transfer /download /priority normal $url $out
        if ((Test-Path $out) -and ((Get-Item $out).Length -gt 10000000)) { return $true }
        if (Test-Path $out) { Remove-Item $out -Force }
    }
    # 3) certutil (системный)
    $certutil = "$env:windir\System32\certutil.exe"
    if (Test-Path $certutil) {
        & $certutil -urlcache -split -f $url $out
        if ((Test-Path $out) -and ((Get-Item $out).Length -gt 10000000)) { return $true }
        if (Test-Path $out) { Remove-Item $out -Force }
    }
    # 4) PowerShell Invoke-WebRequest (TLS12 уже включён)
    try {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 900
        if ((Test-Path $out) -and ((Get-Item $out).Length -gt 10000000)) { return $true }
        if (Test-Path $out) { Remove-Item $out -Force }
    } catch { }
    return $false
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$ok = $false
foreach ($url in $mirrors) {
    Write-Host "    Downloading ffmpeg: $url" -ForegroundColor Gray
    if (Download-With $url $zip) {
        try {
            $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
            try {
                # Извлекаем ffmpeg.exe (BtbN-сборка — статическая, DLL не нужны)
                $entry = $z.Entries | Where-Object { $_.Name -eq "ffmpeg.exe" } | Select-Object -First 1
                if ($entry) {
                    [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
                    # Распаковался без ошибок = архив целый (CRC32-проверка zip)
                    $size = (Get-Item $target).Length
                    Write-Host "  +   ffmpeg installed: $target ($([math]::Round($size/1MB,1)) MB)" -ForegroundColor Green
                    $ok = $true
                    break
                } else {
                    Write-Host "  .   no ffmpeg.exe in archive bin/, trying next mirror..." -ForegroundColor Yellow
                }
            } finally {
                $z.Dispose()
                if (Test-Path $zip) { Remove-Item $zip -Force -ErrorAction SilentlyContinue }
            }
        } catch {
            Write-Host "  .   extract failed: $_" -ForegroundColor Yellow
        } finally {
            if (Test-Path $zip) { Remove-Item $zip -Force }
        }
    }
}

if (-not $ok) {
    Write-Host "  .   ffmpeg install failed after all mirrors" -ForegroundColor Yellow
    exit 1
}
exit 0
