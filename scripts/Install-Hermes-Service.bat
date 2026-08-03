@REM scripts\Install-Hermes-Service.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
cls

title Установка службы Hermes

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DATA_DIR=%ROOT_DIR%\data"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "PYTHONIOENCODING=utf-8"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul

echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                  %ESC%[1;37mУстановка службы Hermes%ESC%[0m                  %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка прав администратора (служба + firewall)
REM ============================================================================
net session >nul 2>&1
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Требуются права администратора!%ESC%[0m
    echo   %ESC%[33mЗапустите Start.bat от имени администратора ^(ПКМ -^> Запуск от имени администратора^).%ESC%[0m
    echo.
    pause
    exit /b 1
)

REM ============================================================================
REM   Проверка установленного Hermes
REM ============================================================================
set "HERMES_EXE=%REPO_DIR%\apps\desktop\release\win-unpacked\Hermes.exe"
if not exist "%HERMES_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] Hermes не установлен.%ESC%[0m
    echo   %ESC%[33mСначала выполните [1] Установить / Обновить Hermes Desktop.%ESC%[0m
    echo.
    pause
    exit /b 1
)

set "PYTHON_EXE=%REPO_DIR%\venv\Scripts\python.exe"
if not exist "%PYTHON_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] venv Python не найден: %PYTHON_EXE%%ESC%[0m
    echo   %ESC%[33mПереустановите компоненты через [1].%ESC%[0m
    echo.
    pause
    exit /b 1
)

echo   %ESC%[1;32m+%ESC%[0m Hermes найден: %HERMES_EXE%
echo   %ESC%[1;32m+%ESC%[0m Python: %PYTHON_EXE%
echo.

REM ============================================================================
REM   Имя службы: "HermesGateway (путь)" — уникально для каждого инстанса!
REM   ВАЖНО: Windows ЗАПРЕЩАЕТ "\" и "/" в имени службы — путь заменяем на "_"
REM   (например: "HermesGateway (D_Hermes)"). Полный путь — в описании службы.
REM   Параметр %1 = имя (для автоматизации; интерактивно — запрос).
REM ============================================================================
set "SERVICE_NAME=%~1"
if not defined SERVICE_NAME (
    set "SERVICE_NAME=HermesGateway (%ROOT_DIR:\=_%)"
    set /p "SERVICE_NAME=%ESC%[1mИмя службы%ESC%[0m %ESC%[2m[Enter = HermesGateway (%ROOT_DIR:\=_%)]%ESC%[0m: "
    if "!SERVICE_NAME!"=="" set "SERVICE_NAME=HermesGateway (%ROOT_DIR:\=_%)"
)
REM Заменяем запрещённые символы в имени службы
set "SERVICE_NAME=!SERVICE_NAME:\=_!"

REM Проверка: не установлена ли уже служба ДЛЯ ЭТОГО инстанса (по описанию с ROOT_DIR)
REM ВАЖНО: хелпер кладёт найденную службу в SERVICE_NAME — сохраняем запрошенное имя!
set "REQUESTED_NAME=!SERVICE_NAME!"
call "%SCRIPTS_DIR%\Find-Hermes-Service.bat" "%ROOT_DIR%" <nul
set "EXIST_SERVICE=%SERVICE_NAME%"
set "SERVICE_NAME=%REQUESTED_NAME%"
if defined EXIST_SERVICE (
    echo   %ESC%[1;31m[ОШИБКА] Для этого инстанса ^(%ROOT_DIR%^) уже установлена служба "!EXIST_SERVICE!".%ESC%[0m
    echo   %ESC%[33mУдалите её через [3] или используйте её для перезапуска [4].%ESC%[0m
    echo.
    pause
    exit /b 1
)

REM Проверка: не установлена ли уже такая служба
sc query "!SERVICE_NAME!" >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;31m[ОШИБКА] Служба "!SERVICE_NAME!" уже существует.%ESC%[0m
    echo   %ESC%[33mУдалите её через [3] или выберите другое имя.%ESC%[0m
    echo.
    pause
    exit /b 1
)

REM ============================================================================
REM   Порт (фиксированный, для удалённого доступа; 0.0.0.0 форсируется)
REM   Параметр %2 = порт (для автоматизации).
REM ============================================================================
set "SERVICE_PORT=%~2"
if not defined SERVICE_PORT (
    set "SERVICE_PORT=9119"
    set /p "SERVICE_PORT=%ESC%[1mПорт для удалённого доступа%ESC%[0m %ESC%[2m[Enter = 9119]%ESC%[0m: "
    if "!SERVICE_PORT!"=="" set "SERVICE_PORT=9119"
)
set "SERVICE_PORT=!SERVICE_PORT: =!"

netstat -ano | findstr ":%SERVICE_PORT% " >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;33m  !   Порт !SERVICE_PORT! уже занят!%ESC%[0m
    set /p "CONT=%ESC%[33mПродолжить с этим портом? ^(y/N^): %ESC%[0m"
    if /i not "!CONT!"=="y" (
        echo.
        pause
        exit /b 1
    )
)

REM ============================================================================
REM   NSSM (Non-Sucking Service Manager) — скачиваем при необходимости
REM ============================================================================
set "NSSM_EXE=%HERMES_HOME%\bin\nssm.exe"
if not exist "%NSSM_EXE%" (
    echo   %ESC%[1;33m- %ESC%[0mNSSM не найден — скачиваем...
    set "NSSM_ZIP=%TEMP%\nssm-2.24.zip"
    if exist "%NSSM_ZIP%" del "%NSSM_ZIP%" 2>nul

    REM --- Загрузка: nssm.cc → GitHub зеркало (curl / PowerShell fallback) ---
    powershell -NoProfile -NonInteractive -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; try { Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile '%NSSM_ZIP%' -TimeoutSec 60 } catch { Invoke-WebRequest -Uri 'https://github.com/rosengaard/nssm-2.24/releases/download/2.24/nssm-2.24.zip' -OutFile '%NSSM_ZIP%' -TimeoutSec 60 }"
    if not exist "%NSSM_ZIP%" (
        echo   %ESC%[1;31m[ОШИБКА] Не удалось скачать NSSM ^(nssm.cc и GitHub недоступны^).%ESC%[0m
        echo   %ESC%[33mСкачайте nssm-2.24.zip вручную и положите nssm.exe в %HERMES_HOME%\bin\%ESC%[0m
        echo.
        pause
        exit /b 1
    )

    REM --- Распаковка: win64\nssm.exe → bin ---
    mkdir "%HERMES_HOME%\bin" 2>nul
    powershell -NoProfile -NonInteractive -Command "Expand-Archive -Path '%NSSM_ZIP%' -DestinationPath '%TEMP%\nssm-unpack' -Force"
    if exist "%TEMP%\nssm-unpack\nssm-2.24\win64\nssm.exe" (
        copy /y "%TEMP%\nssm-unpack\nssm-2.24\win64\nssm.exe" "%NSSM_EXE%" >nul
    )
    rmdir /s /q "%TEMP%\nssm-unpack" 2>nul
    del "%NSSM_ZIP%" 2>nul
)

if not exist "%NSSM_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] nssm.exe не найден после распаковки.%ESC%[0m
    echo   %ESC%[33mПоложите nssm.exe вручную в %HERMES_HOME%\bin\ и повторите.%ESC%[0m
    echo.
    pause
    exit /b 1
)
echo   %ESC%[1;32m+%ESC%[0m NSSM: %NSSM_EXE%
echo.

REM ============================================================================
REM   Авторизация для удалённого доступа
REM   dashboard ОТКАЗЫВАЕТСЯ слушать 0.0.0.0 без auth-провайдера (June 2026
REM   hardening; --insecure больше не работает). Настраиваем basic_auth.
REM ============================================================================
echo.
echo   %ESC%[1;33m-%ESC%[0m Для удалённого доступа dashboard требуется авторизация:
set "AUTH_USER=%~3"
if not defined AUTH_USER (
    set "AUTH_USER=admin"
    set /p "AUTH_USER=%ESC%[1mЛогин веб-доступа%ESC%[0m %ESC%[2m[Enter = admin]%ESC%[0m: "
    if "!AUTH_USER!"=="" set "AUTH_USER=admin"
)
set "AUTH_USER=!AUTH_USER: =!"

set "AUTH_PASS=%~4"
if not defined AUTH_PASS set /p "AUTH_PASS=%ESC%[1mПароль веб-доступа%ESC%[0m: "
if "!AUTH_PASS!"=="" (
    echo   %ESC%[1;31m[!] Пароль не задан — dashboard НЕ сможет слушать 0.0.0.0!%ESC%[0m
    echo   %ESC%[33mУстановка службы продолжится, но удалённый доступ будет недоступен.%ESC%[0m
) else (
    REM Генерируем scrypt-хэш пароля (venv python)
    set "AUTH_HASH="
    for /f "delims=" %%h in ('"%PYTHON_EXE%" -c "from plugins.dashboard_auth.basic import hash_password; print(hash_password('!AUTH_PASS!'))" 2^>nul') do set "AUTH_HASH=%%h"
    if not defined AUTH_HASH (
        echo   %ESC%[1;33m  !   Не удалось сгенерировать хэш пароля.%ESC%[0m
    ) else (
        powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\patch\patch_dashboard_auth.ps1" -ConfigPath "%HERMES_HOME%\config.yaml" -Username "!AUTH_USER!" -PasswordHash "!AUTH_HASH!"
    )
)

REM ============================================================================
REM   Установка службы
REM   dashboard --host 0.0.0.0 — слушаем ВСЕ адаптеры (иначе удалённый доступ невозможен)
REM ============================================================================
echo.
echo   %ESC%[1;33m-%ESC%[0m Установка службы "!SERVICE_NAME!"...

set "HERMES_CLI=%REPO_DIR%\venv\Scripts\hermes.exe"
if not exist "%HERMES_CLI%" (
    echo   %ESC%[1;31m[ОШИБКА] hermes.exe не найден: %HERMES_CLI%%ESC%[0m
    echo.
    pause
    exit /b 1
)

REM --skip-build: dashboard не собирает web UI при старте (иначе цикл
REM "Web UI npm install failed" — web workspace не установлен; dist уже готов)
"%NSSM_EXE%" install "!SERVICE_NAME!" "%HERMES_CLI%" dashboard --host 0.0.0.0 --port "!SERVICE_PORT!" --no-open --skip-build
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] nssm install не удался.%ESC%[0m
    echo.
    pause
    exit /b 1
)

"%NSSM_EXE%" set "!SERVICE_NAME!" AppDirectory "%HERMES_HOME%"
REM HERMES_WEB_DIST — готовый web dist из Desktop-сборки (иначе dashboard
REM пытается собрать web UI при каждом старте и падает: "Web UI npm install failed")
"%NSSM_EXE%" set "!SERVICE_NAME!" AppEnvironmentExtra HERMES_HOME=%HERMES_HOME% HOME=%DATA_DIR%\home USERPROFILE=%DATA_DIR%\home APPDATA=%DATA_DIR%\appdata LOCALAPPDATA=%DATA_DIR%\localappdata TEMP=%DATA_DIR%\temp PYTHONIOENCODING=utf-8 HERMES_WEB_DIST=%REPO_DIR%\apps\desktop\release\win-unpacked\resources\app.asar.unpacked\dist
"%NSSM_EXE%" set "!SERVICE_NAME!" AppStdout "%DATA_DIR%\temp\service-!SERVICE_NAME!.log"
"%NSSM_EXE%" set "!SERVICE_NAME!" AppStderr "%DATA_DIR%\temp\service-!SERVICE_NAME!.log"
"%NSSM_EXE%" set "!SERVICE_NAME!" AppRotateFiles 1
"%NSSM_EXE%" set "!SERVICE_NAME!" AppRotateBytes 10485760
"%NSSM_EXE%" set "!SERVICE_NAME!" AppExit Default Restart
"%NSSM_EXE%" set "!SERVICE_NAME!" Start SERVICE_AUTO_START

REM Описание службы: указываем инстанс (путь) — видно, чья это служба
sc description "!SERVICE_NAME!" "Hermes Portable instance: %ROOT_DIR%" >nul 2>&1

REM   web_dist: dashboard (с --skip-build) ищет web UI ТОЛЬКО в hermes_cli\web_dist.
REM   Если его нет - копируем готовый dist из Desktop-сборки.
REM ============================================================================
if not exist "%REPO_DIR%\hermes_cli\web_dist\index.html" (
    if exist "%REPO_DIR%\apps\desktop\release\win-unpacked\resources\app.asar.unpacked\dist\index.html" (
        echo   %ESC%[1;33m- %ESC%[0mКопирование web dist в hermes_cli\web_dist...
        mkdir "%REPO_DIR%\hermes_cli\web_dist" 2>nul
        xcopy /e /y /q "%REPO_DIR%\apps\desktop\release\win-unpacked\resources\app.asar.unpacked\dist\*" "%REPO_DIR%\hermes_cli\web_dist\" >nul
        if exist "%REPO_DIR%\hermes_cli\web_dist\index.html" (
            echo   %ESC%[1;32m+%ESC%[0m web_dist готов.
        ) else (
            echo   %ESC%[1;33m  !   Не удалось скопировать web_dist. Соберите вручную: npm run build -w web%ESC%[0m
        )
    )
)

REM ============================================================================
REM   Firewall: открываем порт
REM ============================================================================
echo   %ESC%[1;33m-%ESC%[0m Открытие порта !SERVICE_PORT! в брандмауэре...
netsh advfirewall firewall add rule name="Hermes !SERVICE_NAME! !SERVICE_PORT!" dir=in action=allow protocol=TCP localport=!SERVICE_PORT! >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m+%ESC%[0m Правило брандмауэра добавлено: "Hermes !SERVICE_NAME! !SERVICE_PORT!"
) else (
    echo   %ESC%[1;33m  !   Не удалось добавить правило ^(нужны права администратора^).%ESC%[0m
)

REM ============================================================================
REM   Запуск службы
REM ============================================================================
echo   %ESC%[1;33m-%ESC%[0m Запуск службы "!SERVICE_NAME!"...
"%NSSM_EXE%" start "!SERVICE_NAME!" >nul 2>&1

REM ============================================================================
REM   Проверка результата
REM ============================================================================
echo.
echo  --------------------------------------------------------------------------------
set "SERVICE_RUNNING=0"
sc query "!SERVICE_NAME!" 2>nul | findstr /i "RUNNING" >nul 2>&1
if !errorlevel! equ 0 set "SERVICE_RUNNING=1"

if !SERVICE_RUNNING! equ 1 (
    echo   %ESC%[1;32m+ Служба "!SERVICE_NAME!" запущена и работает.%ESC%[0m
) else (
    echo   %ESC%[1;33m. Служба "!SERVICE_NAME!" установлена, но НЕ запущена.%ESC%[0m
    echo   %ESC%[33m  Лог: %DATA_DIR%\temp\service-!SERVICE_NAME!.log%ESC%[0m
)

REM Проверка: слушает ли 0.0.0.0 (не 127.0.0.1!)
netstat -ano | findstr "0.0.0.0:!SERVICE_PORT! " >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m+ Порт !SERVICE_PORT! слушается на 0.0.0.0 ^(все адаптеры^) — удалённый доступ возможен.%ESC%[0m
) else (
    echo   %ESC%[1;31m  ! Порт !SERVICE_PORT! НЕ слушается на 0.0.0.0!%ESC%[0m
    echo   %ESC%[33m  Проверьте лог службы и запустите её снова: [4] Перезапустить службу.%ESC%[0m
)
echo  --------------------------------------------------------------------------------
echo.
echo   %ESC%[1;33mДалее:%ESC%[0m
echo     - Проверьте подключение с другого ПК: пункт [8] Гайд.
echo     - Для нескольких инстансов используйте разные имена служб и порты.
echo.
pause
exit /b 0
