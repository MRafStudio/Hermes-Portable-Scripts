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
echo  %ESC%[1;36m##%ESC%[0m                 %ESC%[1;37mHermes Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление%ESC%[0m               %ESC%[1;36m##%ESC%[0m
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

REM ============================================================================
REM   Вывод меню
REM ============================================================================

if !DESKTOP_INSTALLED! equ 0 (
    echo   %ESC%[1;33mНичего не установлено. Выберите действие:%ESC%[0m
    echo.
    echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1;33mУстановить Hermes Desktop%ESC%[0m
    echo.
    echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
    echo.
    set "choice="
    set /p "choice=%ESC%[33mВыберите действие: %ESC%[0m"

    set "choice=!choice: =!"
    if "!choice!"=="" goto menu
    if "!choice!"=="1" goto install_desktop
    if "!choice!"=="0" goto exit
    goto menu
)

echo   %ESC%[1;33mУстановленные компоненты:%ESC%[0m
if !DESKTOP_INSTALLED! equ 1 (
    echo     %ESC%[1;32m+%ESC%[0m Desktop App %ESC%[2m^(Hermes.exe^)%ESC%[0m
) else (
    echo     %ESC%[1;33m.%ESC%[0m Desktop App %ESC%[2m^(не собран^)%ESC%[0m
)
echo.
echo   %ESC%[1;33mВыберите действие:%ESC%[0m
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановить / Обновить Hermes Desktop%ESC%[0m

echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие: %ESC%[0m"

set "choice=!choice: =!"
if "!choice!"=="" goto menu
if "!choice!"=="1" goto install_desktop
if "!choice!"=="0" goto exit
goto menu

:install_desktop
cls
echo.
echo   %ESC%[1;33m-%ESC%[0m %ESC%[1mЗапуск установки Hermes Desktop...%ESC%[0m
call "%SCRIPTS_DIR%\InstallOrUpdate-Desktop.bat" 0
goto menu

:exit
exit /b 0