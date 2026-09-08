@REM scripts\Restart-Hermes-Service.bat
@REM Перезапуск обеих служб инстанса Hermes (dashboard + messenger gateway).
@REM stop/start через родные sc-команды (не nssm!) — nssm не может открыть
@REM службу с пробелами/скобками в имени ("OpenService: 2").
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cls

title Перезапуск службы Hermes

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Определяем имя dashboard-службы: параметр %1 или первая найденная Hermes*
REM ============================================================================
set "SERVICE_NAME=%~1"
if not defined SERVICE_NAME call "%SCRIPTS_DIR%\Find-Hermes-Service.bat" "%ROOT_DIR%" <nul

REM Имя messenger-gateway службы (всегда вычисляется из каталога)
set "GW_SVC=HermesMessengerGateway (%ROOT_DIR:\=_%)"

echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                          %ESC%[1;37mПерезапуск службы Hermes%ESC%[0m                          %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка прав администратора (stop/start служб требуют админа).
REM   Если не админ — эскалируемся через UAC и перезапускаем себя.
REM ============================================================================
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  Требуются права администратора — запрашиваю UAC...%ESC%[0m
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process cmd -Verb RunAs -ArgumentList '/c','""%~f0"" %~1' -Wait } catch { exit 1 }"
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m[ОШИБКА] UAC отклонён — перезапуск служб отменён.%ESC%[0m
        echo.
        pause
    )
    exit /b 1
)

echo   %ESC%[1;33m- %ESC%[0mПерезапуск служб инстанса Hermes:
if defined SERVICE_NAME echo     %ESC%[2m  * !SERVICE_NAME!%ESC%[0m
echo     %ESC%[2m  * !GW_SVC!%ESC%[0m
echo.

REM ============================================================================
REM   :restart_one "<имя>" — stop, дождаться STOPPED, start, дождаться RUNNING
REM ============================================================================
call :restart_one "!SERVICE_NAME!" "Hermes"
call :restart_one "!GW_SVC!" "шлюзов"

echo.
pause
exit /b 0

:restart_one
set "SVC=%~1"
set "SVC_LABEL=%~2"

echo   %ESC%[1;33m- %ESC%[0mСлужба %SVC_LABEL% "!SVC!"...

REM --- существует ли ---
sc query "!SVC!" >nul 2>&1
if !errorlevel! neq 0 (
    echo     %ESC%[1;33m.  не существует — пропускаю.%ESC%[0m
    exit /b 0
)

REM --- stop (если запущена) ---
sc query "!SVC!" 2>nul | findstr /i "RUNNING START_PENDING" >nul 2>&1
if !errorlevel! equ 0 (
    echo     %ESC%[2m  Останавливаю...%ESC%[0m
    sc stop "!SVC!" >nul 2>&1
    set /a WT=0
    :wait_stop_r
    sc query "!SVC!" 2>nul | findstr /i "STOPPED" >nul 2>&1
    if !errorlevel! equ 0 goto stopped_r
    set /a WT+=1
    if !WT! lss 30 (
        timeout /t 1 /nobreak >nul 2>&1
        goto wait_stop_r
    )
    :stopped_r
    sc query "!SVC!" 2>nul | findstr /i "RUNNING" >nul 2>&1
    if !errorlevel! equ 0 (
        echo     %ESC%[1;31m  ВНИМАНИЕ: служба не остановилась.%ESC%[0m
        exit /b 1
    )
    echo     %ESC%[1;32m  + Остановлена.%ESC%[0m
)

REM --- start ---
echo     %ESC%[2m  Запускаю...%ESC%[0m
sc start "!SVC!" >nul 2>&1
set /a WT=0
:wait_run_r
sc query "!SVC!" 2>nul | findstr /i "RUNNING" >nul 2>&1
if !errorlevel! equ 0 goto running_r
set /a WT+=1
if !WT! lss 60 (
    timeout /t 1 /nobreak >nul 2>&1
    goto wait_run_r
)
:running_r
sc query "!SVC!" 2>nul | findstr /i "RUNNING" >nul 2>&1
if !errorlevel! equ 0 (
    echo     %ESC%[1;32m  + Служба %SVC_LABEL% "!SVC!" перезапущена и работает.%ESC%[0m
) else (
    echo     %ESC%[1;33m  ВНИМАНИЕ: служба %SVC_LABEL% "!SVC!" не запустилась. Лог: %HERMES_HOME%\..\temp%ESC%[0m
)
echo  --------------------------------------------------------------------------------
exit /b 0
