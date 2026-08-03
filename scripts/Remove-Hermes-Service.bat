@REM scripts\Remove-Hermes-Service.bat
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
REM   Определяем имя службы: параметр %1 или первая найденная Hermes*
REM ============================================================================
set "SERVICE_NAME=%~1"
if not defined SERVICE_NAME call "%SCRIPTS_DIR%\Find-Hermes-Service.bat" "%ROOT_DIR%" <nul

echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                           %ESC%[1;37mУдаление службы Hermes%ESC%[0m                           %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

if not defined SERVICE_NAME (
    echo   %ESC%[1;33m. Служба Hermes не найдена — удалять нечего.%ESC%[0m
    echo.
    pause
    exit /b 0
)

sc query "!SERVICE_NAME!" >nul 2>&1
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m. Служба "!SERVICE_NAME!" не существует.%ESC%[0m
    echo.
    pause
    exit /b 0
)

echo   %ESC%[1;33m- %ESC%[0mСлужба найдена: %ESC%[1m!SERVICE_NAME!%ESC%[0m
set /p "CONF=%ESC%[33mУдалить службу "!SERVICE_NAME!"? ^(y/N^): %ESC%[0m"
if /i not "!CONF!"=="y" (
    echo.
    pause
    exit /b 0
)

REM ============================================================================
REM   Удаление: NSSM (если есть) или sc
REM ============================================================================
set "NSSM_EXE=%HERMES_HOME%\bin\nssm.exe"
if exist "%NSSM_EXE%" (
    "%NSSM_EXE%" stop "!SERVICE_NAME!" >nul 2>&1
    "%NSSM_EXE%" remove "!SERVICE_NAME!" confirm >nul 2>&1
) else (
    sc stop "!SERVICE_NAME!" >nul 2>&1
    sc delete "!SERVICE_NAME!" >nul 2>&1
)

REM Проверка
sc query "!SERVICE_NAME!" >nul 2>&1
if !errorlevel! neq 0 (
    echo   %ESC%[1;32m+ Служба "!SERVICE_NAME!" удалена.%ESC%[0m
) else (
    echo   %ESC%[1;33m  ВНИМАНИЕ: Служба всё ещё существует — удалите вручную: sc delete "!SERVICE_NAME!"%ESC%[0m
)

echo   %ESC%[2mПримечание: правило брандмауэра осталось. Удалить: netsh advfirewall firewall delete rule name="Hermes ..."%ESC%[0m
echo.
pause
exit /b 0
