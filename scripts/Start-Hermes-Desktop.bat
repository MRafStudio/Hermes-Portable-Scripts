@REM scripts\Start-Hermes-Desktop.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Запуск Hermes

REM ============================================================================
REM   Определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "NODE_DIR=%HERMES_HOME%\node"
set "DESKTOP_DIR=%REPO_DIR%\apps\desktop"
set "HERMES_EXE=%DESKTOP_DIR%\release\win-unpacked\Hermes.exe"

REM ============================================================================
REM   REAL_LOCALAPPDATA — захватить ДО изоляции!
REM   (нужен для поиска глобального Node.js в профиле пользователя)
REM ============================================================================
set "REAL_LOCALAPPDATA=%LOCALAPPDATA%"

REM ============================================================================
REM   Определение Node.js (глобальный -> локальный) — как во всех скриптах
REM ============================================================================
REM --- 1. Глобальный Node.js: стандартные пути (ПРИОРИТЕТ) ---
if exist "%ProgramFiles%\nodejs\node.exe" set "GLOBAL_NODE=%ProgramFiles%\nodejs"
if not defined GLOBAL_NODE if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "GLOBAL_NODE=%ProgramFiles(x86)%\nodejs"
if not defined GLOBAL_NODE if exist "%REAL_LOCALAPPDATA%\Programs\nodejs\node.exe" set "GLOBAL_NODE=%REAL_LOCALAPPDATA%\Programs\nodejs"

REM --- 2. Глобальный Node.js: реестр (HKLM + WOW6432Node + HKCU) ---
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
    set "NODE_PATH=!GLOBAL_NODE!"
) else if exist "%NODE_DIR%\node.exe" (
    set "NODE_PATH=%NODE_DIR%"
)

REM ============================================================================
REM   ПОЛНАЯ ИЗОЛЯЦИЯ PATH — сразу, до любых операций!
REM   Node.js (если найден) — первым: глобальный в приоритете, иначе локальный
REM ============================================================================
if defined NODE_PATH (
    set "PATH=!NODE_PATH!;%HERMES_HOME%\bin;%ProgramFiles%\Git\cmd;%windir%\system32;%windir%;%windir%\System32\Wbem;%windir%\System32\WindowsPowerShell\v1.0"
) else (
    set "PATH=%HERMES_HOME%\bin;%ProgramFiles%\Git\cmd;%windir%\system32;%windir%;%windir%\System32\Wbem;%windir%\System32\WindowsPowerShell\v1.0"
)

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
REM   Получение ESC (стандартный трюк, без PowerShell)
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Проверка Hermes.exe
REM ============================================================================
if not exist "%HERMES_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] Hermes.exe не найден...%ESC%[0m
    echo   %ESC%[33m       Ожидалось: %HERMES_EXE%%ESC%[0m
    echo   %ESC%[33m       Сначала запустите InstallOrUpdate-Desktop.bat%ESC%[0m
    pause
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
if defined GLOBAL_NODE (
    echo   %ESC%[1;33mNODE:%ESC%[0m   %ESC%[2m!GLOBAL_NODE! ^(глобальный^)%ESC%[0m
) else if defined NODE_PATH (
    echo   %ESC%[1;33mNODE:%ESC%[0m   %ESC%[2m!NODE_PATH! ^(локальный^)%ESC%[0m
) else (
    echo   %ESC%[1;33mNODE:%ESC%[0m   %ESC%[2mне найден ^(для запуска не требуется^)%ESC%[0m
)
echo.
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1;32mЗапуск Hermes Desktop...%ESC%[0m
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo.

REM ============================================================================
REM   Запуск Hermes с изолированным окружением
REM   (start наследует текущее окружение — изоляция передаётся автоматически)
REM ============================================================================
start /min "Hermes Desktop Console" cmd /c "%SCRIPTS_DIR%\Start-Hermes-Desktop-Console.bat"

echo   %ESC%[1;32mHermes Desktop запущен%ESC%[0m
echo   %ESC%[1;32mОкно закроется через 3 секунды...%ESC%[0m
timeout /t 3 /nobreak >nul
exit /b 0