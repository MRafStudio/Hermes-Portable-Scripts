@echo off
chcp 65001 >nul
title Hermes — Варианты запуска

REM ============================================================================
REM   Проверка наличия Hermes CLI
REM ============================================================================
if not exist "%HERMES_HOME%\hermes\hermes.exe" (
    echo %ESC%[1;31m[ОШИБКА] Hermes CLI не найден. Убедитесь, что установлен Hermes Agent.%ESC%[0m
    pause
    exit /b 1
)

REM ============================================================================
REM   Вывод списка вариантов запуска
REM ============================================================================
cls
echo.
echo %ESC%[1;36m################################################################################%ESC%[0m
echo %ESC%[1;36m##                                                                            ##%ESC%[0m
echo %ESC%[1;36m##%ESC%[0m %ESC%[1;37m             Hermes — Варианты запуска%ESC%[0m                 %ESC%[1;36m##%ESC%[0m
echo %ESC%[1;36m##                                                                            ##%ESC%[0m
echo %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo %ESC%[1;37m[1]%ESC%[0m %ESC%[1mhermes — Interactive CLI — начать диалог%ESC%[0m
echo %ESC%[1;37m[2]%ESC%[0m %ESC%[1mhermes model — выбрать модель и провайдера%ESC%[0m
echo %ESC%[1;37m[3]%ESC%[0m %ESC%[1mhermes tools — настроить инструменты%ESC%[0m
echo %ESC%[1;37m[4]%ESC%[0m %ESC%[1mhermes config set — установить значение конфига%ESC%[0m
echo %ESC%[1;37m[5]%ESC%[0m %ESC%[1mhermes config get — показать значение конфига%ESC%[0m
echo %ESC%[1;37m[6]%ESC%[0m %ESC%[1mhermes gateway — запустить шлюз (Telegram, Discord и т.д.)%ESC%[0m
echo %ESC%[1;37m[7]%ESC%[0m %ESC%[1mhermes setup — запустить мастер настройки%ESC%[0m
echo %ESC%[1;37m[8]%ESC%[0m %ESC%[1mhermes claw migrate — миграция с OpenClaw%ESC%[0m
echo %ESC%[1;37m[9]%ESC%[0m %ESC%[1mhermes update — обновить Hermes Agent%ESC%[0m
echo %ESC%[1;37m[10]%ESC%[0m %ESC%[1mhermes doctor — диагностика проблем%ESC%[0m
echo.
echo %ESC%[1;37m[0]%ESC%[0m %ESC%[1mВыход%ESC%[0m
echo.

REM ============================================================================
REM   Получение выбора пользователя
REM ============================================================================
set "choice=INVALID"
set /p "choice=%ESC%[33mВыберите действие (0-10): %ESC%[0m"

set "choice=%choice: =%"

REM ============================================================================
REM   Выполнение выбранного действия
REM ============================================================================
if "%choice%"=="INVALID" goto menu

if "%choice%"=="" goto menu

if "%choice%"=="0" goto exit

if "%choice%"=="1" (
    echo %ESC%[1;33mЗапуск: hermes%ESC%[0m
    call "%HERMES_HOME%\hermes\hermes.exe"
    goto menu
)

if "%choice%"=="2" (
    echo %ESC%[1;33mЗапуск: hermes model%ESC%[0m
    call "%HERMES_HOME%\hermes\hermes.exe" model
    goto menu
)

if "%choice%"=="3" (
    echo %ESC%[1;33mЗапуск: hermes tools%ESC%[0m
    call "%HERMES_HOME%\hermes\hermes.exe" tools
    goto menu
)

if "%choice%"=="4" (
    echo %ESC%[1;33mЗапуск: hermes config set%ESC%[0m
    call "%HERMES_HOME%\hermes\hermes.exe" config set
    goto menu
)

if "%choice%"=="5" (
    echo %ESC%[1;33mЗапуск: hermes config get%ESC%[0m
    call "%HERMES_HOME%\hermes\hermes.exe" config get
    goto menu
)

if "%choice%"=="6" (
    echo %ESC%[1;33mЗапуск: hermes gateway%ESC%[0m
    call "%HERMES_HOME%\hermes\hermes.exe" gateway
    goto menu
)

if "%choice%"=="7" (
    echo %ESC%[1;33mЗапуск: hermes setup%ESC%[0m
    call "%HERMES_HOME%\hermes\hermes.exe" setup
    goto menu
)

if "%choice%"=="8" (
    echo %ESC%[1;33mЗапуск: hermes claw migrate%ESC%[0m
    call "%HERMES_HOME%\hermes\hermes.exe" claw migrate
    goto menu
)

if "%choice%"=="9" (
    echo %ESC%[1;33mЗапуск: hermes update%ESC%[0m
    call "%HERMES_HOME%\hermes\hermes.exe" update
    goto menu
)

if "%choice%"=="10" (
    echo %ESC%[1;33mЗапуск: hermes doctor%ESC%[0m
    call "%HERMES_HOME%\hermes\hermes.exe" doctor
    goto menu
)

:menu
goto menu

:exit
exit /b 0