@REM scripts\Start-Hermes-Web.bat — запуск Hermes Web (dashboard) по настройкам portable_start.ini
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Запуск Hermes Web

REM ============================================================================
REM   Определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "DATA_DIR=%ROOT_DIR%\data"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "HERMES_EXE=%REPO_DIR%\venv\Scripts\hermes.exe"

REM ============================================================================
REM   ПОЛНАЯ ИЗОЛЯЦИЯ PATH
REM ============================================================================
set "PATH=%HERMES_HOME%\bin;%ProgramFiles%\Git\cmd;%windir%\system32;%windir%;%windir%\System32\Wbem;%windir%\System32\WindowsPowerShell\v1.0"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
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
if not exist "%USERPROFILE%" mkdir "%USERPROFILE%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Параметры запуска из portable_start.ini (дефолты — локальный сервер)
REM ============================================================================
set "CONSOLE=0"
set "REMOTE_HOST=127.0.0.1"
set "REMOTE_PORT=9119"
set "REMOTE_URL=http://127.0.0.1:9119"
set "REMOTE_TOKEN=none"
set "START_INI=%HERMES_HOME%\portable_start.ini"
if exist "%START_INI%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%START_INI%") do (
        if /i "%%a"=="CONSOLE" set "CONSOLE=%%b"
        if /i "%%a"=="REMOTE_HOST" set "REMOTE_HOST=%%b"
        if /i "%%a"=="REMOTE_PORT" set "REMOTE_PORT=%%b"
        if /i "%%a"=="REMOTE_URL" set "REMOTE_URL=%%b"
        if /i "%%a"=="REMOTE_TOKEN" set "REMOTE_TOKEN=%%b"
    )
)

REM ============================================================================
REM   Проверка hermes.exe
REM ============================================================================
if not exist "%HERMES_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] hermes.exe не найден: %HERMES_EXE%%ESC%[0m
    echo   %ESC%[33m       Сначала выполните установку: [1] Установка / Обновление%ESC%[0m
    pause
    exit /b 1
)

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                 %ESC%[1;37mHermes Portable%ESC%[0m   —   %ESC%[1;33mWeb ^(dashboard^)%ESC%[0m                      %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo   %ESC%[1;33mHOST:%ESC%[0m   %ESC%[2m!REMOTE_HOST!%ESC%[0m
echo   %ESC%[1;33mPORT:%ESC%[0m   %ESC%[2m!REMOTE_PORT!%ESC%[0m
echo   %ESC%[1;33mURL:%ESC%[0m    %ESC%[2m!REMOTE_URL!%ESC%[0m
echo.

REM ============================================================================
REM   Локальный сервер (127.0.0.1) — запускаем dashboard при необходимости
REM   Удалённый сервер — просто открываем браузер на REMOTE_URL
REM ============================================================================
if /i "!REMOTE_HOST!"=="127.0.0.1" (
    REM Порт уже слушается (служба ИЛИ ручной запуск) — открываем браузер
    netstat -ano | findstr /c:":!REMOTE_PORT!" | findstr /c:"LISTENING" >nul 2>&1
    if !errorlevel! equ 0 (
        echo %ESC%[1;32m+ %ESC%[0m Сервер dashboard уже работает — открываем web UI в браузере.
        start "" "!REMOTE_URL!"
    ) else (
        echo %ESC%[2m       Dashboard не запущен — запускаем в отдельном окне.%ESC%[0m
        echo %ESC%[2m       Для постоянной работы установите службу: [1] -^> [4]%ESC%[0m
        call "%SCRIPTS_DIR%\Ensure-Dashboard-Token.bat"
        set /p "HERMES_DASHBOARD_SESSION_TOKEN=" < "%HERMES_HOME%\dashboard.token"
        if "!CONSOLE!"=="1" (
            start "Hermes Web" cmd /k ""%HERMES_EXE%" dashboard --host 0.0.0.0 --port !REMOTE_PORT! --skip-build"
        ) else (
            start "Hermes Web" cmd /c ""%HERMES_EXE%" dashboard --host 0.0.0.0 --port !REMOTE_PORT! --skip-build"
        )
    )
) else (
    REM Удалённый сервер — просто открываем браузер
    echo %ESC%[1;32m+ %ESC%[0m Удалённый сервер — открываем web UI в браузере.
    start "" "!REMOTE_URL!"
)

exit /b 0
