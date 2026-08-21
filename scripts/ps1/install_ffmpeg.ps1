# scripts\ps1\install_ffmpeg.ps1
# Установка набора ffmpeg (ffmpeg.exe + ffprobe.exe + ffplay.exe) в портабельный каталог HERMES_HOME\bin.
# Приоритет: глобальные бинарники из реестрового PATH (Machine+User) -> копирование exe+DLL;
# если глобальных нет или они невалидны - скачивание (цепочка git-curl -> bitsadmin -> certutil -> PS TLS12).
# Зеркала: BtbN gpl -> BtbN lgpl -> gyan.dev essentials.
param(
    [string]$HermesHome = $env:HERMES_HOME
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "Continue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$binDir = "$HermesHome\bin"
$tools = @("ffmpeg.exe", "ffprobe.exe", "ffplay.exe")
$targets = @{}
foreach ($t in $tools) { $targets[$t] = "$binDir\$t" }

# Все три инструмента уже на месте -> выходим (идемпотентность при повторных запусках).
if (@($tools | Where-Object { Test-Path $targets[$_] }).Count -eq $tools.Count) {
    Write-Host "  +   ffmpeg toolkit already installed: $binDir" -ForegroundColor Green
    exit 0
}

function Missing-Tools {
    return @($tools | Where-Object { -not (Test-Path $targets[$_]) })
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

# --- Копирование глобальных ffmpeg/ffprobe/ffplay (экономия ~450 МБ трафика) ---
$copiedAny = $false
foreach ($t in (Missing-Tools)) {
    $g = Find-GlobalTool $t
    if (-not $g) { continue }
    # Валидируем ИСТОЧНИК: запускается ли он вообще
    $srcOk = $false
    try { & $g -version *> $null; if ($LASTEXITCODE -eq 0) { $srcOk = $true } } catch { $srcOk = $false }
    if ($srcOk) {
        if (-not (Test-Path $binDir)) { New-Item -ItemType Directory -Force -Path $binDir | Out-Null }
        Copy-Item $g -Destination $targets[$t] -Force
        if (-not $copiedAny) {
            # Динамическая сборка (gyan.dev): копируем DLL рядом с exe - без них ffmpeg не стартует.
            # Статическая сборка (BtbN): DLL нет - копируется только exe, это тоже корректно.
            $srcDir = Split-Path $g
            Get-ChildItem "$srcDir\*.dll" -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item $_.FullName -Destination $binDir -Force
            }
            $copiedAny = $true
        }
    }
}

# Валидируем КОПИИ: всё на месте? exe не повреждены? Если нет - чистим и качаем fallback
if ((Missing-Tools).Count -eq 0) {
    $copyOk = $true
    foreach ($t in $tools) {
        try { & $targets[$t] -version *> $null; if ($LASTEXITCODE -ne 0) { $copyOk = $false } } catch { $copyOk = $false }
    }
    if ($copyOk) {
        $copiedSize = (Get-ChildItem $binDir -File | Where-Object { $tools -contains $_.Name -or $_.Extension -eq ".dll" } | Measure-Object Length -Sum).Sum
        Write-Host "  +   ffmpeg toolkit copied from global: $binDir ($([math]::Round($copiedSize/1MB,1)) MB total)" -ForegroundColor Green
        exit 0
    }
    Write-Host "  .   copied ffmpeg failed validation, removing and falling back to download..." -ForegroundColor Yellow
    foreach ($t in $tools) { Remove-Item $targets[$t] -Force -ErrorAction SilentlyContinue }
    Get-ChildItem "$binDir\*.dll" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

# --- Fallback: скачивание (git-curl -> bitsadmin -> certutil -> PS TLS12) ---
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
    Write-Host "    Downloading ffmpeg toolkit: $url" -ForegroundColor Gray
    if (Download-With $url $zip) {
        try {
            $z = [System.IO.Compression.ZipFile]::OpenRead($zip)
            try {
                # Извлекаем недостающие инструменты из bin/ (BtbN-сборка — статическая, DLL не нужны)
                $stillMissing = Missing-Tools
                $extractedAny = $false
                foreach ($t in $stillMissing) {
                    $entry = $z.Entries | Where-Object { $_.Name -eq $t -and $_.FullName -like "*/bin/*" } | Select-Object -First 1
                    if ($entry) {
                        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $targets[$t], $true)
                        $extractedAny = $true
                    }
                }
                # Распаковалось без ошибок = архив целый (CRC32-проверка zip)
                if ($extractedAny) {
                    $size = (Get-ChildItem $binDir -File | Where-Object { $tools -contains $_.Name } | Measure-Object Length -Sum).Sum
                    Write-Host "  +   ffmpeg toolkit installed: $binDir ($([math]::Round($size/1MB,1)) MB)" -ForegroundColor Green
                    $ok = $true
                    break
                } else {
                    Write-Host "  .   no ffmpeg tools in archive bin/, trying next mirror..." -ForegroundColor Yellow
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
    Write-Host "  .   ffmpeg toolkit install failed after all mirrors" -ForegroundColor Yellow
    exit 1
}
exit 0
