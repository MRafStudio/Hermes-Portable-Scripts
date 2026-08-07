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
REM   Определяем Desktop EXE
REM ============================================================================
set "DESKTOP_EXE="
for %%P in (
    "%REPO_DIR%\apps\desktop\release\win-unpacked\Hermes.exe"
    "%REPO_DIR%\apps\desktop\release\win-x64-unpacked\Hermes.exe"
    "%REPO_DIR%\apps\desktop\release\win-ia32-unpacked\Hermes.exe"
    "%REPO_DIR%\apps\desktop\release\win-arm64-unpacked\Hermes.exe"
) do if exist "%%P" set "DESKTOP_EXE=%%P"

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
echo %ESC%[1;37m[1] %ESC%[0m %ESC%[1mHermes setup%ESC%[0m                      %ESC%[2m— мастер первичной настройки%ESC%[0m
echo %ESC%[1;37m[2] %ESC%[0m %ESC%[1mHermes model%ESC%[0m                      %ESC%[2m— выбрать модель и провайдера%ESC%[0m
echo %ESC%[1;37m[3] %ESC%[0m %ESC%[1mHermes tools%ESC%[0m                      %ESC%[2m— настроить инструменты%ESC%[0m
echo.
echo %ESC%[1;37m[4] %ESC%[0m %ESC%[1mHermes CLI (локально)%ESC%[0m             %ESC%[2m— начать диалог в терминале%ESC%[0m
echo %ESC%[1;37m[5] %ESC%[0m %ESC%[1mHermes — Dashboard%ESC%[0m                %ESC%[2m— запустить веб-панель%ESC%[0m
if defined DESKTOP_EXE (
    echo %ESC%[1;37m[6] %ESC%[0m %ESC%[1mHermes — Desktop%ESC%[0m                 %ESC%[2m— запустить графическую версию%ESC%[0m
)
echo.
echo %ESC%[1;37m[7] %ESC%[0m %ESC%[1mHermes gateway%ESC%[0m                    %ESC%[2m— запустить шлюз (Telegram, Discord)%ESC%[0m
echo %ESC%[1;37m[8] %ESC%[0m %ESC%[1mHermes doctor%ESC%[0m                     %ESC%[2m— диагностика проблем%ESC%[0m
echo.
echo %ESC%[1;37m[0] %ESC%[0m %ESC%[1mВыход в главное меню%ESC%[0m
echo.

REM ============================================================================
REM   Получение выбора пользователя
REM ============================================================================
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-9): %ESC%[0m"

set "choice=%choice: =%"

if "%choice%"=="" goto menu
if "%choice%"=="0" goto exit

REM ============================================================================
REM   Выполнение выбранного действия
REM ============================================================================

REM --- [1] Hermes setup ---
if "%choice%"=="1" (
    cls
    echo %ESC%[1;33mЗапуск: Hermes setup%ESC%[0m
    echo.
    "%REPO_DIR%\venv\Scripts\hermes.exe" setup
    echo.
    pause
    goto menu
)

REM --- [2] Hermes model ---
if "%choice%"=="2" (
    cls
    echo %ESC%[1;33mЗапуск: Hermes model%ESC%[0m
    echo.
    "%REPO_DIR%\venv\Scripts\hermes.exe" model
    echo.
    pause
    goto menu
)

REM --- [3] Hermes tools ---
if "%choice%"=="3" (
    cls
    echo %ESC%[1;33mЗапуск: Hermes tools%ESC%[0m
    echo.
    "%REPO_DIR%\venv\Scripts\hermes.exe" tools
    echo.
    pause
    goto menu    
)

REM --- [4] Hermes — Interactive CLI ---
if "%choice%"=="4" (
    cls
    echo %ESC%[1;33mЗапуск: Hermes — Interactive CLI%ESC%[0m
    echo.
    call "%REPO_DIR%\venv\Scripts\hermes.exe"
    goto menu
)

REM --- [5] Hermes — Dashboard ---
if "%choice%"=="5" (
    cls
    echo %ESC%[1;33mЗапуск: Hermes — Dashboard%ESC%[0m
    echo.
    call "%SCRIPTS_DIR%\Start-Hermes-Web.bat"
    echo.
    pause
    goto menu
)

REM --- [6] Hermes — Desktop ---
if "%choice%"=="6" (
    cls
    echo %ESC%[1;33mЗапуск: Hermes — Desktop%ESC%[0m
    echo.
    call "%SCRIPTS_DIR%\Start-Hermes-Desktop.bat"
    echo.
    pause
    goto menu
)

REM --- [7] Hermes gateway ---
if "%choice%"=="7" (
    cls
    echo %ESC%[1;33mЗапуск: Hermes gateway%ESC%[0m
    echo.
    "%REPO_DIR%\venv\Scripts\hermes.exe" gateway
    echo.
    pause
    goto menu
)

REM --- [8] Hermes doctor ---
if "%choice%"=="8" (
    cls
    echo %ESC%[1;33mЗапуск: Hermes doctor%ESC%[0m
    echo.
    "%REPO_DIR%\venv\Scripts\hermes.exe" doctor
    echo.
    pause
    goto menu
)

REM Если ввели что-то левое — возвращаем меню
goto menu

REM ============================================================================
REM   Выход
REM ============================================================================
:exit
exit /b 0
