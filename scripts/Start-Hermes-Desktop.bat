@REM scripts\Start-Hermes-Desktop.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Запуск Hermes

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "NODE_DIR=%HERMES_HOME%\node"
set "DESKTOP_DIR=%REPO_DIR%\apps\desktop"
set "HERMES_EXE=%DESKTOP_DIR%\release\win-unpacked\Hermes.exe"

REM ============================================================================
REM   ПОЛНАЯ ИЗОЛЯЦИЯ PATH — сразу, до любых операций!
REM ============================================================================
set "PATH=%NODE_DIR%;%HERMES_HOME%\bin;C:\Program Files\Git\cmd;C:\WINDOWS\system32;C:\WINDOWS;C:\WINDOWS\System32\Wbem;C:\WINDOWS\System32\WindowsPowerShell\v1.0"

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

REM ============================================================================
REM   Получение ESC (без PS_WRAPPER!)
REM ============================================================================
for /f %%a in ('powershell -NoProfile -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

REM ============================================================================
REM   Проверка Hermes.exe
REM ============================================================================
if not exist "%HERMES_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] Hermes.exe не найден...%ESC%[0m
    echo   %ESC%[33m       Ожидалось: %HERMES_EXE%%ESC%[0m
    echo   %ESC%[33m       Сначала запустите InstallOrUpdate-Desktop.bat%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                 %ESC%[1;37mHermes Portable%ESC%[0m   —   %ESC%[1;33mDesktop App%ESC%[0m                          %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo   %ESC%[1;33mEXE:%ESC%[0m    %ESC%[2m%HERMES_EXE%%ESC%[0m
echo   %ESC%[1;33mDATA:%ESC%[0m   %ESC%[2m%DATA_DIR%%ESC%[0m
echo   %ESC%[1;33mTEMP:%ESC%[0m   %ESC%[2m%TEMP%%ESC%[0m
echo   %ESC%[1;33mAPP:%ESC%[0m    %ESC%[2m%APPDATA%%ESC%[0m
echo.
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1;32mЗапуск Hermes Desktop...%ESC%[0m
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo.

REM ============================================================================
REM   Запуск Hermes с изолированным окружением
REM ============================================================================
set "HERMES_HOME=%HERMES_HOME%"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"

REM Запускаем в отдельном окне
start /min "Hermes Desktop Console" cmd /c "%~dp0Start-Hermes-Desktop-Console.bat"

echo   %ESC%[1;32mHermes Desktop запущен%ESC%[0m
echo   %ESC%[1;32mОкно закроется через 3 секунды...%ESC%[0m
timeout /t 3 /nobreak >nul
exit /b 0