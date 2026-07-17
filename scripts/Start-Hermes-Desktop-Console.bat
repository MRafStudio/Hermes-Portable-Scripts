@REM scripts\Start-Hermes-Desktop-Console.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "HERMES_EXE=%HERMES_HOME%\hermes-agent\apps\desktop\release\win-unpacked\Hermes.exe"

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

"%HERMES_EXE%"

echo.
echo  --------------------------------------------------------------------------------
echo   Hermes Desktop завершён. [%date% %time%]
echo  --------------------------------------------------------------------------------
echo.
exit /b 0