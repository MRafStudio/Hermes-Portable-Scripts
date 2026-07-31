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

REM ============================================================================
REM   PowerShell wrapper (изоляция) — ТОЛЬКО В START.BAT!
REM ============================================================================
set "PS_WRAPPER=%TEMP%\ps_wrapper.bat"
(
    echo @echo off
    echo set "LOCALAPPDATA=%DATA_DIR%\localappdata"
    echo set "APPDATA=%DATA_DIR%\appdata"
    echo set "TEMP=%TEMP%"
    echo set "TMP=%TMP%"
    echo set "HOME=%HOME%"
    echo set "USERPROFILE=%USERPROFILE%"
    echo powershell -NoProfile -NonInteractive %%*
) > "%PS_WRAPPER%"

for /f "usebackq" %%a in (`%PS_WRAPPER% -Command "Write-Host ([char]27) -NoNewline"`) do set "ESC=%%a"

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

echo.
echo %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановка / Обновление компонентов%ESC%[0m
echo %ESC%[1;37m[2]%ESC%[0m %ESC%[1mИнструменты%ESC%[0m
echo.
echo %ESC%[1;37m[5]%ESC%[0m %ESC%[36mHermes — Варианты запуска%ESC%[0m

REM Быстрый запуск Desktop — только если собран
if !DESKTOP_INSTALLED! equ 1 (
    echo %ESC%[1;6m[*]%ESC%[0m %ESC%[32mБыстрый запуск Hermes Desktop%ESC%[0m
    echo.
)

echo %ESC%[1;37m[0]%ESC%[0m %ESC%[1mВыход%ESC%[0m
echo.

set "choice=INVALID"
if !DESKTOP_INSTALLED! equ 1 (
    set /p "choice=%ESC%[33mВыберите действие (0-2, 5, Enter для быстрого запуска): %ESC%[0m"
) else (
    set /p "choice=%ESC%[33mВыберите действие (0-2, 5): %ESC%[0m"
)

set "choice=%choice: =%"
if "%choice%"=="INVALID" goto launch

if "%choice%"=="" goto launch
if "%choice%"=="*" goto launch
if "%choice%"=="1" goto setup
if "%choice%"=="2" goto dev_tools

if "%choice%"=="5" goto launch_options
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

:launch
if !DESKTOP_INSTALLED! equ 1 (
    cls
    echo.
    echo %ESC%[1;33m-%ESC%[0m %ESC%[1mЗапуск Hermes Desktop...%ESC%[0m
    echo.
    call "%SCRIPTS_DIR%\Start-Hermes-Desktop.bat" 1
    goto menu
) else (
    cls
    echo.
    echo %ESC%[1;31m[ОШИБКА] Desktop App не собран.%ESC%[0m
    echo %ESC%[33m Запустите установку через пункт меню [1]%ESC%[0m
    echo.
    pause
    goto menu
)

:exit
popd
exit /b 0