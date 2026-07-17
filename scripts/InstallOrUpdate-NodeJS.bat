@REM scripts\InstallOrUpdate-NodeJS.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Hermes Portable — Установка Node.js Portable

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "NODE_DIR=%HERMES_HOME%\node"
set "NODE_EXE=%NODE_DIR%\node.exe"

REM ============================================================================
REM   Сохраняем РЕАЛЬНЫЕ пути ДО изоляции
REM ============================================================================
set "REAL_LOCALAPPDATA=%LOCALAPPDATA%"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%HERMES_HOME%" mkdir "%HERMES_HOME%" 2>nul

REM ============================================================================
REM   Получение ESC (стандартный трюк, как в остальных скриптах)
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m              %ESC%[1;37mHermes Portable%ESC%[0m   %ESC%[1;33m—%ESC%[0m   %ESC%[1;33mУстановка Node.js Portable%ESC%[0m              %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 0: Проверка разрядности
REM ============================================================================
echo   %ESC%[1;33m[0/2]%ESC%[0m %ESC%[1mПроверка разрядности Windows...%ESC%[0m
set "ARCH_OK=0"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH_OK=1"
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "ARCH_OK=1"

if %ARCH_OK%==0 (
    echo   %ESC%[1;31m[ОШИБКА] Обнаружена 32-разрядная ^(x86^) Windows.%ESC%[0m
    echo   %ESC%[33m       Node.js требует 64-разрядную систему.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)
echo   %ESC%[1;32m  +   Система 64-разрядная ^(x64^).%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 1: Проверка Node.js (глобальный -> локальный)
REM ============================================================================
echo   %ESC%[1;33m[1/2]%ESC%[0m %ESC%[1mПроверка Node.js...%ESC%[0m

REM --- 1. Глобальный Node.js (ПРИОРИТЕТ): стандартные пути ---
set "GLOBAL_NODE="
if exist "%ProgramFiles%\nodejs\node.exe" set "GLOBAL_NODE=%ProgramFiles%\nodejs"
if not defined GLOBAL_NODE if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "GLOBAL_NODE=%ProgramFiles(x86)%\nodejs"
if not defined GLOBAL_NODE if exist "%REAL_LOCALAPPDATA%\Programs\nodejs\node.exe" set "GLOBAL_NODE=%REAL_LOCALAPPDATA%\Programs\nodejs"

REM --- Глобальный Node.js: реестр (HKLM + WOW6432Node + HKCU) ---
if not defined GLOBAL_NODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKLM\SOFTWARE\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" (
            if exist "%%c\node.exe" set "GLOBAL_NODE=%%c"
        )
    )
)
if not defined GLOBAL_NODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" (
            if exist "%%c\node.exe" set "GLOBAL_NODE=%%c"
        )
    )
)
if not defined GLOBAL_NODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKCU\SOFTWARE\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" (
            if exist "%%c\node.exe" set "GLOBAL_NODE=%%c"
        )
    )
)

if defined GLOBAL_NODE (
    echo   %ESC%[1;32m  +   Обнаружен глобальный Node.js%ESC%[0m
    echo   %ESC%[2m       !GLOBAL_NODE!\%ESC%[0m
    set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
    for /f "delims=" %%v in ('"!GLOBAL_NODE!\node.exe" --version 2^>nul') do echo %%v
    echo   %ESC%[1;33m  .   Локальная установка не требуется — Hermes использует глобальный.%ESC%[0m
    goto node_done
)

REM --- 2. Локальный Node.js: уже установлен? ---
if exist "%NODE_EXE%" (
    "%NODE_EXE%" --version >nul 2>nul
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   Локальный Node.js уже установлен.%ESC%[0m
        set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
        for /f "delims=" %%v in ('"%NODE_EXE%" --version 2^>nul') do echo %%v
        goto node_done
    ) else (
        echo   %ESC%[1;33m  .   Node.js найден, но не работает. Переустановка...%ESC%[0m
        rmdir /s /q "%NODE_DIR%" 2>nul
    )
) else (
    echo   %ESC%[1;33m  →   Node.js не найден. Загрузка...%ESC%[0m
)

REM ============================================================================
REM   ШАГ 2: Загрузка и распаковка
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/2]%ESC%[0m %ESC%[1mЗагрузка Node.js...%ESC%[0m

set "NODE_ARCH=win-x64"
set "NODE_VERSION=22.13.0"
set "NODE_ZIP=node-v!NODE_VERSION!-!NODE_ARCH!.zip"
set "NODE_URL=https://nodejs.org/dist/v!NODE_VERSION!/!NODE_ZIP!"

echo   %ESC%[2m       URL: !NODE_URL!%ESC%[0m
echo   %ESC%[2m       ~30 МБ, подождите...%ESC%[0m

REM Удаляем битый zip если есть
if exist "%TEMP%\!NODE_ZIP!" del "%TEMP%\!NODE_ZIP!" 2>nul

REM ============================================================================
REM   Загрузка через curl (быстро)
REM ============================================================================
echo   %ESC%[2m       Попытка загрузки через curl...%ESC%[0m
curl -L -o "%TEMP%\!NODE_ZIP!" "!NODE_URL!"

if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  +   Загрузка через curl завершена.%ESC%[0m
    goto node_unpack
) else (
    echo   %ESC%[1;33m  .   curl не справился. Переключение на PowerShell...%ESC%[0m
)

REM ============================================================================
REM   Fallback: PowerShell
REM ============================================================================
powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '!NODE_URL!' -OutFile '%TEMP%\!NODE_ZIP!'"

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось загрузить Node.js.%ESC%[0m
    echo   %ESC%[33m       Проверьте соединение с интернетом.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

echo   %ESC%[1;32m  +   Загрузка через PowerShell завершена.%ESC%[0m

:node_unpack
echo.
echo   %ESC%[1;33m  →   Распаковка...%ESC%[0m

if exist "%NODE_DIR%" rmdir /s /q "%NODE_DIR%"
mkdir "%NODE_DIR%" 2>nul

REM Чистим каталог распаковки от прошлых запусков
if exist "%TEMP%\node_extract" rmdir /s /q "%TEMP%\node_extract" 2>nul

REM ============================================================================
REM   Распаковка: сначала 7-Zip, потом PowerShell (fallback)
REM ============================================================================
set "SEVENZIP="

where 7z >nul 2>nul
if !errorlevel! equ 0 (
    for /f "tokens=*" %%a in ('where 7z 2^>nul') do set "SEVENZIP=%%a"
)

if not defined SEVENZIP (
    if exist "C:\Program Files\7-Zip\7z.exe" set "SEVENZIP=C:\Program Files\7-Zip\7z.exe"
)
if not defined SEVENZIP (
    if exist "C:\Program Files (x86)\7-Zip\7z.exe" set "SEVENZIP=C:\Program Files (x86)\7-Zip\7z.exe"
)

if defined SEVENZIP (
    echo   %ESC%[2m       Распаковка через 7-Zip...%ESC%[0m
    "%SEVENZIP%" x "%TEMP%\!NODE_ZIP!" -o"%TEMP%\node_extract" -y >nul 2>&1

    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   Распаковка через 7-Zip завершена.%ESC%[0m
        goto node_move
    ) else (
        echo   %ESC%[1;33m  .   7-Zip не справился. Переключение на PowerShell...%ESC%[0m
    )
) else (
    echo   %ESC%[2m       7-Zip не найден. Используем PowerShell...%ESC%[0m
)

REM Fallback: PowerShell Expand-Archive
powershell -NoProfile -Command "Expand-Archive -Path '%TEMP%\!NODE_ZIP!' -DestinationPath '%TEMP%\node_extract' -Force"
echo   %ESC%[1;32m  +   Распаковка через PowerShell завершена.%ESC%[0m

:node_move
REM ============================================================================
REM   Перемещаем файлы из подпапки (PowerShell — одна команда)
REM ============================================================================
powershell -NoProfile -Command "$src = Get-ChildItem -Path '%TEMP%\node_extract' -Directory | Select-Object -First 1; if ($src) { Get-ChildItem -Path $src.FullName | Move-Item -Destination '%NODE_DIR%' -Force }; Remove-Item -Path '%TEMP%\node_extract' -Recurse -Force"

del "%TEMP%\!NODE_ZIP!" 2>nul

if not exist "%NODE_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] Node.js не распаковался.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

echo   %ESC%[1;32m  +   Node.js установлен.%ESC%[0m
set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
for /f "delims=" %%v in ('"%NODE_EXE%" --version 2^>nul') do echo %%v

:node_done
echo.
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
if defined GLOBAL_NODE (
    echo   %ESC%[1;32mNode.js готов ^(глобальный^)%ESC%[0m
    echo   %ESC%[2m  Путь: !GLOBAL_NODE!%ESC%[0m
) else (
    echo   %ESC%[1;32mNode.js готов ^(локальный^)%ESC%[0m
    echo   %ESC%[2m  Путь: %NODE_DIR%%ESC%[0m
)
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m

if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0