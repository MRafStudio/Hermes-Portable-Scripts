@REM scripts\Remove-Hermes-Service.bat
@REM Удаление обеих служб инстанса Hermes (dashboard + messenger gateway).
@REM ВАЖНО: остановка и удаление через родные sc-команды (не nssm!) — nssm не
@REM может открыть службу с пробелами/скобками в имени ("OpenService: 2").
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cls

title Удаление службы Hermes

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
REM   Имя dashboard-службы: параметр %1 или первая найденная Hermes*
REM ============================================================================
set "SERVICE_NAME=%~1"
if not defined SERVICE_NAME call "%SCRIPTS_DIR%\Find-Hermes-Service.bat" "%ROOT_DIR%" <nul

REM Имя messenger-gateway службы (всегда вычисляется из каталога)
set "GW_SVC=HermesMessengerGateway (%ROOT_DIR:\=_%)"

echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                           %ESC%[1;37mУдаление службы Hermes%ESC%[0m                           %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка прав администратора (stop/delete служб требуют админа).
REM   Если не админ — эскалируемся через UAC и перезапускаем себя.
REM ============================================================================
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  Требуются права администратора — запрашиваю UAC...%ESC%[0m
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process cmd -Verb RunAs -ArgumentList '/c','""%~f0"" %~1' -Wait } catch { exit 1 }"
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m[ОШИБКА] UAC отклонён — удаление службы отменено.%ESC%[0m
        echo.
        pause
    )
    exit /b 1
)

REM ============================================================================
REM   Что удаляем (каждая служба — отдельной проверкой, без общего списка,
REM   чтобы не разбить имена с пробелами по словам)
REM ============================================================================
set "HAVE_ANY=0"
if defined SERVICE_NAME (
    sc query "!SERVICE_NAME!" >nul 2>&1
    if !errorlevel! equ 0 set "HAVE_ANY=1"
)
sc query "!GW_SVC!" >nul 2>&1
if !errorlevel! equ 0 set "HAVE_ANY=1"

if !HAVE_ANY! equ 0 (
    echo   %ESC%[1;33m. Службы Hermes не найдены — удалять нечего.%ESC%[0m
    echo.
    pause
    exit /b 0
)

echo   %ESC%[1;33m- %ESC%[0mБудут удалены службы:
if defined SERVICE_NAME (
    sc query "!SERVICE_NAME!" >nul 2>&1
    if !errorlevel! equ 0 echo     %ESC%[33m  * !SERVICE_NAME!%ESC%[0m
)
sc query "!GW_SVC!" >nul 2>&1
if !errorlevel! equ 0 echo     %ESC%[33m  * !GW_SVC!%ESC%[0m
set /p "CONF=%ESC%[33mУдалить службы? (y/N): %ESC%[0m"
if /i not "!CONF!"=="y" (
    echo.
    pause
    exit /b 0
)

REM ============================================================================
REM   Удаляем каждую найденную службу: остановить -> дождаться -> удалить
REM ============================================================================
if defined SERVICE_NAME (
    sc query "!SERVICE_NAME!" >nul 2>&1
    if !errorlevel! equ 0 (
        echo.
        echo   %ESC%[1;33m- %ESC%[0mСлужба "!SERVICE_NAME!":
        call :delete_one "!SERVICE_NAME!"
    )
)
sc query "!GW_SVC!" >nul 2>&1
if !errorlevel! equ 0 (
    echo.
    echo   %ESC%[1;33m- %ESC%[0mСлужба "!GW_SVC!":
    call :delete_one "!GW_SVC!"
)

echo   %ESC%[2mПримечание: правило брандмауэра осталось. Удалить: netsh advfirewall firewall delete rule name="Hermes ..."%ESC%[0m
echo.
pause
exit /b 0

REM ============================================================================
REM   :delete_one "<имя службы>" — остановить, дождаться STOPPED, удалить
REM ============================================================================
:delete_one
set "SVC=%~1"

REM --- 1. Проверяем, существует ли ---
sc query "!SVC!" >nul 2>&1
if !errorlevel! neq 0 (
    echo     %ESC%[1;33m.  не существует — пропускаю.%ESC%[0m
    exit /b 0
)

REM --- 2. Останавливаем (если запущена) ---
sc query "!SVC!" 2>nul | findstr /i "RUNNING START_PENDING STOP_PENDING" >nul 2>&1
if !errorlevel! equ 0 (
    echo     %ESC%[2m  Останавливаю...%ESC%[0m
    sc stop "!SVC!" >nul 2>&1
    REM --- ждём полной остановки (до 30 сек) ---
    set /a WT=0
    :wait_stop
    sc query "!SVC!" 2>nul | findstr /i "STOPPED" >nul 2>&1
    if !errorlevel! equ 0 goto stopped
    set /a WT+=1
    if !WT! lss 30 (
        timeout /t 1 /nobreak >nul 2>&1
        goto wait_stop
    )
    :stopped
    sc query "!SVC!" 2>nul | findstr /i "RUNNING" >nul 2>&1
    if !errorlevel! equ 0 (
        echo     %ESC%[1;31m  ВНИМАНИЕ: служба не остановилась.%ESC%[0m
        exit /b 1
    )
    echo     %ESC%[1;32m  + Служба остановлена.%ESC%[0m
) else (
    echo     %ESC%[2m  Уже остановлена.%ESC%[0m
)

REM --- 3. Удаляем ---
sc delete "!SVC!" >nul 2>&1
timeout /t 2 /nobreak >nul 2>&1

REM --- 4. Проверка ---
sc query "!SVC!" >nul 2>&1
if !errorlevel! neq 0 (
    echo     %ESC%[1;32m  + Служба "!SVC!" удалена.%ESC%[0m
) else (
    echo     %ESC%[1;31m  ВНИМАНИЕ: служба "!SVC!" всё ещё существует — удалите вручную: sc delete "!SVC!"%ESC%[0m
)
exit /b 0
