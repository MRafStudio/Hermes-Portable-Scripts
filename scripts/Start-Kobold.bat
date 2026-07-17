@REM scripts\Start-Kobold.bat
@echo off
chcp 65001 >nul

REM ============================================================================
REM   Параметры: ACTION [AUTOCLOSE]
REM   ACTION: start | stop | status
REM   AUTOCLOSE: 1 = SmartPause 5sec, 0 = pause (default)
REM   Возвращает: 1 = успех/запущен, -1 = ошибка/не запущен
REM ============================================================================
set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=start"

set "AUTOCLOSE=0"
if "%2"=="1" set "AUTOCLOSE=1"

setlocal enabledelayedexpansion

REM ============================================================================
REM   Пути и изоляция
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "CONFIG_FILE=%SCRIPTS_DIR%\Config.ini"
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "HERMES_HOME=%DATA_DIR%\hermes"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Читаем Config.ini
REM ============================================================================
set "KOBOLD_ENABLED=0"
set "KOBOLD_PORT=5001"
set "KOBOLD_MODEL="
set "KOBOLD_MMPROJ="

if exist "%CONFIG_FILE%" (
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_ENABLED=" "%CONFIG_FILE%"') do set "KOBOLD_ENABLED=%%b"
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_PORT=" "%CONFIG_FILE%"') do set "KOBOLD_PORT=%%b"
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MODEL=" "%CONFIG_FILE%"') do set "KOBOLD_MODEL=%%b"
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MMPROJ=" "%CONFIG_FILE%"') do set "KOBOLD_MMPROJ=%%b"
)

set "KOBOLD_ENABLED=%KOBOLD_ENABLED: =%"
set "KOBOLD_PORT=%KOBOLD_PORT: =%"
set "KOBOLD_MODEL=%KOBOLD_MODEL: =%"
set "KOBOLD_MMPROJ=%KOBOLD_MMPROJ: =%"

REM ============================================================================
REM   Пути KoboldCpp (модели в подпапке models\)
REM ============================================================================
set "KCPP_DIR=%ROOT_DIR%\kobold"
set "KCPP_EXE=%KCPP_DIR%\koboldcpp.exe"
set "KCPP_MODEL=%KCPP_DIR%\models\%KOBOLD_MODEL%"
set "KCPP_MMPROJ=%KCPP_DIR%\models\%KOBOLD_MMPROJ%"

REM ============================================================================
REM   РОУТИНГ ДЕЙСТВИЙ
REM ============================================================================
if "%ACTION%"=="stop" goto :do_stop
if "%ACTION%"=="status" goto :do_status
REM По умолчанию — start

REM ============================================================================
REM   Автоопределение GPU и параметров (только для start)
REM ============================================================================
call "%SCRIPTS_DIR%\DetectGPU.bat"

cls

echo   %ESC%[1;33m  -   Определение видеокарты...%ESC%[0m

REM Выводим результат
if "%GPU_TYPE%"=="NVIDIA" (
    echo   %ESC%[1;32m  +   NVIDIA: %GPU_NAME% ^(%GPU_VRAM_MB% MB VRAM^)%ESC%[0m
) else if "%GPU_TYPE%"=="AMD" (
    echo   %ESC%[1;32m  +   AMD: %GPU_NAME% ^(%GPU_VRAM_MB% MB VRAM^)%ESC%[0m
) else if "%GPU_TYPE%"=="INTEL" (
    echo   %ESC%[1;33m  !   Intel GPU: %GPU_NAME% — производительность будет низкой%ESC%[0m
) else (
    echo   %ESC%[1;31m  -   GPU: %GPU_NAME% ^(%GPU_VRAM_MB% MB VRAM, вендор не определён^)%ESC%[0m
)

REM ============================================================================
REM   Выбор параметров KoboldCpp по GPU
REM ============================================================================
if "%GPU_TYPE%"=="NVIDIA" (
    if %GPU_VRAM_NUM% GEQ 32000 (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=2048"
    ) else if %GPU_VRAM_NUM% GEQ 24000 (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=2048"
    ) else if %GPU_VRAM_NUM% GEQ 16000 (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=1024"
    ) else if %GPU_VRAM_NUM% GEQ 11000 (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=1024"
    ) else if %GPU_VRAM_NUM% GEQ 7000 (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=512"
    ) else (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=256"
    )
    set "KCPP_GENAMT=4096"
    set "KCPP_FLASH=--flashattention"
    echo   %ESC%[1;36m  i   Параметры: ctx=!KCPP_CTX!, gen=4096, batch=!KCPP_BATCH!, flashattn=on%ESC%[0m
) else if "%GPU_TYPE%"=="AMD" (
    if %GPU_VRAM_NUM% GEQ 24000 (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=2048"
    ) else if %GPU_VRAM_NUM% GEQ 16000 (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=1024"
    ) else if %GPU_VRAM_NUM% GEQ 11000 (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=1024"
    ) else if %GPU_VRAM_NUM% GEQ 7000 (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=512"
    ) else (
        set "KCPP_CTX=65536"
        set "KCPP_BATCH=256"
    )
    set "KCPP_GENAMT=4096"
    set "KCPP_FLASH=--flashattention"
    echo   %ESC%[1;36m  i   Параметры: ctx=!KCPP_CTX!, gen=4096, batch=!KCPP_BATCH!, flashattn=on%ESC%[0m
) else if "%GPU_TYPE%"=="INTEL" (
    set "KCPP_CTX=65536"
    set "KCPP_GENAMT=1024"
    set "KCPP_BATCH=512"
    set "KCPP_FLASH="
    echo   %ESC%[1;33m  i   Параметры: ctx=8192, gen=1024, batch=256, flashattn=off%ESC%[0m
) else (
    set "KCPP_CTX=65536"
    set "KCPP_GENAMT=2048"
    set "KCPP_BATCH=512"
    set "KCPP_FLASH="
    echo   %ESC%[1;33m  i   Параметры: ctx=16384, gen=2048, batch=512, flashattn=off%ESC%[0m
)
goto :do_start

REM ============================================================================
REM   ACTION: status
REM ============================================================================
:do_status
tasklist /FI "IMAGENAME eq koboldcpp.exe" 2>nul | findstr /I "koboldcpp.exe" >nul
if !errorlevel! equ 0 (
    exit /b 1
) else (
    exit /b -1
)

REM ============================================================================
REM   ACTION: stop
REM ============================================================================
:do_stop
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                        KoboldCpp — Остановка                             %ESC%[0m %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

tasklist /FI "IMAGENAME eq koboldcpp.exe" 2>nul | findstr /I "koboldcpp.exe" >nul
if !errorlevel! equ 0 (
    echo   %ESC%[1;33m  -   Остановка KoboldCpp...%ESC%[0m
    taskkill /F /IM koboldcpp.exe >nul 2>nul
    timeout /t 2 /nobreak >nul 2>nul
    echo   %ESC%[1;32m  +   KoboldCpp остановлен.%ESC%[0m
    set "RET=1"
) else (
    echo   %ESC%[1;33m  .   KoboldCpp не запущен.%ESC%[0m
    set "RET=-1"
)
echo.

if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b %RET%

REM ============================================================================
REM   ACTION: start (по умолчанию)
REM ============================================================================
:do_start

echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                          KoboldCpp — Запуск                              %ESC%[0m %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM Проверка Config
if "!KOBOLD_ENABLED!"=="0" (
    echo   %ESC%[1;33m  -   KoboldCpp отключен в Config.ini%ESC%[0m
    echo   %ESC%[33m         Установите KOBOLD_ENABLED=1 через меню [2]%ESC%[0m
    echo.
    if "%AUTOCLOSE%"=="1" (
        call "%SCRIPTS_DIR%\SmartPause.bat" 5
    ) else (
        pause
    )
    exit /b -1
)

REM Проверка файлов — КОБОЛЬД
if not exist "%KCPP_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] KoboldCpp не найден%ESC%[0m
    echo   %ESC%[33m         Путь: %KCPP_EXE%%ESC%[0m
    goto :do_install
)

REM Проверка файлов — МОДЕЛЬ
if not exist "%KCPP_MODEL%" (
    echo   %ESC%[1;31m[ОШИБКА] Модель LLM не найдена%ESC%[0m
    echo   %ESC%[33m         %KCPP_MODEL%%ESC%[0m
    goto :do_install
)

REM Проверка файлов — ПРОЕКТОР VISION (обязательный!)
if not exist "%KCPP_MMPROJ%" (
    echo   %ESC%[1;31m[ОШИБКА] Проектор Vision ^(mmproj^) не найден%ESC%[0m
    echo   %ESC%[33m         %KCPP_MMPROJ%%ESC%[0m
    echo   %ESC%[33m         Vision-функциональность обязательна для работы.%ESC%[0m
    goto :do_install
)

goto :do_launch

REM ============================================================================
REM   Установка недостающих компонентов
REM ============================================================================
:do_install
echo.

if "%AUTOCLOSE%"=="1" (
    echo   %ESC%[1;33m  -   KoboldCpp не установлен. Автоматическая установка...%ESC%[0m
    echo   %ESC%[2m       Это может занять 10-20 минут ^(загрузка моделей^)...%ESC%[0m
    echo.
    call "%SCRIPTS_DIR%\InstallOrUpdate-Kobold.bat" "1" "models"
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   Установка завершена. Перезапускаем...%ESC%[0m
        timeout /t 2 /nobreak >nul
        goto :do_start
    ) else (
        echo   %ESC%[1;31m  [ОШИБКА] Установка не удалась.%ESC%[0m
        call "%SCRIPTS_DIR%\SmartPause.bat" 5
        exit /b -1
    )
)

echo   %ESC%[1;33m  i   Запустить установку KoboldCpp сейчас? [Y/N]: %ESC%[0m
set /p "INSTALL_KOBOLD="
if /I "!INSTALL_KOBOLD!"=="Y" (
    echo   %ESC%[1;33m  -   Запуск установки...%ESC%[0m
    call "%SCRIPTS_DIR%\InstallOrUpdate-Kobold.bat" "0" "models"
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   Установка завершена. Перезапускаем...%ESC%[0m
        timeout /t 2 /nobreak >nul
        goto :do_start
    ) else (
        echo   %ESC%[1;31m  [ОШИБКА] Установка не удалась.%ESC%[0m
    )
)
echo.
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b -1

REM ============================================================================
REM   Запуск KoboldCpp
REM ============================================================================
:do_launch

REM Проверяем, не запущен ли уже
tasklist /FI "IMAGENAME eq koboldcpp.exe" 2>nul | findstr /I "koboldcpp.exe" >nul
if !errorlevel! equ 0 (
    echo   %ESC%[1;33m  .   KoboldCpp уже запущен.%ESC%[0m
    echo   %ESC%[2m       http://127.0.0.1:%KOBOLD_PORT%%ESC%[0m
    echo.
    if "%AUTOCLOSE%"=="1" (
        call "%SCRIPTS_DIR%\SmartPause.bat" 5
    ) else (
        pause
    )
    exit /b 1
)

echo   %ESC%[1;33m  -   Запуск KoboldCpp в отдельном окне...%ESC%[0m
echo   %ESC%[2m       Модель: %KOBOLD_MODEL%%ESC%[0m
echo   %ESC%[2m       Порт: %KOBOLD_PORT%%ESC%[0m
echo.

REM Запуск в НОВОМ окне
if defined KCPP_MMPROJ (
    start "KoboldCpp — %GPU_NAME%" cmd /c ""%KCPP_EXE%" --model "%KCPP_MODEL%" --mmproj "%KCPP_MMPROJ%" --port %KOBOLD_PORT% --gpulayers 999 --contextsize !KCPP_CTX! --defaultgenamt !KCPP_GENAMT! --batchsize !KCPP_BATCH! !KCPP_FLASH!"
) else (
    start "KoboldCpp — %GPU_NAME%" cmd /c ""%KCPP_EXE%" --model "%KCPP_MODEL%" --port %KOBOLD_PORT% --gpulayers 999 --contextsize !KCPP_CTX! --defaultgenamt !KCPP_GENAMT! --batchsize !KCPP_BATCH! !KCPP_FLASH!"
)

echo   %ESC%[1;32m  +   KoboldCpp запущен в отдельном окне.%ESC%[0m
echo   %ESC%[2m       Ожидание инициализации...%ESC%[0m

REM ============================================================================
REM   Патч config.yaml для KoboldCpp (через PowerShell скрипт)
REM ============================================================================
echo   %ESC%[1;33m  -   Проверка config.yaml...%ESC%[0m

set "CONFIG_YAML=%HERMES_HOME%\config.yaml"
set "CONFIG_YAML_BAK=%HERMES_HOME%\config.yaml.bak"

if not exist "%CONFIG_YAML%" (
    echo   %ESC%[1;33m  i   config.yaml не найден. Пропускаем патч.%ESC%[0m
    goto kobold_done
)

REM Бэкап (только если ещё нет)
if not exist "%CONFIG_YAML_BAK%" (
    copy "%CONFIG_YAML%" "%CONFIG_YAML_BAK%" >nul 2>nul
    echo   %ESC%[1;33m  -   Бэкап: config.yaml.bak%ESC%[0m
)

REM Запускаем PowerShell скрипт патча с передачей KCPP_CTX
echo   %ESC%[1;33m  -   Патчим config.yaml (context=!KCPP_CTX!)...%ESC%[0m

powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\patch\config_kobold.ps1" -ConfigPath "%CONFIG_YAML%" -ContextLength !KCPP_CTX!

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m  [ОШИБКА] Не удалось пропатчить config.yaml.%ESC%[0m
    echo   %ESC%[33m         Восстановите из бэкапа: copy config.yaml.bak config.yaml%ESC%[0m
    goto kobold_done
)

:kobold_done

REM Ждём готовности
set "KCPP_READY=0"
for /L %%i in (1,1,60) do (
    if !KCPP_READY! equ 0 (
        timeout /t 1 /nobreak >nul 2>nul
        curl -s http://127.0.0.1:%KOBOLD_PORT%/api/v1/model >nul 2>nul
        if !errorlevel! equ 0 set "KCPP_READY=1"
    )
)

if !KCPP_READY! equ 1 (
    echo   %ESC%[1;32m  +   KoboldCpp готов!%ESC%[0m
    echo   %ESC%[2m       URL: http://127.0.0.1:%KOBOLD_PORT%%ESC%[0m
    set "RET=1"
) else (
    echo   %ESC%[1;33m  i   KoboldCpp не ответил вовремя.%ESC%[0m
    echo   %ESC%[33m         Проверьте окно KoboldCpp вручную.%ESC%[0m
    set "RET=-1"
)

if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b %RET%