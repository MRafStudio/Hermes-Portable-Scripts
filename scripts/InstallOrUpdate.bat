@REM scripts\InstallOrUpdate.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Установка / Обновление

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"

REM ============================================================================
REM   HERMES_HOME и пути
REM ============================================================================
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul

:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m          %ESC%[1;37mHermes Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление / Настройки%ESC%[0m          %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка статуса компонентов
REM ============================================================================

REM Desktop app
set "DESKTOP_INSTALLED=0"
set "DESKTOP_EXE_PATH="
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

REM --- Web UI (dashboard): собран ли web_dist ---
set "WEB_INSTALLED=0"
if exist "%REPO_DIR%\hermes_cli\web_dist\index.html" set "WEB_INSTALLED=1"
REM --- Что-то установлено (web или desktop)? ---
set "ANY_INSTALLED=0"
if !DESKTOP_INSTALLED! equ 1 set "ANY_INSTALLED=1"
if !WEB_INSTALLED! equ 1 set "ANY_INSTALLED=1"
REM --- Служба возможна, если есть web_dist ИЛИ Desktop-сборка ---
set "CAN_INSTALL_SERVICE=0"
if !WEB_INSTALLED! equ 1 set "CAN_INSTALL_SERVICE=1"
if !DESKTOP_INSTALLED! equ 1 set "CAN_INSTALL_SERVICE=1"


REM --- Статус службы ЭТОГО инстанса (по описанию с ROOT_DIR) ---
set "SERVICE_NAME="
set "SERVICE_INSTALLED=0"
call "%SCRIPTS_DIR%\Find-Hermes-Service.bat" "%ROOT_DIR%" <nul
if defined SERVICE_NAME set "SERVICE_INSTALLED=1"

REM ============================================================================
REM   Вывод меню
REM ============================================================================

if !ANY_INSTALLED! equ 0 (
    echo   %ESC%[1;33mНичего не установлено. Выберите действие:%ESC%[0m
    echo.
    echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1;33mУстановить Hermes Web %ESC%[2m^(сервер, без Desktop^)%ESC%[0m
    echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1;33mУстановить Hermes Desktop%ESC%[0m
    echo.
    echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
    echo.
    set "choice="
    set /p "choice=%ESC%[33mВыберите действие: %ESC%[0m"

    if not "!choice!"=="" set "choice=!choice: =!"
    if "!choice!"=="" goto menu
    if "!choice!"=="1" goto install_web
if "!choice!"=="2" goto install_desktop
    if "!choice!"=="0" goto exit
    goto menu
)

echo   %ESC%[1;33mУстановленные компоненты:%ESC%[0m
if !WEB_INSTALLED! equ 1 (
    echo     %ESC%[1;32m+%ESC%[0m Web UI %ESC%[2m^(dashboard^)%ESC%[0m
) else (
    echo     %ESC%[1;33m.%ESC%[0m Web UI %ESC%[2m^(не собран^)%ESC%[0m
)
if !DESKTOP_INSTALLED! equ 1 (
    echo     %ESC%[1;32m+%ESC%[0m Desktop App %ESC%[2m^(Hermes.exe^)%ESC%[0m
) else (
    echo     %ESC%[1;33m.%ESC%[0m Desktop App %ESC%[2m^(не собран^)%ESC%[0m
)
if !SERVICE_INSTALLED! equ 1 (
    echo     %ESC%[1;32m+%ESC%[0m Служба: %ESC%[1m!SERVICE_NAME!%ESC%[0m
) else (
    echo     %ESC%[1;33m.%ESC%[0m Служба Hermes %ESC%[2m^(не установлена^)%ESC%[0m
)
echo.
echo   %ESC%[1;33mВыберите действие:%ESC%[0m
if !WEB_INSTALLED! equ 1 (
    echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mОбновить Hermes Web %ESC%[2m^(сервер, без Desktop^)%ESC%[0m
) else (
    echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановить Hermes Web %ESC%[2m^(сервер, без Desktop^)%ESC%[0m
)
if !DESKTOP_INSTALLED! equ 1 (
    echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mОбновить Hermes Desktop%ESC%[0m
) else (
    echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mУстановить Hermes Desktop%ESC%[0m
)
if !ANY_INSTALLED! equ 1 (
    echo   %ESC%[1;37m[3]%ESC%[0m %ESC%[1mГайд: подключение с другого ПК %ESC%[2m^(пошагово^)%ESC%[0m
)
echo.
if !SERVICE_INSTALLED! equ 0 if !CAN_INSTALL_SERVICE! equ 1 (
    echo   %ESC%[1;37m[4]%ESC%[0m %ESC%[1mУстановить службу Hermes %ESC%[2m^(удалённый доступ^)%ESC%[0m
)
if !SERVICE_INSTALLED! equ 1 (
    echo   %ESC%[1;37m[5]%ESC%[0m %ESC%[1mПерезапустить службу Hermes%ESC%[0m
    echo   %ESC%[1;37m[6]%ESC%[0m %ESC%[1mУдалить службу Hermes%ESC%[0m
)
echo.
echo   %ESC%[1;37m[7]%ESC%[0m %ESC%[1mОткрыть порт в брандмауэре %ESC%[2m^(удалённый доступ^)%ESC%[0m
echo.

if !SERVICE_INSTALLED! equ 1 (
    echo   %ESC%[1;37m[8]%ESC%[0m %ESC%[1mИзменить логин и пароль %ESC%[2m^(удалённый доступ^)%ESC%[0m
    echo.
)
echo   %ESC%[1;37m[9]%ESC%[0m %ESC%[1mПараметры подключения к серверу Hermes %ESC%[0m
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие: %ESC%[0m"

if not "!choice!"=="" set "choice=!choice: =!"
if "!choice!"=="" goto menu
if "!choice!"=="1" goto install_web
if "!choice!"=="2" goto install_desktop
if "!choice!"=="3" goto connect_guide
if "!choice!"=="4" goto install_service
if "!choice!"=="5" goto restart_service
if "!choice!"=="6" goto remove_service
if "!choice!"=="7" goto firewall_port
if "!choice!"=="8" goto change_password
if "!choice!"=="9" call "%SCRIPTS_DIR%\Connection.bat"
if "!choice!"=="0" goto exit
goto menu

:install_web
cls
echo.
echo   %ESC%[1;33m-%ESC%[0m %ESC%[1mЗапуск установки Hermes Web ^(сервер^)...%ESC%[0m
call "%SCRIPTS_DIR%\Backup-Now.bat"
call "%SCRIPTS_DIR%\InstallOrUpdate-Web.bat" 0
goto menu

:install_desktop
cls
echo.
echo   %ESC%[1;33m-%ESC%[0m %ESC%[1mЗапуск установки Hermes Desktop...%ESC%[0m
call "%SCRIPTS_DIR%\Backup-Now.bat"
call "%SCRIPTS_DIR%\InstallOrUpdate-Desktop.bat" 0
goto menu

:install_service
if !ANY_INSTALLED! equ 0 (
    echo   %ESC%[1;31m[ОШИБКА] Hermes не установлен. Сначала установите: [1] Hermes Web или [2] Desktop.%ESC%[0m
    pause
    goto menu
)
call "%SCRIPTS_DIR%\Backup-Now.bat"
call "%SCRIPTS_DIR%\Install-Hermes-Service.bat"
goto menu

:remove_service
call "%SCRIPTS_DIR%\Remove-Hermes-Service.bat"
goto menu

:restart_service
call "%SCRIPTS_DIR%\Restart-Hermes-Service.bat"
goto menu

:firewall_port
call "%SCRIPTS_DIR%\Open-Firewall-Port.bat"
goto menu

:connect_guide
if !ANY_INSTALLED! equ 0 (
    echo   %ESC%[1;31m[ОШИБКА] Hermes не установлен. Сначала установите: [1] Hermes Web или [2] Desktop.%ESC%[0m
    pause
    goto menu
)
call "%SCRIPTS_DIR%\Connect-Guide.bat"
goto menu

:change_password
cls
echo [1;33mИзменение логина и пароля ^(удалённый доступ^)[0m
echo.
set "NEW_USER="
set /p "NEW_USER=[1mЛогин [2m[Enter — оставить текущий][0m: "
set "NEW_PASS="
set /p "NEW_PASS=[1mПароль[0m: "
if not "!NEW_USER!"=="" "%REPO_DIR%\venv\Scripts\hermes.exe" config set dashboard.basic_auth.username !NEW_USER! 2>nul
if not "!NEW_PASS!"=="" "%REPO_DIR%\venv\Scripts\hermes.exe" config set dashboard.basic_auth.password !NEW_PASS! 2>nul
echo.
echo [1;32m+ [0mЛогин и пароль обновлены. Перезапустите сервер ^(Start.bat — Enter или [5]^).
echo.
pause
goto menu

:exit
exit /b 0