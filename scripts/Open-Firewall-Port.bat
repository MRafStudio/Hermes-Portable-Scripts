@REM scripts\Open-Firewall-Port.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cls

title Открытие порта в брандмауэре

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                        %ESC%[1;37mОткрытие порта в брандмауэре%ESC%[0m                        %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Порт (параметр %1 или запрос)
REM ============================================================================
set "SERVICE_PORT=%~1"
if not defined SERVICE_PORT (
    set /p "SERVICE_PORT=%ESC%[1mПорт для открытия%ESC%[0m %ESC%[2m[Enter = 9119]%ESC%[0m: "
    if "!SERVICE_PORT!"=="" set "SERVICE_PORT=9119"
)
if not "!SERVICE_PORT!"=="" set "SERVICE_PORT=!SERVICE_PORT: =!"

REM ============================================================================
REM   Имя правила (параметр %2 или автоматическое)
REM ============================================================================
set "RULE_NAME=%~2"
if not defined RULE_NAME set "RULE_NAME=Hermes !SERVICE_PORT!"

REM ============================================================================
REM   Проверка существующего правила (права администратора НЕ нужны)
REM ============================================================================
echo   %ESC%[1;33m- %ESC%[0mПроверяю существующие правила для порта %ESC%[1m!SERVICE_PORT!%ESC%[0m...
netsh advfirewall firewall show rule name=all | findstr /i "!SERVICE_PORT!" >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m+ Правило для порта !SERVICE_PORT! уже существует — порт открыт.%ESC%[0m
    echo   %ESC%[33m      Если удалённый доступ не работает — проверьте профиль сети ^(Частная^).%ESC%[0m
    echo.
    pause
    exit /b 0
)

REM ============================================================================
REM   Проверка прав администратора (нужны только для создания правила)
REM ============================================================================
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Правило для порта !SERVICE_PORT! не найдено — нужно создать.%ESC%[0m
    echo   %ESC%[33mТребуются права администратора — запустите от имени администратора.%ESC%[0m
    echo.
    pause
    exit /b 1
)

echo   %ESC%[1;33m- %ESC%[0mОткрываю TCP-порт %ESC%[1m!SERVICE_PORT!%ESC%[0m ^(правило: "!RULE_NAME!"^)...
netsh advfirewall firewall add rule name="!RULE_NAME!" dir=in action=allow protocol=TCP localport=!SERVICE_PORT!
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m+ Правило добавлено.%ESC%[0m
) else (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось добавить правило.%ESC%[0m
)
echo.
pause
exit /b 0
