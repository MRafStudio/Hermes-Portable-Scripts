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
set "NODE_MIN_MAJOR=26"
set "NODE_VERSION=26.12.1"

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
    set "G_VER="
    set "G_MAJOR=0"
    for /f "delims=" %%v in ('"!GLOBAL_NODE!\node.exe" --version 2^>nul') do set "G_VER=%%v"
    if defined G_VER (
        set "G_NUM=!G_VER:v=!"
        for /f "tokens=1 delims=." %%a in ("!G_NUM!") do set "G_MAJOR=%%a"
    )
    echo   %ESC%[2m       Версия: !G_VER!%ESC%[0m
    if !G_MAJOR! GEQ !NODE_MIN_MAJOR! (
        echo   %ESC%[1;32m  +   Версия подходит ^(!G_VER! ^>= !NODE_MIN_MAJOR!^) - используем глобальный.%ESC%[0m
        goto node_done
    )
    echo.
    echo  %ESC%[1;41m                                                                              %ESC%[0m
    echo  %ESC%[1;41m   ВНИМАНИЕ: ГЛОБАЛЬНЫЙ NODE.JS УСТАРЕЛ                                       %ESC%[0m
    echo  %ESC%[1;41m                                                                              %ESC%[0m
    echo   %ESC%[1;33m   Найден:    !GLOBAL_NODE!%ESC%[0m
    echo   %ESC%[1;33m   Версия:    !G_VER!%ESC%[0m
    echo   %ESC%[1;33m   Требуется: Node.js ^>= !NODE_MIN_MAJOR! ^(hermes-agent^)%ESC%[0m
    echo.
    echo   %ESC%[1;37mСейчас будет запущено ОБНОВЛЕНИЕ ГЛОБАЛЬНОГО Node.js:%ESC%[0m
    echo   %ESC%[2m   1^) winget ^(OpenJS.NodeJS^)  2^) если не выйдет - MSI v!NODE_VERSION! через UAC%ESC%[0m
    echo   %ESC%[2m   Если обновление не удастся - будет поставлена портативная версия.%ESC%[0m
    echo.
    set "UPD="
    set /p "UPD=   Обновить глобальный Node.js сейчас? (y/n): "
    if /I not "!UPD!"=="y" (
        echo   %ESC%[1;33m  !   Обновление отменено - ставим портативную версию.%ESC%[0m
    ) else (
        call :update_global_node
        if "!GLOBAL_UPDATED!"=="1" goto node_done
        echo   %ESC%[1;33m  !   Глобальный обновить не удалось - ставим портативную версию.%ESC%[0m
    )
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
REM hermes-agent: engines.node >=26 — версия задана выше (NODE_VERSION), единый источник истины
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

REM ============================================================================
REM   Обновление ГЛОБАЛЬНОГО Node.js (winget -> MSI через UAC) с перепроверкой
REM ============================================================================
:update_global_node
set "GLOBAL_UPDATED=0"
echo.
echo   %ESC%[2m       [обновление] попытка 1: winget OpenJS.NodeJS...%ESC%[0m
call :find_winget
if defined WINGET (
    echo   %ESC%[2m       winget: !WINGET! ^(v!WINGET_VER!^)%ESC%[0m
    powershell -NoProfile -Command "Start-Process -FilePath '!WINGET!' -ArgumentList 'install','--id','OpenJS.NodeJS','-e','--silent','--accept-package-agreements','--accept-source-agreements','--upgrade' -Verb RunAs -Wait" >nul 2>&1
    call :recheck_global_node
    if "!GLOBAL_UPDATED!"=="1" exit /b 0
) else (
    echo   %ESC%[1;33m  !   winget не найден ни в PATH, ни в WindowsApps - шаг пропущен.%ESC%[0m
    echo   %ESC%[2m       Перехожу к установке MSI ^(запрос UAC^).%ESC%[0m
)
echo.
echo   %ESC%[2m       [обновление] попытка 2: MSI v!NODE_VERSION! ^(запрос UAC^)...%ESC%[0m
set "NODE_MSI=node-v!NODE_VERSION!-x64.msi"
set "NODE_MSI_URL=https://nodejs.org/dist/v!NODE_VERSION!/!NODE_MSI!"
if exist "%TEMP%\!NODE_MSI!" del "%TEMP%\!NODE_MSI!" 2>nul
curl -L -o "%TEMP%\!NODE_MSI!" "!NODE_MSI_URL!" >nul 2>&1
if not exist "%TEMP%\!NODE_MSI!" (
    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '!NODE_MSI_URL!' -OutFile '%TEMP%\!NODE_MSI!'" >nul 2>&1
)
if exist "%TEMP%\!NODE_MSI!" (
    powershell -NoProfile -Command "Start-Process msiexec -ArgumentList '/i','%TEMP%\!NODE_MSI!','/qn','/norestart' -Verb RunAs -Wait" >nul 2>&1
    del "%TEMP%\!NODE_MSI!" 2>nul
    call :recheck_global_node
)
exit /b 0

:recheck_global_node
set "G_VER="
set "G_MAJOR=0"
for /f "delims=" %%v in ('"!GLOBAL_NODE!\node.exe" --version 2^>nul') do set "G_VER=%%v"
if defined G_VER (
    set "G_NUM=!G_VER:v=!"
    for /f "tokens=1 delims=." %%a in ("!G_NUM!") do set "G_MAJOR=%%a"
)
if !G_MAJOR! GEQ !NODE_MIN_MAJOR! (
    set "GLOBAL_UPDATED=1"
    echo   %ESC%[1;32m  +   Глобальный Node.js обновлён: !G_VER!%ESC%[0m
) else (
    echo   %ESC%[1;31m  x   Глобальный Node.js всё ещё !G_VER!%ESC%[0m
)
exit /b 0

REM ============================================================================
REM   Поиск winget: PATH -> алиас реального профиля -> PowerShell Get-Command
REM   ВАЖНО: каталог "C:\Program Files\WindowsApps" из cmd НЕ листается (ACL),
REM   поэтому перебор пакетов DesktopAppInstaller невозможен - только эти три пути.
REM   В обычном запуске (пользователь из Explorer/cmd) winget лежит в PATH.
REM ============================================================================
:find_winget
set "WINGET="
set "WINGET_VER="
for /f "delims=" %%w in ('where winget 2^>nul') do if not defined WINGET set "WINGET=%%w"
if not defined WINGET (
    if defined REAL_LOCALAPPDATA (
        if exist "%REAL_LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe" set "WINGET=%REAL_LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe"
    )
)
if not defined WINGET (
    for /f "delims=" %%w in ('powershell -NoProfile -Command "$p = Get-AppxPackage Microsoft.DesktopAppInstaller; if ($p) { Join-Path $p.InstallLocation winget.exe }" 2^>nul') do if not defined WINGET if exist "%%w" set "WINGET=%%w"
)
if not defined WINGET (
    for /f "delims=" %%w in ('powershell -NoProfile -Command "(Get-Command winget -ErrorAction SilentlyContinue).Source" 2^>nul') do if not defined WINGET set "WINGET=%%w"
)
if defined WINGET (
    set "WINGET_EXE=!WINGET!"
    for /f "delims=" %%v in ('powershell -NoProfile -Command "try { (& $env:WINGET_EXE --version) | Select-Object -First 1 } catch { }" 2^>nul') do if not defined WINGET_VER set "WINGET_VER=%%v"
)
exit /b 0
