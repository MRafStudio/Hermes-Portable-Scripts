@REM scripts\DetectGPU.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Определение GPU: тип, имя, VRAM
REM ============================================================================
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
REM ============================================================================

set "GPU_TYPE=UNKNOWN"
set "GPU_NAME=Не определена"
set "GPU_VRAM_MB=0"

REM === Метод 1: Registry (ищем NVIDIA/AMD в приоритете) ===
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "try { $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'; $keys = Get-ChildItem $regPath -ErrorAction SilentlyContinue | Where-Object { $_.GetValue('DriverDesc') -match 'NVIDIA|AMD|Radeon|GeForce' }; if (-not $keys) { $keys = Get-ChildItem $regPath -ErrorAction SilentlyContinue | Where-Object { $_.GetValue('HardwareInformation.qwMemorySize') -ne $null -or $_.GetValue('HardwareInformation.MemorySize') -ne $null } }; if ($keys) { $key = $keys | Select-Object -First 1; $mem = $key.GetValue('HardwareInformation.qwMemorySize'); if (-not $mem) { $mem = $key.GetValue('HardwareInformation.MemorySize') }; $name = $key.GetValue('DriverDesc'); Write-Output ('NAME=' + $name); Write-Output ('VRAM=' + [math]::Round($mem / 1MB)) } else { Write-Output 'NAME=UNKNOWN'; Write-Output 'VRAM=0' } } catch { Write-Output 'NAME=UNKNOWN'; Write-Output 'VRAM=0' }" 2^>nul') do (
    set "LINE=%%a"
    echo.!LINE!|findstr /B "NAME=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "GPU_NAME=%%b"
    echo.!LINE!|findstr /B "VRAM=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "GPU_VRAM_MB=%%b"
)

REM === Метод 2: WMI fallback (ищем NVIDIA/AMD в приоритете, потом макс VRAM) ===
if "!GPU_VRAM_MB!"=="0" (
    for /f "tokens=*" %%a in ('powershell -NoProfile -Command "try { $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA|AMD|Radeon|GeForce' } | Select-Object -First 1; if (-not $gpu) { $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.AdapterRAM -gt 0 } | Sort-Object AdapterRAM -Descending | Select-Object -First 1 }; $name = $gpu.Name; $ram = [math]::Round($gpu.AdapterRAM / 1MB); if ($ram -gt 4096) { $ram = [math]::Round($ram) }; Write-Output ('NAME=' + $name); Write-Output ('VRAM=' + $ram) } catch { Write-Output 'NAME=UNKNOWN'; Write-Output 'VRAM=0' }" 2^>nul') do (
        set "LINE=%%a"
        echo.!LINE!|findstr /B "NAME=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "GPU_NAME=%%b"
        echo.!LINE!|findstr /B "VRAM=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "GPU_VRAM_MB=%%b"
    )
)

REM === Метод 3: dxdiag ===
if "!GPU_VRAM_MB!"=="4095" (
    for /f "tokens=*" %%a in ('powershell -NoProfile -Command "try { $dxdiag = & dxdiag /t \"$env:TEMP\dxdiag.txt\" 2^>$null; Start-Sleep -Seconds 2; $content = Get-Content \"$env:TEMP\dxdiag.txt\" -Raw; if ($content -match 'Display Memory: (\d+) MB') { $vram = [int]$matches[1]; $name = 'Unknown'; if ($content -match 'Card name: (.+)') { $name = $matches[1].Trim() }; Write-Output ('NAME=' + $name); Write-Output ('VRAM=' + $vram) } else { Write-Output 'NAME=UNKNOWN'; Write-Output 'VRAM=0' } } catch { Write-Output 'NAME=UNKNOWN'; Write-Output 'VRAM=0' }" 2^>nul') do (
        set "LINE=%%a"
        echo.!LINE!|findstr /B "NAME=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "GPU_NAME=%%b"
        echo.!LINE!|findstr /B "VRAM=">nul&&for /f "tokens=2 delims==" %%b in ("!LINE!") do set "GPU_VRAM_MB=%%b"
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

REM === Возврат переменных в вызывающий скрипт (ПРАВИЛО 2!) ===
endlocal & set "GPU_TYPE=%GPU_TYPE%" & set "GPU_NAME=%GPU_NAME%" & set "GPU_VRAM_MB=%GPU_VRAM_MB%" & set "GPU_VRAM_NUM=%GPU_VRAM_NUM%"

exit /b 0