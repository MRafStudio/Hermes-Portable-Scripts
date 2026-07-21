@REM scripts\Start-Kobold.bat
@echo off
chcp 65001 >nul

REM ============================================================================
REM   Параметры: ACTION [AUTOCLOSE] [DEBUG]
REM   ACTION: start | stop | status
REM   AUTOCLOSE: 1 = SmartPause 5sec, 0 = pause (default)
REM   DEBUG: 1 = запуск с cmd /k (окно остаётся — отладка из Tools.bat), 0 = cmd /c (default)
REM   Возвращает: 1 = успех/запущен, -1 = ошибка/не запущен
REM   ВНИМАНИЕ: вызывающие должны проверять код через equ, а не errorlevel-геq!
REM ============================================================================
set "ACTION=%~1"
if "%ACTION%"=="" set "ACTION=start"

set "AUTOCLOSE=0"
if "%2"=="1" set "AUTOCLOSE=1"

set "KOBOLD_DEBUG=0"
if "%3"=="1" set "KOBOLD_DEBUG=1"

setlocal enabledelayedexpansion

title KoboldCpp

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
call "%SCRIPTS_DIR%\DetectGPU.bat" quiet

REM Страховка: если DetectGPU не вернул VRAM — считаем нулём
if not defined GPU_VRAM_NUM set "GPU_VRAM_NUM=0"

cls

echo   %ESC%[1;33m  -   Определение видеокарты...%ESC%[0m

REM Выводим результат
if "%GPU_TYPE%"=="NVIDIA" (
    echo   %ESC%[1;32m  +   NVIDIA: %GPU_NAME% ^(%GPU_VRAM_MB% MB VRAM^)%ESC%[0m
) else if "%GPU_TYPE%"=="AMD" (
    echo   %ESC%[1;32m  +   AMD: %GPU_NAME% ^(%GPU_VRAM_MB% MB VRAM^)%ESC%[0m
) else if "%GPU_TYPE%"=="INTEL" (
    echo   %ESC%[1;33m  ⚠  Intel GPU: %GPU_NAME% — производительность будет низкой%ESC%[0m
) else (
    echo   %ESC%[1;31m  -   GPU: %GPU_NAME% ^(%GPU_VRAM_MB% MB VRAM, вендор не определён^)%ESC%[0m
)

REM ============================================================================
REM   Выбор параметров KoboldCpp по GPU
REM ============================================================================
if "%GPU_TYPE%"=="NVIDIA" (
    if %GPU_VRAM_NUM% GEQ 32000 (
        set "KCPP_CTX=131072"
        set "KCPP_BATCH=4096"
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
	REM Максимальный размер отдаваемых токенов
    set "KCPP_GENAMT=8192"
    set "KCPP_FLASH=--flashattention"
	
) else if "%GPU_TYPE%"=="AMD" (
    if %GPU_VRAM_NUM% GEQ 24000 (
        set "KCPP_CTX=262144"
        set "KCPP_BATCH=4096"
    ) else if %GPU_VRAM_NUM% GEQ 16000 (
        set "KCPP_CTX=131072"
        set "KCPP_BATCH=4096"
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
	REM Максимальный размер отдаваемых токенов
    set "KCPP_GENAMT=8192"
    set "KCPP_FLASH=--flashattention"
    
) else if "%GPU_TYPE%"=="INTEL" (
    set "KCPP_CTX=65536"
    set "KCPP_GENAMT=8192"
    set "KCPP_BATCH=512"
    set "KCPP_FLASH="
) else (
    set "KCPP_CTX=65536"
	REM Максимальный размер отдаваемых токенов
    set "KCPP_GENAMT=8192"
    set "KCPP_BATCH=512"
    set "KCPP_FLASH="
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

rem goto patch_yaml

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
REM   Нет koboldcpp.exe — нужен ПОЛНЫЙ режим, иначе — только модели!
REM ============================================================================
:do_install
echo.

set "INSTALL_MODE=models"
if not exist "%KCPP_EXE%" set "INSTALL_MODE=full"

if "%AUTOCLOSE%"=="1" (
    echo   %ESC%[1;33m  -   KoboldCpp не установлен. Автоматическая установка ^(!INSTALL_MODE!^)...%ESC%[0m
    echo   %ESC%[2m       Это может занять 10-20 минут ^(загрузка моделей^)...%ESC%[0m
    echo.
    call "%SCRIPTS_DIR%\InstallOrUpdate-Kobold.bat" "1" "!INSTALL_MODE!" !KCPP_CTX! 0
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
    echo   %ESC%[1;33m  -   Запуск установки ^(!INSTALL_MODE!^)...%ESC%[0m
    call "%SCRIPTS_DIR%\InstallOrUpdate-Kobold.bat" "0" "!INSTALL_MODE!" 
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
    if "!KOBOLD_DEBUG!"=="1" (
        echo   %ESC%[1;33m  -   KoboldCpp уже запущен. Останавливаем для перезапуска в отладке...%ESC%[0m
        echo.
        taskkill /F /IM koboldcpp.exe >nul 2>nul
        timeout /t 2 /nobreak >nul 2>nul
        echo   %ESC%[1;32m  +   Остановлен. Запускаем заново.%ESC%[0m
        echo.
    ) else (
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
)

REM Честный вывод параметров (ctx из переменной, а не литерал!)
if "!KCPP_FLASH!"=="" (
    echo   %ESC%[1;33m  i   Параметры: ctx=!KCPP_CTX!, gen=!KCPP_GENAMT!, batch=!KCPP_BATCH!, flashattn=off%ESC%[0m
) else (
    echo   %ESC%[1;36m  i   Параметры: ctx=!KCPP_CTX!, gen=!KCPP_GENAMT!, batch=!KCPP_BATCH!, flashattn=on%ESC%[0m
)

echo   %ESC%[1;33m  -   Запуск KoboldCpp в отдельном окне...%ESC%[0m
echo   %ESC%[2m       Модель: %KOBOLD_MODEL%%ESC%[0m
echo   %ESC%[2m       Порт: %KOBOLD_PORT%%ESC%[0m
echo.

REM Запуск в НОВОМ окне
REM DEBUG=1 (Tools.bat): cmd /k — окно остаётся, нормальный режим
REM DEBUG=0 (Start.bat): cmd /c + /MIN — окно сразу в панель задач
set "KCPP_CMD=/c"
set "KCPP_TITLE=KoboldCpp"
set "KCPP_MIN="
if "!KOBOLD_DEBUG!"=="1" (
    set "KCPP_CMD=/k"
    set "KCPP_TITLE=KoboldCpp (ОТЛАДКА)"
) else (
    set "KCPP_MIN=/MIN"
)
if defined KCPP_MMPROJ (
    start %KCPP_MIN% "!KCPP_TITLE! — %GPU_NAME%" cmd !KCPP_CMD! ""%KCPP_EXE%" --model "%KCPP_MODEL%" --mmproj "%KCPP_MMPROJ%" --host 0.0.0.0 --port %KOBOLD_PORT% --noshift --gpulayers 999 --genlimit 16384 --contextsize !KCPP_CTX! --defaultgenamt !KCPP_GENAMT! --batchsize !KCPP_BATCH! !KCPP_FLASH! --usecublas normal --noavx2 --nommap"
) else (
    start %KCPP_MIN% "!KCPP_TITLE! — %GPU_NAME%" cmd !KCPP_CMD! ""%KCPP_EXE%" --model "%KCPP_MODEL%" --host 0.0.0.0 --port %KOBOLD_PORT% --noshift --gpulayers 999 --genlimit 16384 --contextsize !KCPP_CTX! --defaultgenamt !KCPP_GENAMT! --batchsize !KCPP_BATCH! !KCPP_FLASH! --usecublas normal --noavx2 --nommap"
)

echo   %ESC%[1;32m  +   KoboldCpp запущен в отдельном окне.%ESC%[0m
echo   %ESC%[2m       Ожидание инициализации...%ESC%[0m

REM Ждём готовности
set "KCPP_READY=0"
for /L %%i in (1,1,60) do (
    if !KCPP_READY! equ 0 (
        timeout /t 1 /nobreak >nul 2>nul
        curl -fs http://127.0.0.1:%KOBOLD_PORT%/api/v1/model >nul 2>nul
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

:patch_yaml
REM ============================================================================
REM   Патч config.yaml — ТОЛЬКО С РАЗРЕШЕНИЯ ПОЛЬЗОВАТЕЛЯ!
REM   В авто-режиме — пропускаем (патч доступен через меню).
REM   Логика патча — в PatchConfigKobold.bat (не дублируем!).
REM ============================================================================
if "%AUTOCLOSE%"=="1" (
    echo   %ESC%[1;33m  .   Авто-режим: патч config.yaml пропущен ^(доступен через меню^).%ESC%[0m
    goto kobold_done
)

echo.
set "PATCH_KOBOLD="
set /p "PATCH_KOBOLD=%ESC%[33m  ?   Пропатчить config.yaml под KoboldCpp? [Y/N]: %ESC%[0m"
if /I "!PATCH_KOBOLD!"=="Y" (
    call "%SCRIPTS_DIR%\PatchConfigKobold.bat" %AUTOCLOSE% !KCPP_CTX! 0
) else (
    echo   %ESC%[1;33m  .   Патч config.yaml пропущен.%ESC%[0m
)

:kobold_done

if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    rem pause
)
exit /b %RET%