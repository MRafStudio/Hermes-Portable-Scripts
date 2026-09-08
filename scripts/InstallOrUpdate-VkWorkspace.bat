@REM scripts\InstallOrUpdate-VkWorkspace.bat — VK WorkSpace плагин шлюза
@REM
@REM ТОЛЬКО управление ПЛАГИНОМ (не службой!). Служба шлюза HermesMessengerGateway
@REM ставится/снимается вместе со службой Hermes (см. Install-Hermes-Service.bat).
@REM
@REM Источник плагина — GitHub: MRafStudio/hermes-vk-workspace (папка plugin).
@REM Качается zip main-ветки и распаковывается plugin\ -> plugins\vk_workspace\
@REM (3 файла: adapter.py, plugin.yaml, __init__.py).
@REM
@REM Меню:
@REM   [1] Установить/обновить плагин VK WorkSpace (с GitHub)
@REM       + запрос/проверка токена бота, включение в config.yaml,
@REM         проверка приёма сообщения, рекомендация по приватности
@REM   [2] Удалить плагин VK WorkSpace (выключить + удалить папку)
@REM   [3] Открыть .env для ручной настройки
@REM   [0] Назад
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title VK WorkSpace плагин

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "DATA_DIR=%ROOT_DIR%\data"
set "PLUGIN_DST=%HERMES_HOME%\plugins\vk_workspace"
set "CONFIG_YAML=%HERMES_HOME%\config.yaml"
set "ENV_FILE=%HERMES_HOME%\.env"
set "AGENT_LOG=%HERMES_HOME%\logs\agent.log"
set "PY=%HERMES_HOME%\hermes-agent\venv\Scripts\python.exe"
set "PYHELPER=%SCRIPTS_DIR%\py\vk_plugin_config.py"
set "API_URL=https://myteam.mail.ru/bot/v1"
set "GH_REPO=MRafStudio/hermes-vk-workspace"
set "GH_BRANCH=main"
set "GH_ZIP_URL=https://codeload.github.com/%GH_REPO%/zip/refs/heads/%GH_BRANCH%"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Статус плагина
REM ============================================================================
:status
set "VK_INSTALLED=0"
if exist "%PLUGIN_DST%\plugin.yaml" set "VK_INSTALLED=1"
set "VK_ENABLED=0"
"%PY%" "%PYHELPER%" enabled "%CONFIG_YAML%" >nul 2>&1
if !errorlevel! equ 0 set "VK_ENABLED=1"

:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                 VK WorkSpace%ESC%[0m — %ESC%[1;33mплагин шлюза мессенджера%ESC%[0m                   %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
if !VK_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m Плагин VK WorkSpace — установлен в %PLUGIN_DST%
) else (
    echo   %ESC%[1;33m. %ESC%[0m Плагин VK WorkSpace — не установлен
)
if !VK_ENABLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m Плагин включён в config.yaml ^(vk-workspace-platform^)
) else (
    echo   %ESC%[1;33m. %ESC%[0m Плагин не включён в config.yaml
)
echo.
echo   %ESC%[2mИсточник: GitHub %GH_REPO% ^(папка plugin^)%ESC%[0m
echo   %ESC%[2mСлужба мессенджеров ставится/удаляется вместе со службой Hermes%ESC%[0m
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановить/Обновить плагин VK WorkSpace%ESC%[0m
echo       %ESC%[2mСкачать с GitHub + токен + включение + проверка приёма%ESC%[0m
echo.
if !VK_INSTALLED! equ 1 (
echo   %ESC%[1;31m[2]%ESC%[0m %ESC%[1;31mУдалить плагин VK WorkSpace%ESC%[0m
echo       %ESC%[2mВыключить в config.yaml + удалить папку плагина%ESC%[0m
echo.
)
echo   %ESC%[1;37m[3]%ESC%[0m %ESC%[1mОткрыть .env для настройки%ESC%[0m
echo       %ESC%[2mТокен, разрешённые пользователи, API URL%ESC%[0m
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в меню плагинов%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие: %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" exit /b 0
if "%choice%"=="1" goto do_install
if "%choice%"=="2" goto do_remove
if "%choice%"=="3" goto do_open_env
goto menu

REM ============================================================================
REM   [1] Установка / обновление плагина (с GitHub)
REM ============================================================================
:do_install
if not exist "%PY%" (
    echo   %ESC%[1;31m[ОШИБКА] Python не найден: %PY%%ESC%[0m
    pause
    goto status
)
if not exist "%PYHELPER%" (
    echo   %ESC%[1;31m[ОШИБКА] Хелпер не найден: %PYHELPER%%ESC%[0m
    pause
    goto status
)

echo.
echo   %ESC%[1;33m-%ESC%[0m Настройка токена бота VK WorkSpace...

REM --- токен: сначала пробуем тот, что в .env (NEW_TOKEN пуст → ensure-token возьмёт из .env).
REM Если он не прошёл проверку (протух/битый) — запрашиваем новый у пользователя и пробуем снова.
set "NEW_TOKEN="

:token_retry
echo   %ESC%[1;33m-%ESC%[0m Проверяю токен на сервере...
"%PY%" "%PYHELPER%" ensure-token "!NEW_TOKEN!" "%API_URL%" "%ENV_FILE%" >"%TEMP%\vk_token_check.txt" 2>&1
if !errorlevel! equ 0 (
    set /p CHECK=<"%TEMP%\vk_token_check.txt"
    echo   %ESC%[1;32m+%ESC%[0m Токен верный: !CHECK!
    goto token_ok
)

REM --- не прошёл: сообщаем и запрашиваем новый токен ---
set /p CHECK=<"%TEMP%\vk_token_check.txt"
echo   %ESC%[1;31m[ОШИБКА] Токен НЕ прошёл проверку: !CHECK!%ESC%[0m
echo   %ESC%[33mВозможно токен протух или неверен. Введите НОВЫЙ токен бота VK WorkSpace:%ESC%[0m
echo   %ESC%[2mТокен Metabot — получить: https://teams.vk.com/botapi/%ESC%[0m
set "NEW_TOKEN="
set /p "NEW_TOKEN=%ESC%[1mНовый токен бота VK WorkSpace%ESC%[0m: "
set "NEW_TOKEN=!NEW_TOKEN: =!"
if "!NEW_TOKEN!"=="" (
    echo   %ESC%[1;31m[ОШИБКА] Токен не введён. Установка отменена.%ESC%[0m
    pause
    goto status
)
echo   %ESC%[2mПроверяю новый токен...%ESC%[0m
goto token_retry

:token_ok
echo.

echo   %ESC%[1;33m-%ESC%[0m Скачиваю плагин с GitHub ^(%GH_REPO%^)...
set "GH_ZIP=%TEMP%\hermes-vk-workspace.zip"
set "GH_UNPACK=%TEMP%\hermes-vk-workspace-unpack"
if exist "%GH_ZIP%" del "%GH_ZIP%" 2>nul
if exist "%GH_UNPACK%" rmdir /s /q "%GH_UNPACK%" 2>nul
call :download "%GH_ZIP_URL%" "%GH_ZIP%" "плагин VK WorkSpace GitHub"
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось скачать плагин с GitHub.%ESC%[0m
    echo   %ESC%[33mПроверьте доступ к github.com. Или положите файлы вручную в %PLUGIN_DST%%ESC%[0m
    pause
    goto status
)
call :unzip "%GH_ZIP%" "%GH_UNPACK%"

REM --- найти plugin-папку внутри распакованного (имя каталога = repo-branch) ---
set "GH_PLUGIN="
for /d %%d in ("%GH_UNPACK%\*") do (
    if exist "%%d\plugin\plugin.yaml" set "GH_PLUGIN=%%d\plugin"
)
if not defined GH_PLUGIN (
    echo   %ESC%[1;31m[ОШИБКА] В архиве не найдена папка plugin\.%ESC%[0m
    pause
    goto status
)

echo   %ESC%[1;33m-%ESC%[0m Копирую плагин в %PLUGIN_DST% ...
if not exist "%PLUGIN_DST%" mkdir "%PLUGIN_DST%" 2>nul
copy /Y "%GH_PLUGIN%\plugin.yaml" "%PLUGIN_DST%\" >nul
copy /Y "%GH_PLUGIN%\adapter.py" "%PLUGIN_DST%\" >nul
copy /Y "%GH_PLUGIN%\__init__.py" "%PLUGIN_DST%\" >nul
echo   %ESC%[1;32m+%ESC%[0m Файлы плагина скопированы ^(3 шт^).
if exist "%GH_ZIP%" del "%GH_ZIP%" 2>nul
if exist "%GH_UNPACK%" rmdir /s /q "%GH_UNPACK%" 2>nul

echo   %ESC%[1;33m-%ESC%[0m Включаю плагин в config.yaml...
"%PY%" "%PYHELPER%" enable "%CONFIG_YAML%" >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m+%ESC%[0m Плагин включён в config.yaml.
) else (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось включить плагин в config.yaml.%ESC%[0m
)
echo.
echo   %ESC%[1;32m+%ESC%[0m Плагин VK WorkSpace установлен и включён.
echo.
set /p "DO_CHECK=%ESC%[1mПроверить приём сообщений сейчас?%ESC%[0m %ESC%[2m(y/N): %ESC%[0m"
if /i "!DO_CHECK!"=="y" goto do_receive_check
goto install_done

:do_receive_check
echo.
echo   %ESC%[1;36m────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1;33mПроверка приёма сообщений.%ESC%[0m
echo   %ESC%[2m  1. Откройте VK WorkSpace и напишите этому боту любое сообщение,%ESC%[0m
echo   %ESC%[2m     например: %ESC%[1m«Привет»%ESC%[0m
echo   %ESC%[2m  2. Нажмите Enter после того, как отправите сообщение.%ESC%[0m
echo.
set /p "WAIT=Напишите боту и нажмите Enter: "

REM --- снимок: было ли входящее сообщение ДО (убираем старые из счёта) ---
for /f "delims=" %%c in ('"%PY%" "%PYHELPER%" received "%AGENT_LOG%" vk_workspace 2^>nul') do set "BEFORE=%%c"
if not defined BEFORE set "BEFORE=0"
timeout /t 2 /nobreak >nul 2>&1
for /f "delims=" %%c in ('"%PY%" "%PYHELPER%" received "%AGENT_LOG%" vk_workspace 2^>nul') do set "AFTER=%%c"
if not defined AFTER set "AFTER=0"
echo.
if !AFTER! GTR !BEFORE! (
    echo   %ESC%[1;32m+%ESC%[0m Сообщение поймано шлюзом! Плагин VK WorkSpace работает. ^(в логе: !BEFORE! -^> !AFTER!^)
) else (
    echo   %ESC%[1;31m[ВНИМАНИЕ] Сообщение не обнаружено в логе.%ESC%[0m
    echo   %ESC%[33m  Причины: служба шлюза не запущена, или бот не в сети.%ESC%[0m
    echo   %ESC%[33m  1. Поставьте службу шлюза: InstallOrUpdate.bat ^-^> [4] Установить службу Hermes%ESC%[0m
    echo   %ESC%[33m  2. Или перезапустите: Restart-Hermes-Service.bat%ESC%[0m
)
echo.

:install_done
echo   %ESC%[1;33mДалее — настройка в .env ^([3] Открыть .env^):%ESC%[0m
echo     - VK_WORKSPACE_ALLOWED_USERS — кто может писать боту ^(приватность^). Сейчас: rr.kagarmanov@gk-base.ru
echo     - VK_WORKSPACE_HOME_CHANNEL — чат для cron-уведомлений ^(если нужно^)
echo     - VK_WORKSPACE_API_URL — база API ^(on-prem, если нужно^)
echo.
echo   %ESC%[2mПосле правки .env перезапустите службу шлюза: Restart-Hermes-Service.bat%ESC%[0m
echo.
pause
goto status

REM ============================================================================
REM   [2] Удаление плагина
REM ============================================================================
:do_remove
echo.
echo   %ESC%[1;33mВНИМАНИЕ: будет выключен и удалён плагин VK WorkSpace из %PLUGIN_DST%%ESC%[0m
set /p "CONF=%ESC%[33mУдалить плагин? (y/N): %ESC%[0m"
if /i not "!CONF!"=="y" goto status

echo   %ESC%[1;33m-%ESC%[0m Выключаю плагин в config.yaml...
"%PY%" "%PYHELPER%" disable "%CONFIG_YAML%" >nul 2>&1
echo   %ESC%[1;33m-%ESC%[0m Удаляю папку плагина...
if exist "%PLUGIN_DST%" rmdir /s /q "%PLUGIN_DST%" 2>nul
echo   %ESC%[1;32m+%ESC%[0m Плагин удалён.
echo   %ESC%[33mТокен в .env оставлен ^(удалите вручную при желании^).%ESC%[0m
pause
goto status

REM ============================================================================
REM   [3] Открыть .env
REM ============================================================================
:do_open_env
if not exist "%ENV_FILE%" (
    echo   %ESC%[1;33m. %ESC%[0m .env не найден - создаю пустой: %ENV_FILE%
    echo # VK WorkSpace > "%ENV_FILE%"
)
echo   %ESC%[1;33m-%ESC%[0m Открываю %ENV_FILE% в Блокноте...
start notepad "%ENV_FILE%"
echo   %ESC%[2mЗаполните: VK_WORKSPACE_BOT_TOKEN, VK_WORKSPACE_ALLOWED_USERS, %ESC%[0m
echo   %ESC%[2mVK_WORKSPACE_API_URL ^(опционально^). Потом вернитесь в это меню.%ESC%[0m
pause
goto status

REM ============================================================================
REM   :download URL FILE NAME — скачивание: напрямую -> прокси 10809 -> PowerShell
REM ============================================================================
:download
set "DL_URL=%~1"
set "DL_FILE=%~2"
set "DL_NAME=%~3"
if exist "%DL_FILE%" del "%DL_FILE%" 2>nul
set "CURL="
if exist "%SYSTEMROOT%\System32\curl.exe" set "CURL=%SYSTEMROOT%\System32\curl.exe"
if not defined CURL for /f "delims=" %%c in ('where curl 2^>nul') do if not defined CURL set "CURL=%%c"
echo   %ESC%[2m  Загрузка %DL_NAME% ...%ESC%[0m
"%CURL%" -L --fail --ssl-no-revoke --noproxy "*" -C - -o "%DL_FILE%" "%DL_URL%"
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m  Напрямую не вышло - пробуем через прокси 10809...%ESC%[0m
    "%CURL%" -L --fail --ssl-no-revoke -x "http://127.0.0.1:10809" -C - --retry 8 --retry-delay 3 --retry-all-errors -o "%DL_FILE%" "%DL_URL%"
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m  Прокси не помог - переключение на PowerShell...%ESC%[0m
    powershell -NoProfile -NonInteractive -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; try { Invoke-WebRequest -Uri '%DL_URL%' -OutFile '%DL_FILE%' -UseBasicParsing -TimeoutSec 600 } catch { exit 1 }"
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;31m[ОШИБКА] Загрузка не удалась: %DL_NAME%%ESC%[0m
    echo   %ESC%[33mURL: %DL_URL%%ESC%[0m
    exit /b 1
)
echo   %ESC%[1;32m  OK: %DL_NAME%%ESC%[0m
exit /b 0

REM ============================================================================
REM   :unzip FILE DIR — 7z (если найден) -> иначе PowerShell Expand-Archive
REM ============================================================================
:unzip
set "SEVENZIP="
if exist "%ProgramFiles%\7-Zip\7z.exe" set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
if not defined SEVENZIP if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" set "SEVENZIP=%ProgramFiles(x86)%\7-Zip\7z.exe"
if defined SEVENZIP (
    "%SEVENZIP%" x -y -o"%~2" "%~1" >nul 2>&1
    if not errorlevel 1 exit /b 0
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%~1' -DestinationPath '%~2' -Force"
exit /b 0
