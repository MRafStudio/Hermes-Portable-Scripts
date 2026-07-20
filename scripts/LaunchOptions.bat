@REM scripts\LaunchOptions.bat — Варианты запуска Hermes
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Hermes — Варианты запуска

REM ============================================================================
REM   Пути и изоляция
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "CONFIG_FILE=%SCRIPTS_DIR%\Config.ini"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"

REM Создаём изолированные папки
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Проверка наличия Hermes CLI
REM ============================================================================
if not exist "%REPO_DIR%\venv\Scripts\hermes.exe" (
    echo %ESC%[1;31m[ОШИБКА] Hermes CLI не найден.%ESC%[0m
    echo %ESC%[33m         Убедитесь, что установлен Hermes Agent.%ESC%[0m
    echo %ESC%[33m         Запустите установку через главное меню [1].%ESC%[0m
    pause
    exit /b 1
)

REM ============================================================================
REM   Вывод меню
REM ============================================================================
:menu
cls
echo.
echo %ESC%[1;36m################################################################################%ESC%[0m
echo %ESC%[1;36m##                                                                            ##%ESC%[0m
echo %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                Hermes AI Agent (Portable)%ESC%[0m — %ESC%[1;33mВарианты запуска%ESC%[0m              %ESC%[1;36m##%ESC%[0m
echo %ESC%[1;36m##                                                                            ##%ESC%[0m
echo %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo %ESC%[1;37m[1] %ESC%[0m %ESC%[1mhermes — Interactive CLI%ESC%[0m %ESC%[2m— начать диалог в терминале%ESC%[0m
echo %ESC%[1;37m[2] %ESC%[0m %ESC%[1mhermes model%ESC%[0m %ESC%[2m            — выбрать модель и провайдера%ESC%[0m
echo %ESC%[1;37m[3] %ESC%[0m %ESC%[1mhermes tools%ESC%[0m %ESC%[2m            — настроить инструменты%ESC%[0m
echo %ESC%[1;37m[4] %ESC%[0m %ESC%[1mhermes config set%ESC%[0m %ESC%[2m       — установить значение конфига%ESC%[0m
echo %ESC%[1;37m[5] %ESC%[0m %ESC%[1mhermes config get%ESC%[0m %ESC%[2m       — показать значение конфига%ESC%[0m
echo %ESC%[1;37m[6] %ESC%[0m %ESC%[1mhermes gateway%ESC%[0m %ESC%[2m          — запустить шлюз (Telegram, Discord)%ESC%[0m
echo %ESC%[1;37m[7] %ESC%[0m %ESC%[1mhermes setup%ESC%[0m %ESC%[2m            — запустить мастер настройки%ESC%[0m
echo %ESC%[1;37m[8] %ESC%[0m %ESC%[1mhermes claw migrate%ESC%[0m %ESC%[2m     — миграция с OpenClaw%ESC%[0m
echo %ESC%[1;37m[9] %ESC%[0m %ESC%[1mhermes update%ESC%[0m %ESC%[2m           — обновить Hermes Agent%ESC%[0m
echo %ESC%[1;37m[10]%ESC%[0m %ESC%[1mhermes doctor%ESC%[0m %ESC%[2m           — диагностика проблем%ESC%[0m
echo.
echo %ESC%[1;37m[0]%ESC%[0m %ESC%[1mВыход в главное меню%ESC%[0m
echo.

REM ============================================================================
REM   Получение выбора пользователя
REM ============================================================================
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-10): %ESC%[0m"

set "choice=%choice: =%"

if "%choice%"=="" goto menu
if "%choice%"=="0" goto exit

REM ============================================================================
REM   Выполнение выбранного действия
REM ============================================================================
if "%choice%"=="1" (
    cls
    echo %ESC%[1;33mЗапуск: hermes (Interactive CLI)%ESC%[0m
    call "%REPO_DIR%\venv\Scripts\hermes.exe"
    goto menu
)

if "%choice%"=="2" (
    cls
    echo %ESC%[1;33mЗапуск: hermes model%ESC%[0m
    call "%REPO_DIR%\venv\Scripts\hermes.exe" model
    goto menu
)

if "%choice%"=="3" (
    cls
    echo %ESC%[1;33mЗапуск: hermes tools%ESC%[0m
    call "%REPO_DIR%\venv\Scripts\hermes.exe" tools
    goto menu
)

if "%choice%"=="4" (
    cls
    echo %ESC%[1;33mЗапуск: hermes config set%ESC%[0m
    call "%REPO_DIR%\venv\Scripts\hermes.exe" config set
    goto menu
)

if "%choice%"=="5" (
    cls
    echo %ESC%[1;33mЗапуск: hermes config get%ESC%[0m
    call "%REPO_DIR%\venv\Scripts\hermes.exe" config get
    goto menu
)

if "%choice%"=="6" (
    cls
    echo %ESC%[1;33mЗапуск: hermes gateway%ESC%[0m
    call "%REPO_DIR%\venv\Scripts\hermes.exe" gateway
    goto menu
)

if "%choice%"=="7" (
    cls
    echo %ESC%[1;33mЗапуск: hermes setup%ESC%[0m
    call "%REPO_DIR%\venv\Scripts\hermes.exe" setup
    goto menu
)

if "%choice%"=="8" (
    cls
    echo %ESC%[1;33mЗапуск: hermes claw migrate%ESC%[0m
    call "%REPO_DIR%\venv\Scripts\hermes.exe" claw migrate
    goto menu
)

if "%choice%"=="9" (
    cls
    echo %ESC%[1;33mЗапуск: hermes update%ESC%[0m
    call "%REPO_DIR%\venv\Scripts\hermes.exe" update
    goto menu
)

if "%choice%"=="10" (
    cls
    echo %ESC%[1;33mЗапуск: hermes doctor%ESC%[0m
    call "%REPO_DIR%\venv\Scripts\hermes.exe" doctor
    goto menu
)

REM Если ввели что-то левое — возвращаем меню
goto menu

REM ============================================================================
REM   Выход
REM ============================================================================
:exit
exit /b 0
