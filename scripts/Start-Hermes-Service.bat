@REM scripts\Start-Hermes-Service.bat
@REM Запуск служб инстанса Hermes (dashboard + messenger gateway) с UAC-элевацией.
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cls

title Запуск службы Hermes

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Определяем имя dashboard-службы: параметр %1 или первая найденная Hermes*
REM ============================================================================
set "SERVICE_NAME=%~1"
if not defined SERVICE_NAME call "%SCRIPTS_DIR%\Find-Hermes-Service.bat" "%ROOT_DIR%" <nul

set "GW_SVC=HermesMessengerGateway (%ROOT_DIR:\\=_%)"

echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                            %ESC%[1;37mЗапуск службы Hermes%ESC%[0m                           %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка прав администратора — если нет, эскалируемся через UAC
REM ============================================================================
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  Требуются права администратора — запрашиваю UAC...%ESC%[0m
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process cmd -Verb RunAs -ArgumentList '/c','\"\"%~f0\"\" %~1' -Wait } catch { exit 1 }"
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m[ОШИБКА] UAC отклонён — запуск отменён.%ESC%[0m
        echo.
        pause
    )
    exit /b 1
)

echo   %ESC%[1;33m- %ESC%[0mЗапуск служб инстанса Hermes:
if defined SERVICE_NAME echo     %ESC%[2m  * !SERVICE_NAME!%ESC%[0m
echo     %ESC%[2m  * !GW_SVC!%ESC%[0m
echo.

REM ============================================================================
REM   :start_one "<имя>" "<метка>" — start и дождаться RUNNING
REM ============================================================================
call :start_one "!SERVICE_NAME!" "Hermes"
call :start_one "!GW_SVC!" "шлюзов"

echo.
pause
exit /b 0

:start_one
set "SVC=%~1"
set "SVC_LABEL=%~2"

echo   %ESC%[1;33m- %ESC%[0mСлужба %SVC_LABEL% "!SVC!"...

sc query "!SVC!" >nul 2>&1
if !errorlevel! neq 0 (
    echo     %ESC%[1;33m.  не существует — пропускаю.%ESC%[0m
    exit /b 0
)

sc query "!SVC!" 2>nul | findstr /i "RUNNING" >nul 2>&1
if !errorlevel! equ 0 (
    echo     %ESC%[1;33m  уже запущена.%ESC%[0m
) else (
    echo     %ESC%[2m  Запускаю...%ESC%[0m
    sc start "!SVC!" >nul 2>&1
    set /a WT=0
    :wait_run
    sc query "!SVC!" 2>nul | findstr /i "RUNNING" >nul 2>&1
    if !errorlevel! equ 0 goto running
    set /a WT+=1
    if !WT! lss 60 (
        timeout /t 1 /nobreak >nul 2>&1
        goto wait_run
    )
    :running
    sc query "!SVC!" 2>nul | findstr /i "RUNNING" >nul 2>&1
    if !errorlevel! equ 0 (
        echo     %ESC%[1;32m  + Служба %SVC_LABEL% "!SVC!" запущена и работает.%ESC%[0m
    ) else (
        echo     %ESC%[1;31m  ВНИМАНИЕ: служба %SVC_LABEL% "!SVC!" не запустилась.%ESC%[0m
    )
)
echo  --------------------------------------------------------------------------------
exit /b 0
