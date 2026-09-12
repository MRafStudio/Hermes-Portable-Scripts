@REM scripts\Start-Hermes-Desktop-Console.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

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
REM   Изоляция данных — обязательна и здесь!
REM   При запуске от Start-Hermes-Desktop.bat значения те же (идемпотентно),
REM   при ПРЯМОМ запуске — защищает профиль пользователя от записи.
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
if not exist "%USERPROFILE%" mkdir "%USERPROFILE%" 2>nul

REM ============================================================================
REM   Заголовок консоли
REM ============================================================================
title Hermes Desktop

cls
echo.
echo  ################################################################################
echo  ##                                                                            ##
echo  ##                    Hermes Desktop — Консоль вывода                         ##
echo  ##                                                                            ##
echo  ################################################################################
echo.
echo   Запуск: %HERMES_EXE%
echo   Время:  %date% %time%
echo.
echo   [Ctrl+C] — Прервать
echo   [Закрыть окно] — Завершить Hermes Desktop
echo.
echo  --------------------------------------------------------------------------------
echo.

REM ============================================================================
REM   Запуск Hermes Desktop
REM ============================================================================
if not exist "%HERMES_EXE%" (
    echo.
    echo   [ОШИБКА] Hermes.exe не найден.
    echo   Путь: %HERMES_EXE%
    echo.
    echo   Выполните полную установку через главное меню.
    echo.
    pause
    exit /b 1
)

REM ============================================================================
REM   ПРЕДОХРАНИТЕЛЬ: пустышки + маркер песочницы Chromium
REM   При запуске из Start-Hermes-Desktop.bat уже отработал; здесь — для прямого
REM   запуска этого файла. Файл: scripts\ps1\guard-hermes-desktop.ps1
REM ============================================================================
if not exist "%SCRIPTS_DIR%\ps1\guard-hermes-desktop.ps1" goto :guard_done
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps1\guard-hermes-desktop.ps1" -RootDir "%ROOT_DIR%"
if errorlevel 10 (
    echo.
    echo   Hermes уже запущен — второе окно не появится ^(single-instance^).
    echo   Окно поднято на передний план. Закройте текущий Hermes и запустите снова.
    echo.
    REM Пауза 5 с без timeout — timeout падает при перенаправленном вводе
    ping -n 6 127.0.0.1 >nul 2>&1
    exit /b 0
)
:guard_done

REM Рабочая директория Hermes — изолированный профиль data\home,
REM а не наследованный откуда попало (иначе сессии/файлы падают в системный профиль)!
REM --- Очистка логов: только текущий запуск ---
if exist "%APPDATA%\Hermes\logs\*.log" del /q "%APPDATA%\Hermes\logs\*.log" 2>nul

cd /d "%HOME%"

"%HERMES_EXE%"

echo.
echo  --------------------------------------------------------------------------------
echo   Hermes Desktop завершён. [%date% %time%]
echo  --------------------------------------------------------------------------------
echo.
exit /b 0