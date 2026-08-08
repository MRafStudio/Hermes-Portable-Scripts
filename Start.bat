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
REM   portable_start.ini — параметры запуска (автосоздание с дефолтами)
REM ============================================================================
set "START_INI=%HERMES_HOME%\portable_start.ini"
if not exist "%START_INI%" (
    > "%START_INI%" echo CONSOLE=0
    >> "%START_INI%" echo REMOTE_HOST=127.0.0.1
    >> "%START_INI%" echo REMOTE_PORT=9119
    >> "%START_INI%" echo REMOTE_URL=http://127.0.0.1:9119
    >> "%START_INI%" echo REMOTE_TOKEN=
    echo %ESC%[1;33m- %ESC%[0mСоздан %START_INI% с параметрами по умолчанию.
)

REM ============================================================================
REM   Синхронизация переменных окружения пользователя с корнем запуска
REM   (реестр всегда указывает на тот корень, из которого запущен Start.bat)
REM ============================================================================
if exist "%SCRIPTS_DIR%\ps\Fix-UserEnv.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps\Fix-UserEnv.ps1" -RootDir "%ROOT_DIR%"
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
for /f "delims=" %%m in ('call "%SCRIPTS_DIR%\Connection-Mode.bat"') do set "CONN_MODE=%%m"
if "!CONN_MODE!"=="LOCAL" (
    echo   %ESC%[1;33mПодключение:%ESC%[0m %ESC%[1;32mLOCAL%ESC%[0m %ESC%[2m^(127.0.0.1 / свой IP^)%ESC%[0m
) else (
    echo   %ESC%[1;33mПодключение:%ESC%[0m %ESC%[1;33mREMOTE%ESC%[0m %ESC%[2m^(удалённый сервер^)%ESC%[0m
)
echo   %ESC%[1;33mHERMES_HOME:%ESC%[0m %ESC%[2m%HERMES_HOME%%ESC%[0m
echo.
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
    echo %ESC%[1;33m. %ESC%[0m Служба Hermes %ESC%[2m^(не установлена — см. [1] п.4^)%ESC%[0m
)

echo.
REM [2] Инструменты и [5] Варианты запуска — только если что-то установлено
set "ANY_INSTALLED=0"
if !DESKTOP_INSTALLED! equ 1 set "ANY_INSTALLED=1"
if !WEB_INSTALLED! equ 1 set "ANY_INSTALLED=1"
echo %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановка, обновление и настройки%ESC%[0m
if !ANY_INSTALLED! equ 1 (
    echo %ESC%[1;37m[2]%ESC%[0m %ESC%[1mИнструменты%ESC%[0m
)
echo.
if !ANY_INSTALLED! equ 1 (
    echo %ESC%[1;37m[5]%ESC%[0m %ESC%[36mHermes — Варианты запуска%ESC%[0m
)
REM Быстрый запуск: Desktop приоритет, иначе Web
if !DESKTOP_INSTALLED! equ 1 (
    echo %ESC%[1;6m[*]%ESC%[0m %ESC%[32mБыстрый запуск Hermes Desktop%ESC%[0m
    echo.
) else if !WEB_INSTALLED! equ 1 (
    echo %ESC%[1;6m[*]%ESC%[0m %ESC%[32mБыстрый запуск Hermes Web %ESC%[2m^(dashboard^)%ESC%[0m
    echo.
)

REM [6] Desktop — локальное подключение (только если Desktop собран И в ini remote)
if !DESKTOP_INSTALLED! equ 1 if "!CONN_MODE!"=="REMOTE" (
    echo %ESC%[1;37m[6]%ESC%[0m %ESC%[32mHermes Desktop %ESC%[2m^(локальное подключение^)%ESC%[0m
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
if "%choice%"=="6" goto desktop_local
if "%choice%"=="0" goto exit
goto menu

:setup
call "%SCRIPTS_DIR%\InstallOrUpdate.bat"
goto menu

:dev_tools
call "%SCRIPTS_DIR%\Tools.bat"
goto menu

:desktop_local
cls
echo.
echo %ESC%[1;33m-%ESC%[0m %ESC%[1mЗапуск Hermes Desktop %ESC%[2m^(локальное подключение^)%ESC%[0m...%ESC%[0m
echo.
REM Сбрасываем connection.json на локальный эндпоинт (иначе Desktop возьмёт remote из ini)
if exist "%REPO_DIR%\venv\Scripts\python.exe" (
    "%REPO_DIR%\venv\Scripts\python.exe" "%SCRIPTS_DIR%\py\set_desktop_connection.py" "!USERPROFILE!\AppData\Roaming\Hermes" "http://127.0.0.1:9119" "127.0.0.1" >nul 2>&1
)
start /min "Hermes Desktop Console" cmd /c "%SCRIPTS_DIR%\Start-Hermes-Desktop-Console.bat"
goto menu

:launch_options
call "%SCRIPTS_DIR%\LaunchOptions.bat"
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
    call "%SCRIPTS_DIR%\Start-Hermes-Web.bat"
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
