@REM scripts\Connect-Guide.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Гайд: подключение к Hermes с другого компьютера

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "DATA_DIR=%ROOT_DIR%\data"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m       %ESC%[1;37mГайд: подключение к Hermes с другого компьютера%ESC%[0m       %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 0: Проверки на этом (серверном) компьютере
REM ============================================================================
echo  %ESC%[1;33m[0/4] Проверки на этом компьютере...%ESC%[0m
echo.

REM --- 0.1: Служба ЭТОГО инстанса (по описанию с ROOT_DIR)? ---
set "SERVICE_NAME="
call "%SCRIPTS_DIR%\Find-Hermes-Service.bat" "%ROOT_DIR%" <nul

if not defined SERVICE_NAME (
    echo   %ESC%[1;31m  [X] Служба Hermes не установлена!%ESC%[0m
    echo   %ESC%[33m      Установите: Start.bat -^> [1] -^> [2] Установить службу Hermes%ESC%[0m
    echo.
    pause
    exit /b 0
)

sc query "!SERVICE_NAME!" 2>nul | findstr /i "RUNNING" >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  [+] Служба "!SERVICE_NAME!": работает%ESC%[0m
) else (
    echo   %ESC%[1;31m  [X] Служба "!SERVICE_NAME!": НЕ работает%ESC%[0m
    echo   %ESC%[33m      Перезапустите: Start.bat -^> [1] -^> [4]%ESC%[0m
)

REM --- 0.2: Порт (определяем из конфигурации службы) ---
set "SERVICE_PORT=9119"
for /f "tokens=2 delims=:" %%p in ('sc qc "!SERVICE_NAME!" 2^>nul ^| findstr /i "BINARY_PATH_NAME"') do (
    set "BIN=%%p"
)
REM Достаём --port N из командной строки службы
if defined BIN (
    for /f "tokens=2" %%n in ('echo !BIN! ^| findstr /i /r "--port [0-9]*"') do set "SERVICE_PORT=%%n"
)
set "SERVICE_PORT=!SERVICE_PORT: =!"
if "!SERVICE_PORT!"=="" set "SERVICE_PORT=8642"

netstat -ano | findstr "0.0.0.0:!SERVICE_PORT! " >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  [+] Порт !SERVICE_PORT!: слушается на 0.0.0.0%ESC%[0m
) else (
    echo   %ESC%[1;31m  [X] Порт !SERVICE_PORT!: НЕ слушается на 0.0.0.0!%ESC%[0m
    echo   %ESC%[33m      Служба должна запускаться с --host 0.0.0.0. Проверьте лог:%ESC%[0m
    echo   %ESC%[33m      %DATA_DIR%\temp\service-!SERVICE_NAME!.log%ESC%[0m
)

REM --- 0.3: Firewall ---
netsh advfirewall firewall show rule name="Hermes !SERVICE_NAME! !SERVICE_PORT!" >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  [+] Правило брандмауэра: есть%ESC%[0m
) else (
    echo   %ESC%[1;33m  [.] Правило брандмауэра не найдено — откройте порт:
    echo   %ESC%[33m      Start.bat -^> [1] -^> [2] ^(или вручную netsh advfirewall ... localport=!SERVICE_PORT!^)%ESC%[0m
)

REM --- 0.4: IP-адреса сервера ---
echo.
echo   %ESC%[1;33m  IP-адреса этого компьютера ^(для подключения^):%ESC%[0m
for /f "tokens=2 delims=:" %%i in ('ipconfig ^| findstr /i "IPv4"') do (
    echo   %ESC%[1;32m    http://%%i:!SERVICE_PORT!%ESC%[0m
)

echo.
echo  --------------------------------------------------------------------------------
echo   %ESC%[1;33m[1/4] На домашнем компьютере: установите Hermes Desktop %ESC%[0m
echo       ^(та же сборка, что на сервере — из этого репозитория^)
echo.
echo   %ESC%[1;33m[2/4] Откройте приложение и перейдите:%ESC%[0m
echo       Settings -^> Connection -^> Remote
echo.
echo   %ESC%[1;33m[3/4] Укажите URL сервера:%ESC%[0m
echo       http://<IP-сервера>:!SERVICE_PORT!
echo       ^(IP из списка выше; для внешнего доступа — публичный IP/DNS + проброс порта на роутере^)
echo.
echo   %ESC%[1;33m[4/4] Авторизация:%ESC%[0m
echo       Логин/пароль задаются на сервере при установке службы
echo       ^(Start.bat -^> [1] -^> [2], шаг "Логин веб-доступа"^).
echo       Введите их в окне входа удалённого Desktop.
echo.
echo  --------------------------------------------------------------------------------
echo   %ESC%[2mСоветы:%ESC%[0m
echo   %ESC%[2m  - Для нескольких инстансов: разные имена служб и порты.%ESC%[0m
echo   %ESC%[2m  - Проверка соединения: netstat -ano ^| findstr :!SERVICE_PORT! ^(на сервере^)%ESC%[0m
echo   %ESC%[2m  - Логи службы: %DATA_DIR%\temp\service-*.log%ESC%[0m
echo  --------------------------------------------------------------------------------
echo.
pause
exit /b 0
