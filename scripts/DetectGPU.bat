@REM scripts\DetectGPU.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Определение GPU: тип, имя, VRAM
REM ============================================================================
REM   Вызов: call DetectGPU.bat [quiet]
REM     quiet — полный детект без вывода сообщений (для фоновых вызовов)
REM
REM   ПРАВИЛА (никогда не удалять, только дополнять):
REM   1. Всегда возвращает 4 переменные: GPU_TYPE, GPU_NAME, GPU_VRAM_MB, GPU_VRAM_NUM
REM   2. Всегда через endlocal & set "VAR=VALUE" — иначе переменные потеряются
REM   3. GPU_TYPE: NVIDIA, AMD, INTEL, UNKNOWN
REM   4. GPU_VRAM_MB: строка с числом (для вывода)
REM   5. GPU_VRAM_NUM: число для сравнений (GEQ, LEQ)
REM   6. Fallback по имени — если Registry/WMI/dxdiag не сработали
REM   7. Новые карты добавлять в fallback по шаблону:
REM      echo.!GPU_NAME!|findstr /I "НАЗВАНИЕ">nul&&set "GPU_VRAM_MB=МБАЙТ"
REM   8. ПРИОРИТЕТ: NVIDIA/AMD > Intel (ищем дискретную карту первой!)
REM
REM   ИЗВЕСТНЫЕ ЛОВУШКИ (не наступать повторно!):
REM   - WMI Win32_VideoController.AdapterRAM — uint32, КЭП на ~4GB (4095/4096).
REM     Показания выше 4GB через WMI недостижимы, только Registry/dxdiag.
REM   - dxdiag вывод ЛОКАЛИЗОВАН: на RU Windows "Имя платы"/"Память дисплея"/"МБ".
REM   - Имя и VRAM применяем НЕЗАВИСИМО: имя применяется даже при VRAM=0,
REM     иначе fallback по имени не сможет сработать.
REM   - Файл держать в UTF-8 + chcp 65001 (в PS-команде есть кириллица в regex).
REM ============================================================================

REM === ESC (если вызвали из скрипта без ESC) ===
if not defined ESC (
    for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"
)

set "GPU_QUIET=0"
if /I "%~1"=="quiet" set "GPU_QUIET=1"

set "GPU_TYPE=UNKNOWN"
set "GPU_NAME=Не определена"
set "GPU_VRAM_MB=0"

if "!GPU_QUIET!"=="0" (
    echo.
    echo   %ESC%[1;33m  →   Определение видеокарты...%ESC%[0m
    echo   %ESC%[2m       Запросы к системе могут занять несколько секунд — это нормально.%ESC%[0m
)

REM === Метод 1: Registry (точные байты qwMemorySize; призраки пропускаем) ===
set "M_NAME="
set "M_VRAM=0"
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "try { $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; $best = $null; Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object { $name = $_.GetValue('DriverDesc'); $mem = $_.GetValue('HardwareInformation.qwMemorySize'); if (-not $mem) { $mem = $_.GetValue('HardwareInformation.MemorySize') }; if ($name -and $mem -and [int64]$mem -gt 0) { $prio = 0; if ($name -match 'NVIDIA|GeForce|AMD|Radeon') { $prio = 1 }; $score = [int64]$mem + $prio * [int64]1099511627776; if (-not $best -or $score -gt $best.Score) { $best = @{ Score = $score; Name = $name; Mem = [int64]$mem } } } }; if ($best) { Write-Output ('NAME=' + $best.Name); Write-Output ('VRAM=' + [math]::Round($best.Mem / 1MB)) } else { Write-Output 'NAME='; Write-Output 'VRAM=0' } } catch { Write-Output 'NAME='; Write-Output 'VRAM=0' }" 2^>nul') do (
    set "LINE=%%a"
    echo.!LINE!|findstr /B "NAME=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "M_NAME=%%b"
    echo.!LINE!|findstr /B "VRAM=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "M_VRAM=%%b"
)
if !M_VRAM! GTR 0 set "GPU_VRAM_MB=!M_VRAM!"
if not "!M_NAME!"=="" (
    if "!GPU_NAME!"=="Не определена" set "GPU_NAME=!M_NAME!"
)

REM === Метод 2: WMI fallback (ВНИМАНИЕ: AdapterRAM кэпится на ~4GB!) ===
if "!GPU_VRAM_MB!"=="0" (
    set "M_NAME="
    set "M_VRAM=0"
    for /f "tokens=*" %%a in ('powershell -NoProfile -Command "try { $gpu = Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { $_.Name -match 'NVIDIA|AMD|Radeon|GeForce' } | Select-Object -First 1; if (-not $gpu) { $gpu = Get-CimInstance Win32_VideoController | Sort-Object AdapterRAM -Descending | Select-Object -First 1 }; if ($gpu) { Write-Output ('NAME=' + $gpu.Name); Write-Output ('VRAM=' + [math]::Round($gpu.AdapterRAM / 1MB)) } else { Write-Output 'NAME='; Write-Output 'VRAM=0' } } catch { Write-Output 'NAME='; Write-Output 'VRAM=0' }" 2^>nul') do (
        set "LINE=%%a"
        echo.!LINE!|findstr /B "NAME=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "M_NAME=%%b"
        echo.!LINE!|findstr /B "VRAM=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "M_VRAM=%%b"
    )
    if !M_VRAM! GTR 0 set "GPU_VRAM_MB=!M_VRAM!"
    if not "!M_NAME!"=="" (
        if "!GPU_NAME!"=="Не определена" set "GPU_NAME=!M_NAME!"
    )
)

REM === Метод 3: dxdiag (только при подозрительном VRAM: 0 или WMI-кэп 4095/4096) ===
set "NEED_DXDIAG=0"
if "!GPU_VRAM_MB!"=="0" set "NEED_DXDIAG=1"
if "!GPU_VRAM_MB!"=="4095" set "NEED_DXDIAG=1"
if "!GPU_VRAM_MB!"=="4096" set "NEED_DXDIAG=1"

if "!NEED_DXDIAG!"=="1" (
    if "!GPU_QUIET!"=="0" echo   %ESC%[1;33m  →   Уточнение через dxdiag — может занять до 30 секунд, ждите...%ESC%[0m
    set "M_NAME="
    set "M_VRAM=0"
    for /f "tokens=*" %%a in ('powershell -NoProfile -Command "try { $tmp = Join-Path $env:TEMP 'dxdiag_gpu.txt'; if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }; & dxdiag /t $tmp | Out-Null; $n = 0; while ((-not (Test-Path $tmp)) -and ($n -lt 60)) { Start-Sleep -Milliseconds 500; $n++ }; Start-Sleep -Seconds 1; $content = Get-Content $tmp -Raw -ErrorAction Stop; $vram = 0; $name = ''; if ($content -match 'Dedicated Memory: +(\d+) MB') { $vram = [int]$matches[1] } elseif ($content -match 'Выделенная память: +(\d+) МБ') { $vram = [int]$matches[1] } elseif ($content -match 'Display Memory: +(\d+) MB') { $vram = [int]$matches[1] } elseif ($content -match 'Память дисплея: +(\d+) МБ') { $vram = [int]$matches[1] }; if ($content -match 'Card name: +(.+)') { $name = $matches[1].Trim() } elseif ($content -match 'Имя платы: +(.+)') { $name = $matches[1].Trim() }; Write-Output ('NAME=' + $name); Write-Output ('VRAM=' + $vram) } catch { Write-Output 'NAME='; Write-Output 'VRAM=0' }" 2^>nul') do (
        set "LINE=%%a"
        echo.!LINE!|findstr /B "NAME=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "M_NAME=%%b"
        echo.!LINE!|findstr /B "VRAM=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "M_VRAM=%%b"
    )
    if !M_VRAM! GTR 0 set "GPU_VRAM_MB=!M_VRAM!"
    if not "!M_NAME!"=="" if /I not "!M_NAME!"=="Unknown" (
        if "!GPU_NAME!"=="Не определена" set "GPU_NAME=!M_NAME!"
    )
)

REM === Fallback по имени GPU (добавлять новые карты сюда!) ===
if !GPU_VRAM_MB! LEQ 4096 (
    echo.!GPU_NAME!|findstr /I "RTX 5090">nul&&set "GPU_VRAM_MB=32768"
    echo.!GPU_NAME!|findstr /I "RTX 5080">nul&&set "GPU_VRAM_MB=32768"
    echo.!GPU_NAME!|findstr /I "RTX 4090">nul&&set "GPU_VRAM_MB=24576"
    echo.!GPU_NAME!|findstr /I "RTX 4080">nul&&set "GPU_VRAM_MB=16384"
    echo.!GPU_NAME!|findstr /I "RTX 4070">nul&&set "GPU_VRAM_MB=12288"
    echo.!GPU_NAME!|findstr /I "RTX 4060">nul&&set "GPU_VRAM_MB=8192"
    echo.!GPU_NAME!|findstr /I "RTX 3090">nul&&set "GPU_VRAM_MB=24576"
    echo.!GPU_NAME!|findstr /I "RTX 3080">nul&&set "GPU_VRAM_MB=10240"
    echo.!GPU_NAME!|findstr /I "RTX 3070">nul&&set "GPU_VRAM_MB=8192"
    echo.!GPU_NAME!|findstr /I "RTX 3060">nul&&set "GPU_VRAM_MB=12288"
    echo.!GPU_NAME!|findstr /I "RTX 2080">nul&&set "GPU_VRAM_MB=8192"
    echo.!GPU_NAME!|findstr /I "GTX 1080">nul&&set "GPU_VRAM_MB=8192"
    echo.!GPU_NAME!|findstr /I "7900">nul&&set "GPU_VRAM_MB=24576"
    echo.!GPU_NAME!|findstr /I "7800">nul&&set "GPU_VRAM_MB=16384"
    echo.!GPU_NAME!|findstr /I "7700">nul&&set "GPU_VRAM_MB=12288"
    echo.!GPU_NAME!|findstr /I "7600">nul&&set "GPU_VRAM_MB=8192"
)

REM === Определяем вендора ===
echo.!GPU_NAME!|findstr /I "NVIDIA">nul&&set "GPU_TYPE=NVIDIA"
echo.!GPU_NAME!|findstr /I "GeForce">nul&&set "GPU_TYPE=NVIDIA"
echo.!GPU_NAME!|findstr /I "AMD">nul&&set "GPU_TYPE=AMD"
echo.!GPU_NAME!|findstr /I "Radeon">nul&&set "GPU_TYPE=AMD"
echo.!GPU_NAME!|findstr /I "ATI">nul&&set "GPU_TYPE=AMD"
if "!GPU_TYPE!"=="UNKNOWN" (
    echo.!GPU_NAME!|findstr /I "Intel">nul&&set "GPU_TYPE=INTEL"
    echo.!GPU_NAME!|findstr /I "Arc">nul&&set "GPU_TYPE=INTEL"
)

REM === Нормализация VRAM ===
set "GPU_VRAM_NUM=!GPU_VRAM_MB: =!"
set "GPU_VRAM_NUM=!GPU_VRAM_NUM:"=!"
set /a "GPU_VRAM_NUM=!GPU_VRAM_NUM!" 2>nul
if !GPU_VRAM_NUM! EQU 0 set "GPU_VRAM_NUM=!GPU_VRAM_MB!"

REM === Итог детекта (виден и вызывающему, и при ручном запуске) ===
if "!GPU_QUIET!"=="0" (
    echo   %ESC%[1;32m  +   GPU: !GPU_NAME!%ESC%[0m
    echo   %ESC%[2m       Тип: !GPU_TYPE! ^| VRAM: !GPU_VRAM_MB! MB%ESC%[0m
    echo.
)

REM === Возврат переменных в вызывающий скрипт (ПРАВИЛО 2!) ===
endlocal & set "GPU_TYPE=%GPU_TYPE%" & set "GPU_NAME=%GPU_NAME%" & set "GPU_VRAM_MB=%GPU_VRAM_MB%" & set "GPU_VRAM_NUM=%GPU_VRAM_NUM%"

exit /b 0