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
echo  %ESC%[1;36m##%ESC%[0m                           %ESC%[1;37mУстановка службы Hermes%ESC%[0m                          %ESC%[1;36m##%ESC%[0m
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
REM   Проверка установленного Hermes (для службы нужен CLI + web_dist,
REM   Desktop-сборка не требуется)
REM ============================================================================
set "PYTHON_EXE=%REPO_DIR%\venv\Scripts\python.exe"
if not exist "%PYTHON_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] venv Python не найден: %PYTHON_EXE%%ESC%[0m
    echo   %ESC%[33mПереустановите компоненты через [1].%ESC%[0m
    echo.
    pause
    exit /b 1
)
if not exist "%REPO_DIR%\hermes_cli\web_dist\index.html" (
    echo   %ESC%[1;31m[ОШИБКА] web_dist не найден: %REPO_DIR%\hermes_cli\web_dist%ESC%[0m
    echo   %ESC%[33mУстановите [1] Hermes Web или Desktop, чтобы собрать web UI.%ESC%[0m
    echo.
    pause
    exit /b 1
)

echo   %ESC%[1;32m+%ESC%[0m Python: %PYTHON_EXE%
echo   %ESC%[1;32m+%ESC%[0m Web dist: %REPO_DIR%\hermes_cli\web_dist
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
REM LOG_NAME — имя лог-файла без двоеточия (Windows запрещает ":" в именах файлов!)
set "LOG_NAME=!SERVICE_NAME::=_!"
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
REM   Порт (фиксированный, для удалённого доступа)
REM   Параметр %2 = порт (для автоматизации).
REM ============================================================================
set "SERVICE_PORT=%~2"
if not defined SERVICE_PORT (
    set "SERVICE_PORT=9119"
    set /p "SERVICE_PORT=%ESC%[1mПорт для удалённого доступа%ESC%[0m %ESC%[2m[Enter = 9119]%ESC%[0m: "
    if "!SERVICE_PORT!"=="" set "SERVICE_PORT=9119"
)
if not "!SERVICE_PORT!"=="" set "SERVICE_PORT=!SERVICE_PORT: =!"

REM ============================================================================
REM   Хост (адрес прослушивания): список доступных адаптеров
REM   [1] 0.0.0.0 — все адаптеры (по умолчанию, удалённый доступ)
REM   [2] 127.0.0.1 — только локальный
REM   [N] — IP конкретного адаптера
REM ============================================================================
set "SERVICE_HOST=0.0.0.0"
echo   %ESC%[1;33m-%ESC%[0m Доступные адреса прослушивания:
echo   %ESC%[2m      [1] 0.0.0.0   — все адаптеры (по умолчанию)%ESC%[0m
echo   %ESC%[2m      [2] 127.0.0.1 — только локальный%ESC%[0m
set "IP_N=2"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^169\.254' -and $_.IPAddress -notmatch '^127\.' } | Select-Object -ExpandProperty IPAddress)"`) do (
    set /a IP_N+=1
    set "IP_!IP_N!=%%i"
    echo   %ESC%[2m      [!IP_N!] %%i%ESC%[0m
)
set "HOST_CHOICE="
set /p "HOST_CHOICE=%ESC%[1mВыберите адрес%ESC%[0m %ESC%[2m[Enter = 0.0.0.0]%ESC%[0m: "
if not "!HOST_CHOICE!"=="" set "HOST_CHOICE=!HOST_CHOICE: =!"
if "!HOST_CHOICE!"=="2" set "SERVICE_HOST=127.0.0.1"
if defined HOST_CHOICE if !HOST_CHOICE! GTR 2 (
    set "SERVICE_HOST="
    for %%x in (!HOST_CHOICE!) do if defined IP_%%x set "SERVICE_HOST=!IP_%%x!"
    if not defined SERVICE_HOST (
        echo   %ESC%[1;31m  ОШИБКА: неверный выбор.%ESC%[0m
        echo.
        pause
        exit /b 1
    )
)
echo   %ESC%[1;32m+%ESC%[0m Адрес прослушивания: !SERVICE_HOST!

netstat -ano | findstr ":!SERVICE_PORT! " >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;33m  ВНИМАНИЕ: Порт !SERVICE_PORT! уже занят.%ESC%[0m
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
REM REM Portable-сборка: nssm лежит в scripts\bin (как uv.exe) — копируем без скачивания
if not exist "%NSSM_EXE%" if exist "%SCRIPTS_DIR%\bin\nssm.exe" copy /y "%SCRIPTS_DIR%\bin\nssm.exe" "%NSSM_EXE%" >nul 2>&1
if not exist "%NSSM_EXE%" (
    echo   %ESC%[1;33m- %ESC%[0mNSSM не найден — скачиваем...
    set "NSSM_ZIP=%TEMP%\nssm-2.24.zip"
    if exist "%NSSM_ZIP%" del "%NSSM_ZIP%" 2>nul

    REM --- Поиск curl: System32 (Win11+), затем git for windows (Win10 1607) ---
    if not defined CURL if exist "%SystemRoot%\System32\curl.exe" set "CURL=%SystemRoot%\System32\curl.exe"
    if not defined CURL if exist "%ProgramFiles%\Git\mingw64\bin\curl.exe" set "CURL=%ProgramFiles%\Git\mingw64\bin\curl.exe"
    if not defined CURL if exist "%ProgramFiles(x86)%\Git\mingw64\bin\curl.exe" set "CURL=%ProgramFiles(x86)%\Git\mingw64\bin\curl.exe"
    if not defined CURL if exist "%LocalAppData%\Programs\Git\mingw64\bin\curl.exe" set "CURL=%LocalAppData%\Programs\Git\mingw64\bin\curl.exe"

    REM --- Загрузка: цепочка curl → bitsadmin → certutil → PowerShell ---
    REM (PowerShell 5.1 на Win10 1607 капризен с TLS — поэтому он ПОСЛЕДНИЙ)
    if defined CURL (
        "%CURL%" -L --fail --silent --show-error -o "%NSSM_ZIP%" "https://nssm.cc/release/nssm-2.24.zip"
        if not exist "%NSSM_ZIP%" "%CURL%" -L --fail --silent --show-error -o "%NSSM_ZIP%" "https://github.com/rosengaard/nssm-2.24/releases/download/2.24/nssm-2.24.zip"
    )
    if not exist "%NSSM_ZIP%" (
        bitsadmin /transfer nssm_download /download /priority normal "https://nssm.cc/release/nssm-2.24.zip" "%NSSM_ZIP%" >nul 2>&1
    )
    if not exist "%NSSM_ZIP%" (
        bitsadmin /transfer nssm_download /download /priority normal "https://github.com/rosengaard/nssm-2.24/releases/download/2.24/nssm-2.24.zip" "%NSSM_ZIP%" >nul 2>&1
    )
    if not exist "%NSSM_ZIP%" (
        certutil -urlcache -f -split "https://nssm.cc/release/nssm-2.24.zip" "%NSSM_ZIP%" >nul 2>&1
    )
    if not exist "%NSSM_ZIP%" (
        powershell -NoProfile -NonInteractive -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; try { Invoke-WebRequest -Uri 'https://nssm.cc/release/nssm-2.24.zip' -OutFile '%NSSM_ZIP%' -TimeoutSec 60 } catch { Invoke-WebRequest -Uri 'https://github.com/rosengaard/nssm-2.24/releases/download/2.24/nssm-2.24.zip' -OutFile '%NSSM_ZIP%' -TimeoutSec 60 }"
    )

    REM --- Проверка: файл реально zip (~350 КБ; HTML-ошибки — килобайты) ---
    if exist "%NSSM_ZIP%" for %%z in ("%NSSM_ZIP%") do if %%~zz LSS 200000 del "%NSSM_ZIP%" 2>nul
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
REM   hardening; --insecure больше не работает).
REM   Если basic_auth уже задан в config.yaml (не null) — используем молча;
REM   иначе запрашиваем логин/пароль (как в Connection.bat) и сохраняем.
REM ============================================================================
set "AUTH_USER="
set "AUTH_PASS="
for /f "usebackq delims=" %%u in (`"%REPO_DIR%\venv\Scripts\hermes.exe" config get dashboard.basic_auth.username 2^>nul`) do set "AUTH_USER=%%u"
for /f "usebackq delims=" %%p in (`"%REPO_DIR%\venv\Scripts\hermes.exe" config get dashboard.basic_auth.password 2^>nul`) do set "AUTH_PASS=%%p"
if /i "!AUTH_USER!"=="null" set "AUTH_USER="
if /i "!AUTH_USER!"=="None" set "AUTH_USER="
if /i "!AUTH_PASS!"=="null" set "AUTH_PASS="
if /i "!AUTH_PASS!"=="None" set "AUTH_PASS="
if defined AUTH_USER if defined AUTH_PASS goto auth_done
echo   %ESC%[1;33m-%ESC%[0m Для удалённого доступа dashboard требуется авторизация:
if defined AUTH_USER goto pass_part
:ask_user
echo   %ESC%[1;33mЛогин%ESC%[0m %ESC%[2m- НЕ используйте символы %%%% и ^!^! и пробелы%ESC%[0m
set "AUTH_USER="
set /p "AUTH_USER=%ESC%[1mЛогин веб-доступа%ESC%[0m %ESC%[2m[Enter = admin]%ESC%[0m: "
if "!AUTH_USER!"=="" set "AUTH_USER=admin"
"%REPO_DIR%\venv\Scripts\python.exe" "%SCRIPTS_DIR%\py\validate_credentials.py" "!AUTH_USER!"
if errorlevel 1 (
    echo   %ESC%[1;31m  Логин содержит запрещённые символы ^(%%%% или ^!^! или пробел^) - повторите.%ESC%[0m
    goto ask_user
)
:pass_part
if defined AUTH_PASS goto save_auth
:ask_pass
echo   %ESC%[1;33mПароль%ESC%[0m %ESC%[2m- НЕ используйте символы %%%% и ^!^! ^(раскрытие переменных cmd^)%ESC%[0m
set "AUTH_PASS="
set /p "AUTH_PASS=%ESC%[1mПароль веб-доступа%ESC%[0m: "
if "!AUTH_PASS!"=="" (
    echo   %ESC%[1;31m  Пароль не может быть пустым - повторите.%ESC%[0m
    goto ask_pass
)
"%REPO_DIR%\venv\Scripts\python.exe" "%SCRIPTS_DIR%\py\validate_credentials.py" "!AUTH_PASS!"
if errorlevel 1 (
    echo   %ESC%[1;31m  Пароль содержит запрещённые символы - повторите.%ESC%[0m
    goto ask_pass
)
:save_auth
"%REPO_DIR%\venv\Scripts\hermes.exe" config set dashboard.basic_auth.username "!AUTH_USER!"
"%REPO_DIR%\venv\Scripts\hermes.exe" config set dashboard.basic_auth.password "!AUTH_PASS!"
:auth_done

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
"%NSSM_EXE%" install "!SERVICE_NAME!" "%HERMES_CLI%" dashboard --host "!SERVICE_HOST!" --port "!SERVICE_PORT!" --no-open --skip-build
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] nssm install не удался.%ESC%[0m
    echo.
    pause
    exit /b 1
)

"%NSSM_EXE%" set "!SERVICE_NAME!" AppDirectory "%HERMES_HOME%"
REM HERMES_WEB_DIST — готовый web dist из Desktop-сборки (иначе dashboard
REM пытается собрать web UI при каждом старте и падает: "Web UI npm install failed")
"%NSSM_EXE%" set "!SERVICE_NAME!" AppEnvironmentExtra "HERMES_HOME=%HERMES_HOME%" "HOME=%DATA_DIR%\home" "USERPROFILE=%DATA_DIR%\home" "APPDATA=%DATA_DIR%\appdata" "LOCALAPPDATA=%DATA_DIR%\localappdata" "TEMP=%DATA_DIR%\temp" "PYTHONIOENCODING=utf-8" "HERMES_WEB_DIST=%REPO_DIR%\apps\desktop\release\win-unpacked\resources\app.asar.unpacked\dist"
"%NSSM_EXE%" set "!SERVICE_NAME!" AppStdout "%DATA_DIR%\temp\service-!LOG_NAME!.log"
"%NSSM_EXE%" set "!SERVICE_NAME!" AppStderr "%DATA_DIR%\temp\service-!LOG_NAME!.log"
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
echo.
call "%SCRIPTS_DIR%\Open-Firewall-Port-Auto.bat" !SERVICE_PORT! "Hermes !SERVICE_NAME!"

REM ============================================================================
REM   Запуск службы (лог — только текущий запуск)
if exist "%DATA_DIR%\temp\service-!LOG_NAME!.log" del /q "%DATA_DIR%\temp\service-!LOG_NAME!.log" 2>nul
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

REM Ожидаем подъём dashboard (первый старт медленный — до 60 сек) — иначе ложное "НЕ слушается"
set /a WAIT=0
:wait_port
netstat -ano | findstr "0.0.0.0:!SERVICE_PORT! " >nul 2>&1
if !errorlevel! equ 0 goto port_checked
set /a WAIT+=1
if !WAIT! lss 60 (
    timeout /t 1 /nobreak >nul 2>&1
    goto wait_port
)
:port_checked
REM Проверка: слушает ли 0.0.0.0 (не 127.0.0.1!)
netstat -ano | findstr "0.0.0.0:!SERVICE_PORT! " >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m+ Порт !SERVICE_PORT! слушается на 0.0.0.0 ^(все адаптеры^) — удалённый доступ возможен.%ESC%[0m
) else (
    echo   %ESC%[1;31m  ВНИМАНИЕ: Порт !SERVICE_PORT! НЕ слушается на 0.0.0.0.%ESC%[0m
    echo   %ESC%[33m  Проверьте лог службы и запустите её снова: [4] Перезапустить службу.%ESC%[0m
)
echo  --------------------------------------------------------------------------------
echo.
echo   %ESC%[1;33mДалее:%ESC%[0m
echo     - Проверьте подключение с другого ПК: пункт [3] Гайд.
echo     - Для нескольких инстансов используйте разные имена служб и порты.
echo.
pause
exit /b 0
