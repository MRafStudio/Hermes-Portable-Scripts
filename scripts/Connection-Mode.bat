@REM scripts\Connection-Mode.bat — точка подключения: LOCAL или REMOTE
@REM Выводит в stdout: "LOCAL" или "REMOTE" (по REMOTE_HOST из portable_start.ini)
@REM Exit-код: 0 = LOCAL, 1 = REMOTE (для if errorlevel)
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REMOTE_HOST=127.0.0.1"
set "START_INI=%HERMES_HOME%\portable_start.ini"
if exist "%START_INI%" for /f "usebackq tokens=1,* delims==" %%a in ("%START_INI%") do (
    if /i "%%a"=="REMOTE_HOST" set "REMOTE_HOST=%%b"
)

set "CONN_MODE=LOCAL"
if /i not "!REMOTE_HOST!"=="127.0.0.1" if /i not "!REMOTE_HOST!"=="0.0.0.0" if /i not "!REMOTE_HOST!"=="localhost" (
    set "CONN_MODE=REMOTE"
    REM Сверка с реальными адресами локальных адаптеров (свой IP = локально)
    for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue).IPAddress"`) do (
        if /i "!REMOTE_HOST!"=="%%i" set "CONN_MODE=LOCAL"
    )
)

echo !CONN_MODE!
if "!CONN_MODE!"=="LOCAL" (exit /b 0) else (exit /b 1)
