@REM scripts\Open-Firewall-Port-Auto.bat — предложить открыть порт (занят → следующий свободный)
@REM Использование: call Open-Firewall-Port-Auto.bat <PORT> <RULE_BASE_NAME>
@REM   <PORT>             желаемый порт (например, 9119)
@REM   <RULE_BASE_NAME>   базовое имя правила (например, "Hermes Web") — добавится номер порта
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Параметры
REM ============================================================================
set "REQ_PORT=%~1"
if not defined REQ_PORT set "REQ_PORT=9119"
set "RULE_BASE=%~2"
if not defined RULE_BASE set "RULE_BASE=Hermes"

set "FREE_PORT=%REQ_PORT%"

REM ============================================================================
REM   Поиск свободного порта: REQ_PORT .. REQ_PORT+20
REM ============================================================================
set "FOUND=0"
for /l %%p in (1,1,20) do (
    if !FOUND! equ 0 (
        netstat -ano | findstr /c:":!FREE_PORT! " | findstr "LISTENING" >nul 2>&1
        if !errorlevel! neq 0 set "FOUND=1"
        if !FOUND! equ 0 set /a FREE_PORT+=1
    )
)
if !FOUND! equ 0 (
    echo   %ESC%[1;31m[ОШИБКА] Порт !REQ_PORT! и следующие 20 заняты — открытие порта пропущено.%ESC%[0m
    exit /b 0
)

REM ============================================================================
REM   Предложение
REM ============================================================================
if "!FREE_PORT!"=="!REQ_PORT!" (
    echo   %ESC%[1;33m- %ESC%[0mОткрыть порт !FREE_PORT! в брандмауэре для доступа с других ПК?
) else (
    echo   %ESC%[1;33m- %ESC%[0mПорт !REQ_PORT! занят другим экземпляром Hermes.
    echo   %ESC%[1;33m- %ESC%[0mОткрыть вместо него свободный порт !FREE_PORT!?
)
set "OPEN_PORT="
set /p "OPEN_PORT=%ESC%[33m      [Enter = да, N = нет]: %ESC%[0m"
if /i "!OPEN_PORT!"=="N" (
    echo   %ESC%[2m      Порт не открыт.%ESC%[0m
    exit /b 0
)

REM ============================================================================
REM   Проверка прав администратора
REM ============================================================================
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo   %ESC%[33m      Установка запущена НЕ от администратора — порт не открыт.%ESC%[0m
    echo   %ESC%[33m      Сделайте позже: Start.bat -^> [1] -^> [7]%ESC%[0m
    exit /b 0
)

REM ============================================================================
REM   Создание правила
REM ============================================================================
netsh advfirewall firewall add rule name="!RULE_BASE! !FREE_PORT!" dir=in action=allow protocol=TCP localport=!FREE_PORT! >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m+ %ESC%[0mПравило брандмауэра добавлено: "!RULE_BASE! !FREE_PORT!"
) else (
    echo   %ESC%[1;31m  !   Не удалось добавить правило.%ESC%[0m
)
exit /b 0
