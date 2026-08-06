@REM Start.bat — Главное меню Hermes Portable
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Hermes Portable
pushd %~dp0

REM ============================================================================
REM   Пути (относительно Start.bat)
REM ============================================================================
for %%F in ("%~dp0") do set "ROOT_DIR=%%~fF"
set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"

REM HERMES_HOME — критично для Hermes!
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "DATA_DIR=%ROOT_DIR%\data"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"

REM ============================================================================
REM   Синхронизация переменных окружения пользователя с корнем запуска
REM   (реестр всегда указывает на тот корень, из которого запущен Start.bat)
REM ============================================================================
if exist "%SCRIPTS_DIR%\patch\Fix-UserEnv.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\patch\Fix-UserEnv.ps1" -RootDir "%ROOT_DIR%"
)

REM ============================================================================
REM   Рабочая директория сессий: terminal.cwd в config.yaml всегда = %ROOT_DIR%\data\home
REM   (Electron иначе берёт системный профиль через WinAPI — сессии падают в C:\Users\<user>)
REM ============================================================================
set "CONFIG_YAML=%HERMES_HOME%\config.yaml"
if exist "%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe" if exist "%CONFIG_YAML%" (
    "%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe" config set terminal.cwd "%ROOT_DIR%\data\home"
)

REM ============================================================================
REM   Изоляция данных (ничего в систему!)
REM ============================================================================
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "PYTHONUSERBASE=%DATA_DIR%\python-userbase"
set "PYTHONPATH="
set "PYTHONHOME="
set "PYTHONSTARTUP="
set "PYTHONIOENCODING=utf-8"
set "PIP_CACHE_DIR=%TEMP%\pip-cache"
set "HF_HOME=%DATA_DIR%\huggingface"
set "HF_HUB_DISABLE_SYMLINKS=1"
set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%HOME%\Desktop" mkdir "%HOME%\Desktop" 2>nul
if not exist "%PYTHONUSERBASE%" mkdir "%PYTHONUSERBASE%" 2>nul
if not exist "%HF_HOME%" mkdir "%HF_HOME%" 2>nul
if not exist "%HERMES_HOME%" mkdir "%HERMES_HOME%" 2>nul

for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

:menu

cls
echo.
echo %ESC%[1;36m################################################################################%ESC%[0m
echo %ESC%[1;36m##                                                                            ##%ESC%[0m
echo %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                 Hermes AI Agent (Portable)%ESC%[0m — %ESC%[1;33mГлавное меню%ESC%[0m                 %ESC%[1;36m##%ESC%[0m
echo %ESC%[1;36m##                                                                            ##%ESC%[0m
echo %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка статуса готовности компонентов и элементов запуска
REM ============================================================================
echo %ESC%[1;33mСтатус готовности:%ESC%[0m
set "DESKTOP_INSTALLED=0"
for %%P in (
    "%REPO_DIR%\apps\desktop\release\win-unpacked\Hermes.exe"
    "%REPO_DIR%\apps\desktop\release\win-ia32-unpacked\Hermes.exe"
    "%REPO_DIR%\apps\desktop\release\win-arm64-unpacked\Hermes.exe"
    "%REPO_DIR%\apps\desktop\release\win-x64-unpacked\Hermes.exe"
) do (
    if exist "%%P" (
        set "DESKTOP_INSTALLED=1"
        set "DESKTOP_EXE_PATH=%%P"
        goto :desktop_found
    )
)
:desktop_found
if !DESKTOP_INSTALLED! equ 1 (
    echo %ESC%[1;32m+ %ESC%[0m Desktop App %ESC%[2m^(Hermes.exe^)%ESC%[0m
) else (
    echo %ESC%[1;33m. %ESC%[0m Desktop App %ESC%[2m^(не собран^)%ESC%[0m
)
REM --- Web UI (dashboard): собран ли web_dist ---
set "WEB_INSTALLED=0"
if exist "%REPO_DIR%\hermes_cli\web_dist\index.html" set "WEB_INSTALLED=1"
if !WEB_INSTALLED! equ 1 (
    echo %ESC%[1;32m+ %ESC%[0m Web UI %ESC%[2m^(dashboard^)%ESC%[0m
) else (
    echo %ESC%[1;33m. %ESC%[0m Web UI %ESC%[2m^(не собран — [1] п.1^)%ESC%[0m
)

REM --- Статус службы ЭТОГО инстанса (по описанию с ROOT_DIR) ---
set "SERVICE_NAME="
set "SERVICE_INSTALLED=0"
call "%SCRIPTS_DIR%\Find-Hermes-Service.bat" "%ROOT_DIR%" <nul
if defined SERVICE_NAME set "SERVICE_INSTALLED=1"
if !SERVICE_INSTALLED! equ 1 (
    echo %ESC%[1;32m+ %ESC%[0m Служба: %ESC%[1m!SERVICE_NAME!%ESC%[0m %ESC%[2m^(установлена^)%ESC%[0m
) else (
    echo %ESC%[1;33m. %ESC%[0m Служба Hermes %ESC%[2m^(не установлена — см. [1] п.5^)%ESC%[0m
)

echo.
REM [2] Инструменты и [5] Варианты запуска — только если что-то установлено
set "ANY_INSTALLED=0"
if !DESKTOP_INSTALLED! equ 1 set "ANY_INSTALLED=1"
if !WEB_INSTALLED! equ 1 set "ANY_INSTALLED=1"
echo %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановка / Обновление компонентов%ESC%[0m
if !ANY_INSTALLED! equ 1 (
    echo %ESC%[1;37m[2]%ESC%[0m %ESC%[1mИнструменты%ESC%[0m
)
echo.
if !ANY_INSTALLED! equ 1 (
    echo %ESC%[1;37m[5]%ESC%[0m %ESC%[36mHermes — Варианты запуска%ESC%[0m
)
echo %ESC%[1;37m[6]%ESC%[0m %ESC%[1mHermes — Desktop ^(другой сервер^)%ESC%[0m %ESC%[2m— подключение к удалённому серверу%ESC%[0m
REM Быстрый запуск: Desktop приоритет, иначе Web
if !DESKTOP_INSTALLED! equ 1 (
    echo %ESC%[1;6m[*]%ESC%[0m %ESC%[32mБыстрый запуск Hermes Desktop%ESC%[0m
    echo.
) else if !WEB_INSTALLED! equ 1 (
    echo %ESC%[1;6m[*]%ESC%[0m %ESC%[32mБыстрый запуск Hermes Web %ESC%[2m^(dashboard^)%ESC%[0m
    echo.
)

echo %ESC%[1;37m[0]%ESC%[0m %ESC%[1mВыход%ESC%[0m
echo.

set "choice=INVALID"
set /p "choice=%ESC%[33mВыберите действие (Enter — быстрый запуск): %ESC%[0m"

set "choice=%choice: =%"
if "%choice%"=="INVALID" goto launch

if "%choice%"=="" goto launch
if "%choice%"=="*" goto launch
if "%choice%"=="1" goto setup
if "%choice%"=="2" goto dev_tools

if "%choice%"=="5" goto launch_options
if "%choice%"=="6" goto desktop_remote
if "%choice%"=="0" goto exit
goto menu

:setup
call "%SCRIPTS_DIR%\InstallOrUpdate.bat"
goto menu

:dev_tools
call "%SCRIPTS_DIR%\Tools.bat"
goto menu

:launch_options
call "%SCRIPTS_DIR%\LaunchOptions.bat"
goto menu

:desktop_remote
cls
echo.
echo %ESC%[1;33m-%ESC%[0m %ESC%[1mHermes — Desktop ^(другой сервер^)%ESC%[0m
echo.
if not defined DESKTOP_EXE_PATH (
    echo %ESC%[1;31m[ОШИБКА] Desktop не собран. Сначала соберите: [1] Установка/Обновление -^> [2] Установить Hermes Desktop.%ESC%[0m
    echo.
    pause
    goto menu
)
if not exist "%HERMES_HOME%\remote-server.ini" (
    echo %ESC%[1;31m[ОШИБКА] Параметры удалённого сервера не сохранены.%ESC%[0m
    echo %ESC%[33m      Настройте подключение: [5] Варианты запуска -^> [9] Hermes — Desktop ^(другой сервер^).%ESC%[0m
    echo.
    pause
    goto menu
)
for /f "usebackq tokens=1,* delims==" %%a in ("%HERMES_HOME%\remote-server.ini") do set "%%a=%%b"
if not defined REMOTE_URL (
    echo %ESC%[1;31m[ОШИБКА] Файл %HERMES_HOME%\remote-server.ini повреждён.%ESC%[0m
    echo.
    pause
    goto menu
)
if not defined REMOTE_TOKEN (
    echo %ESC%[1;31m[ОШИБКА] В файле %HERMES_HOME%\remote-server.ini нет REMOTE_TOKEN.%ESC%[0m
    echo %ESC%[33m      Настройте заново: [5] Варианты запуска -^> [9] Hermes — Desktop ^(другой сервер^).%ESC%[0m
    echo.
    pause
    goto menu
)
echo %ESC%[1;33m- %ESC%[0mПроверяю доступность %ESC%[1m!REMOTE_URL!%ESC%[0m...
set "TCP_OK=False"
for /f "usebackq delims=" %%r in (`powershell -NoProfile -Command "(Test-NetConnection -ComputerName '!REMOTE_HOST!' -Port !REMOTE_PORT! -WarningAction SilentlyContinue).TcpTestSucceeded"`) do set "TCP_OK=%%r"
if /i not "!TCP_OK!"=="True" (
    echo %ESC%[1;33m. %ESC%[0mСервер не отвечает. Всё равно запустить? %ESC%[2m[Enter = да, N = нет]%ESC%[0m
    set "FORCE="
    set /p "FORCE="
    if /i "!FORCE!"=="N" goto menu
)
set "HERMES_DESKTOP_REMOTE_URL=!REMOTE_URL!"
set "HERMES_DESKTOP_REMOTE_TOKEN=!REMOTE_TOKEN!"
echo %ESC%[1;32m+ %ESC%[0mЗапускаю Desktop с подключением к !REMOTE_URL!...
echo.
start "" "!DESKTOP_EXE_PATH!"
pause
goto menu

:launch
if !DESKTOP_INSTALLED! equ 1 (
    cls
    echo.
    echo %ESC%[1;33m-%ESC%[0m %ESC%[1mЗапуск Hermes Desktop...%ESC%[0m
    echo.
    call "%SCRIPTS_DIR%\Start-Hermes-Desktop.bat" 1
    goto menu
)
if !WEB_INSTALLED! equ 1 (
    cls
    echo.
    echo %ESC%[1;33m-%ESC%[0m %ESC%[1mЗапуск Hermes Web %ESC%[2m^(dashboard^)%ESC%[0m...%ESC%[0m
    echo.
    REM Порт dashboard уже слушается (служба ИЛИ ручной запуск) — просто открываем браузер!
    netstat -ano | findstr /c:":9119" | findstr /c:"LISTENING" >nul 2>&1
    if !errorlevel! equ 0 (
        echo %ESC%[1;32m+ %ESC%[0m Сервер dashboard уже работает — открываем web UI в браузере.
        start "" "http://localhost:9119"
    ) else if !SERVICE_INSTALLED! equ 1 (
        echo %ESC%[1;33m. %ESC%[0m Служба установлена, но не запущена — запускаем...
        net start !SERVICE_NAME! >nul 2>&1
        echo %ESC%[1;32m+ %ESC%[0m Служба запущена — открываем web UI в браузере.
        start "" "http://localhost:9119"
    ) else (
        echo %ESC%[2m       Dashboard не запущен — запускаем в отдельном окне.%ESC%[0m
        echo %ESC%[2m       Для постоянной работы установите службу: [1] → [4]%ESC%[0m
        start "Hermes Web" cmd /k ""%REPO_DIR%\venv\Scripts\hermes.exe" dashboard --host 0.0.0.0 --port 9119 --skip-build"
    )
    goto menu
)
cls
echo.
echo %ESC%[1;31m[ОШИБКА] Ничего не установлено.%ESC%[0m
echo %ESC%[33m Начните с установки: [1] Установка / Обновление компонентов%ESC%[0m
echo.
pause
goto menu

:exit
popd
exit /b 0
