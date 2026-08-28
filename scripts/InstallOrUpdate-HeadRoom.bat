@REM scripts\InstallOrUpdate-HeadRoom.bat — HeadRoom: прокси-сервер сжатия контекста
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title HeadRoom — прокси сжатия контекста

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "DATA_DIR=%ROOT_DIR%\data"
set "UV_EXE=%HERMES_HOME%\bin\uv.exe"
if not exist "%UV_EXE%" set "UV_EXE=%SCRIPTS_DIR%\bin\uv.exe"

REM ============================================================================
REM   Параметры HeadRoom (вся установка в data\HeadRoom — как llama-manager)
REM ============================================================================
set "HEADROOM_DIR=%DATA_DIR%\HeadRoom"
set "HEADROOM_VENV=%HEADROOM_DIR%\.venv"
set "HEADROOM_EXE=%HEADROOM_VENV%\Scripts\headroom.exe"
set "HEADROOM_PY=%HEADROOM_VENV%\Scripts\python.exe"
set "HEADROOM_NSSM=%HEADROOM_DIR%\nssm\nssm.exe"
set "HEADROOM_NSSM_ZIP=%TEMP%\nssm-2.24.zip"
set "HEADROOM_PORT=8787"
set "HEADROOM_UPSTREAM=https://api.deepseek.com"
set "HEADROOM_EXTRAS=proxy,ml,code"
set "HEADROOM_HF_HOME=%DATA_DIR%\huggingface"
set "HEADROOM_HF_MODEL=chopratejas/kompress-v2-base"
set "HEADROOM_STATS=%SCRIPTS_DIR%\py\headroom_stats.py"
set "HEADROOM_REPO=headroomlabs-ai/headroom"
set "HEADROOM_NSSM_URL=https://nssm.cc/release/nssm-2.24.zip"

REM --- Интеграция с Hermes (model.base_url) ---
set "HERMES_BIN=%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe"
set "HEADROOM_BASE_URL=http://127.0.0.1:%HEADROOM_PORT%/v1"
set "HEADROOM_SAVED_URL=%HEADROOM_DIR%\saved_base_url.txt"

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
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul

REM ============================================================================
REM   Получение ESC (стандартный трюк, без PowerShell)
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Права администратора
REM ============================================================================
net session >nul 2>&1
if errorlevel 1 (set "IS_ADMIN=0") else (set "IS_ADMIN=1")

REM ============================================================================
REM   Параметры командной строки (self-elevate: запуск от администратора)
REM ============================================================================
if /i "%~1"=="install" goto do_install
if /i "%~1"=="svc_reinstall" goto do_svc_reinstall
if /i "%~1"=="svc_remove" goto do_svc_remove
if /i "%~1"=="headroom_nuke" goto headroom_nuke

REM ============================================================================
REM   Статус HeadRoom
REM ============================================================================
:status
set "HEADROOM_INSTALLED=0"
set "HEADROOM_VER=?"
if exist "%HEADROOM_EXE%" (
    set "HEADROOM_INSTALLED=1"
    for /f "delims=" %%v in ('"%HEADROOM_EXE%" --version 2^>nul') do set "HEADROOM_VER=%%v"
)
set "HEADROOM_SVC=0"
sc query Headroom >nul 2>&1
if not errorlevel 1 set "HEADROOM_SVC=1"

REM Hermes подключён к прокси? (model.base_url или providers.deepseek-hr.base_url)
set "HR_LINKED=0"
if exist "%HERMES_BIN%" (
    for /f "delims=" %%u in ('"%HERMES_BIN%" config get model.base_url 2^>nul ^| findstr /V /C:"not set"') do (
        set "HR_CUR=%%u"
        if "!HR_CUR!"=="%HEADROOM_BASE_URL%" set "HR_LINKED=1"
    )
    if "!HR_LINKED!"=="0" (
        for /f "delims=" %%u in ('"%HERMES_BIN%" config get providers.deepseek-hr.base_url 2^>nul ^| findstr /V /C:"not set"') do (
            set "HR_CUR=%%u"
            if "!HR_CUR!"=="%HEADROOM_BASE_URL%" set "HR_LINKED=1"
        )
    )
)

REM ============================================================================
REM   Меню
REM ============================================================================
:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                     HeadRoom%ESC%[0m — %ESC%[1;33mпрокси сжатия контекста%ESC%[0m                    %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
if !HEADROOM_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m HeadRoom %ESC%[2m^(%HEADROOM_VER%^)%ESC%[0m — установлен в %HEADROOM_DIR%
) else (
    echo   %ESC%[1;33m. %ESC%[0m HeadRoom — не установлен
)
if !HEADROOM_SVC! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m Служба Headroom %ESC%[2m^(порт %HEADROOM_PORT%, автозапуск^)%ESC%[0m — работает
) else (
    echo   %ESC%[1;33m. %ESC%[0m Служба Headroom — не установлена
)
if !HR_LINKED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m Hermes %ESC%[2m^(model.base_url^)%ESC%[0m — через прокси %HEADROOM_BASE_URL%
) else (
    echo   %ESC%[1;33m. %ESC%[0m Hermes %ESC%[2m^(model.base_url^)%ESC%[0m — напрямую в DeepSeek
)
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановить/Обновить HeadRoom%ESC%[0m
echo       %ESC%[2mСвежий wheel из GitHub, venv, служба с автозапуском%ESC%[0m
if !HEADROOM_INSTALLED! equ 1 (
echo.
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mПереустановить службу%ESC%[0m
echo       %ESC%[2mЕсли прокси не стартует или путь установки изменился%ESC%[0m
)

if !HEADROOM_SVC! equ 1 (
echo.
echo   %ESC%[1;31m[3]%ESC%[0m %ESC%[1;31mУдалить службу%ESC%[0m
echo       %ESC%[2mПрокси остановится — сжатие отключится до переустановки%ESC%[0m
echo.
echo   %ESC%[1;31m[7]%ESC%[0m %ESC%[1;31mПОЛНЫЙ СНОС HeadRoom%ESC%[0m
echo       %ESC%[2mСлужба + каталог целиком. Чистая переустановка через [1]%ESC%[0m
)
if !HEADROOM_INSTALLED! equ 1 (
echo.
echo   %ESC%[1;37m[4]%ESC%[0m %ESC%[1mСтатус и экономия%ESC%[0m
echo       %ESC%[2mСводка: запросы, сэкономленные токены, деньги%ESC%[0m
echo.
echo   %ESC%[1;37m[6]%ESC%[0m %ESC%[1mПодключить/Отключить прокси в Hermes%ESC%[0m
echo       %ESC%[2mТумблер: model.base_url на прокси ^(или обратно на DeepSeek^)%ESC%[0m
)
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие: %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" exit /b 0
if "%choice%"=="1" goto install
if "%choice%"=="2" (
    if !HEADROOM_INSTALLED! equ 0 (
        echo   %ESC%[1;31m[ОШИБКА] HeadRoom не установлен — сначала пункт [1].%ESC%[0m
        pause
        goto menu
    )
    goto svc_reinstall
)
if "%choice%"=="3" goto svc_remove
if "%choice%"=="4" (
    if !HEADROOM_INSTALLED! equ 0 (
        echo   %ESC%[1;31m[ОШИБКА] HeadRoom не установлен — сначала пункт [1].%ESC%[0m
        pause
        goto menu
    )
    goto stats
)
if "%choice%"=="6" (
    if !HEADROOM_INSTALLED! equ 0 (
        echo   %ESC%[1;31m[ОШИБКА] HeadRoom не установлен — сначала пункт [1].%ESC%[0m
        pause
        goto menu
    )
    goto toggle_proxy
)
if "%choice%"=="7" goto headroom_nuke
goto menu

REM ============================================================================
REM   [1] Установка / обновление (нужен администратор для службы)
REM ============================================================================
:install
if "!IS_ADMIN!"=="0" (
    echo.
    echo   %ESC%[1;33m  Требуются права администратора — запрашиваю UAC...%ESC%[0m
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process cmd -Verb RunAs -ArgumentList '/c','""%~f0"" install' -Wait } catch { exit 1 }"
    if errorlevel 1 (
        echo   %ESC%[1;31m[ОШИБКА] UAC отклонён — установка отменена.%ESC%[0m
        pause
        goto status
    )
    goto status
)
call :do_install
goto status

:do_install
cls
echo.
echo  %ESC%[1;33m- %ESC%[0m %ESC%[1mУстановка/обновление HeadRoom...%ESC%[0m
echo.
call "%SCRIPTS_DIR%\Backup-Now.bat"

if not exist "%UV_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] uv не найден: %UV_EXE%%ESC%[0m
    echo   %ESC%[33mСначала установите uv через меню «Установка / Обновление компонентов».%ESC%[0m
    pause
    exit /b 1
)

if not exist "%HEADROOM_DIR%" mkdir "%HEADROOM_DIR%" 2>nul

REM --- Актуальная версия и URL wheel через GitHub API ---
echo   %ESC%[2m  Запрашиваю последний релиз %HEADROOM_REPO% ...%ESC%[0m
set "HR_WHEEL_URL="
for /f "delims=" %%u in ('powershell -NoProfile -NonInteractive -Command "$v=(Invoke-RestMethod -Uri 'https://api.github.com/repos/%HEADROOM_REPO%/releases/latest' -UseBasicParsing -TimeoutSec 30).tag_name; Write-Output ('https://github.com/%HEADROOM_REPO%/releases/download/' + $v + '/headroom_ai-' + $v.Substring(1) + '-cp310-abi3-win_amd64.whl')" 2^>nul') do set "HR_WHEEL_URL=%%u"
if not defined HR_WHEEL_URL (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось получить последний релиз с GitHub.%ESC%[0m
    pause
    exit /b 1
)
echo   %ESC%[1;32m  URL: %HR_WHEEL_URL%%ESC%[0m

REM --- Скачивание wheel ---
set "HR_WHEEL=%TEMP%\headroom_latest.whl"
call :download "%HR_WHEEL_URL%" "%HR_WHEEL%" "headroom wheel"
if errorlevel 1 exit /b 1

REM --- Создание venv (python 3.13, скачается uv'ом при необходимости) ---
echo   %ESC%[2m  Создание виртуального окружения...%ESC%[0m
if exist "%HEADROOM_VENV%" (
    echo   %ESC%[2m  Чищу старый venv — обновление экстров ^(proxy,ml,code^) гарантировано...%ESC%[0m
    rmdir /s /q "%HEADROOM_VENV%"
)
"%UV_EXE%" venv "%HEADROOM_VENV%" --python 3.13
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось создать venv.%ESC%[0m
    pause
    exit /b 1
)

REM --- Установка пакета из wheel ---
echo   %ESC%[2m  Установка headroom ^(это займёт пару минут — зависимости тяжелые^)...%ESC%[0m
"%UV_EXE%" pip install --python "%HEADROOM_PY%" "headroom-ai[%HEADROOM_EXTRAS%] @ %HR_WHEEL_URL%"
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Установка пакета не удалась.%ESC%[0m
    pause
    exit /b 1
)
del /q "%HR_WHEEL%" 2>nul

if not exist "%HEADROOM_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] headroom.exe не найден после установки.%ESC%[0m
    pause
    exit /b 1
)
for /f "delims=" %%v in ('"%HEADROOM_EXE%" --version 2^>nul') do echo   %ESC%[1;32m+ %ESC%[0m HeadRoom %%v — установлен

REM --- NSSM (обёртка службы) — скачается автоматически, если нет ---
call :ensure_nssm
if errorlevel 1 (
    pause
    exit /b 1
)

REM --- Установка службы ---
call :install_service
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Служба не установлена. Смотрите вывод выше.%ESC%[0m
    pause
    exit /b 1
)
echo.
echo  %ESC%[1;32m+ %ESC%[0m HeadRoom установлен: %HEADROOM_DIR%
echo  %ESC%[2m  Порт %HEADROOM_PORT%, режим cache, upstream %HEADROOM_UPSTREAM%%ESC%[0m
echo  %ESC%[2m  Hermes должен указывать на http://127.0.0.1:%HEADROOM_PORT%/v1%ESC%[0m
echo.
REM ============================================================================
REM   ТРОЙНАЯ ПЕРЕСТРАХОВКА: модель + реестр + проверка сжатия
REM   Если хоть один шаг не удался — установка СЧИТАЕТСЯ ПРОВАЛЕННОЙ.
REM ============================================================================
call :hr_ensure_model
if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Модель Kompress НЕ скачана — сжатие работать НЕ будет!%ESC%[0m
    echo   %ESC%[33mHeadRoom установлен, но без сжатия. Повтори установку позже.%ESC%[0m
    pause
    exit /b 1
)
call :hr_set_hf_env
if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Не удалось прописать HF_HOME службе — сжатие работать НЕ будет!%ESC%[0m
    pause
    exit /b 1
)
call :hr_restart_service
if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Служба не перезапустилась после настройки.%ESC%[0m
    pause
    exit /b 1
)
call :hr_verify_compress
if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] ПРОВЕРКА СЖАТИЯ НЕ ПРОЙДЕНА!%ESC%[0m
    echo   %ESC%[33mHeadRoom работает, но НЕ сжимает контекст — деньги уходят без экономии.%ESC%[0m
    pause
    exit /b 1
)
echo   %ESC%[1;32m+ %ESC%[0m Компрессия ПОДТВЕРЖДЕНА: контекст реально сжимается.
echo.
REM --- Подключаем Hermes к прокси (model.base_url) ---
call :hr_enable_proxy
call :hr_need_restart
echo.
pause
exit /b 0

REM ============================================================================
REM   [2] Переустановка службы
REM ============================================================================
:svc_reinstall
if not exist "%HEADROOM_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] HeadRoom не установлен. Сначала пункт [1].%ESC%[0m
    pause
    goto status
)
if "!IS_ADMIN!"=="0" (
    echo.
    echo   %ESC%[1;33m  Требуются права администратора — запрашиваю UAC...%ESC%[0m
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process cmd -Verb RunAs -ArgumentList '/c','""%~f0"" svc_reinstall' -Wait } catch { exit 1 }"
    if errorlevel 1 (
        echo   %ESC%[1;31m[ОШИБКА] UAC отклонён.%ESC%[0m
        pause
        goto status
    )
    goto status
)
call :do_svc_reinstall
goto status

:do_svc_reinstall
call :install_service
if errorlevel 1 pause
pause
exit /b 0

REM ============================================================================
REM   [3] Удаление службы
REM ============================================================================
:svc_remove
if "!IS_ADMIN!"=="0" (
    echo.
    echo   %ESC%[1;33m  Требуются права администратора — запрашиваю UAC...%ESC%[0m
    powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process cmd -Verb RunAs -ArgumentList '/c','""%~f0"" svc_remove' -Wait } catch { exit 1 }"
    if errorlevel 1 (
        echo   %ESC%[1;31m[ОШИБКА] UAC отклонён.%ESC%[0m
        pause
        goto status
    )
    goto status
)
call :do_svc_remove
goto status

:do_svc_remove
echo   %ESC%[2m  Останавливаю и удаляю службу Headroom...%ESC%[0m
if exist "%HEADROOM_NSSM%" (
    "%HEADROOM_NSSM%" stop Headroom >nul 2>&1
    "%HEADROOM_NSSM%" remove Headroom confirm
) else (
    sc stop Headroom >nul 2>&1
    sc delete Headroom >nul 2>&1
)
echo   %ESC%[1;32m+ %ESC%[0m Служба удалена. Файлы в %HEADROOM_DIR% сохранены.
echo.
REM --- Возвращаем Hermes на прямой DeepSeek (base_url) ---
call :hr_disable_proxy
call :hr_need_restart
pause
exit /b 0

REM ============================================================================
REM   [7] ПОЛНЫЙ СНОС HeadRoom: служба + каталог целиком
REM   Порядок: ДА → UAC → удаление. Повторный запуск с параметром
REM   headroom_nuke (после UAC) — подтверждение пропускается.
REM ============================================================================
:headroom_nuke
if /i not "%~1"=="headroom_nuke" (
    echo   %ESC%[1;33m  ВНИМАНИЕ: будет удалена СЛУЖБА и КАТАЛОГ %HEADROOM_DIR% целиком.%ESC%[0m
    set "nuke_confirm="
    set /p "nuke_confirm=%ESC%[31m  Точно снести? Введи ДА: %ESC%[0m"
    if /i not "%nuke_confirm%"=="ДА" (
        echo   %ESC%[2m  Отменено.%ESC%[0m
        pause
        goto status
    )
    if "!IS_ADMIN!"=="0" (
        echo.
        echo   %ESC%[1;33m  Требуются права администратора — запрашиваю UAC...%ESC%[0m
        powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Start-Process cmd -Verb RunAs -ArgumentList '/c','""%~f0"" headroom_nuke' -Wait } catch { exit 1 }"
        if errorlevel 1 (
            echo   %ESC%[1;31m[ОШИБКА] UAC отклонён.%ESC%[0m
            pause
            goto status
        )
        goto status
    )
)
echo   %ESC%[2m  Останавливаю и удаляю службу Headroom...%ESC%[0m
if exist "%HEADROOM_NSSM%" (
    "%HEADROOM_NSSM%" stop Headroom >nul 2>&1
    "%HEADROOM_NSSM%" remove Headroom confirm >nul 2>&1
) else (
    sc stop Headroom >nul 2>&1
    sc delete Headroom >nul 2>&1
)
echo   %ESC%[1;32m+ %ESC%[0m Служба удалена.
REM --- Сначала возвращаем Hermes на прямой DeepSeek (пока saved_base_url.txt жив) ---
call :hr_disable_proxy
echo   %ESC%[2m  Удаляю каталог %HEADROOM_DIR% ...%ESC%[0m
if exist "%HEADROOM_DIR%" (
    rmdir /s /q "%HEADROOM_DIR%"
    echo   %ESC%[1;32m+ %ESC%[0m Каталог удалён.
) else (
    echo   %ESC%[2m  Каталог и так отсутствует.%ESC%[0m
)
echo   %ESC%[1;32m+ %ESC%[0m HeadRoom полностью снесён. Чистая установка — пункт [1].
call :hr_need_restart
pause
exit /b 0

REM ============================================================================
REM   [4] Статус и экономия
REM ============================================================================
:stats
if not exist "%HEADROOM_PY%" (
    echo   %ESC%[1;31m[ОШИБКА] HeadRoom не установлен. Сначала пункт [1].%ESC%[0m
    pause
    goto status
)
if not exist "%HEADROOM_STATS%" (
    echo   %ESC%[1;31m[ОШИБКА] Не найден headroom_stats.py в %SCRIPTS_DIR%\py%ESC%[0m
    pause
    goto status
)
"%HEADROOM_PY%" "%HEADROOM_STATS%"
echo.
pause
goto status

REM ============================================================================
REM   :hr_get_current — текущий model.base_url в HR_CUR; HR_HERMES_OK=1 если hermes есть
REM   Каноничная схема: провайдер deepseek-hr.base_url (а НЕ глобальный model.base_url!)
REM ============================================================================
:hr_get_current
set "HR_HERMES_OK=0"
set "HR_CUR="
set "HR_HR_OK=0"
if exist "%HERMES_BIN%" (
    for /f "delims=" %%u in ('"%HERMES_BIN%" config get providers.deepseek-hr.base_url 2^>nul ^| findstr /V /C:"not set"') do set "HR_CUR=%%u"
    if defined HR_CUR (
        set "HR_HR_OK=1"
        set "HR_HERMES_OK=1"
    ) else (
        for /f "delims=" %%u in ('"%HERMES_BIN%" config get model.base_url 2^>nul ^| findstr /V /C:"not set"') do set "HR_CUR=%%u"
        if defined HR_CUR set "HR_HERMES_OK=1"
    )
)
exit /b 0

REM ============================================================================
REM   :hr_enable_proxy — сохранить текущий base_url и переключить Hermes на прокси
REM ============================================================================
:hr_enable_proxy
call :hr_get_current
if "!HR_HERMES_OK!"=="0" (
    echo   %ESC%[1;33m  ВНИМАНИЕ: hermes.exe не найден - настройка base_url пропущена.%ESC%[0m
    echo   %ESC%[33m  Выполни позже: hermes config set model.base_url %HEADROOM_BASE_URL%%ESC%[0m
    exit /b 0
)
if "!HR_CUR!"=="%HEADROOM_BASE_URL%" (
    echo   %ESC%[1;32m+ %ESC%[0m Hermes уже настроен на прокси: %HEADROOM_BASE_URL%
    exit /b 0
)
echo   %ESC%[2m  Сохраняю текущий base_url ^(%HR_CUR%^) и переключаю Hermes на прокси...%ESC%[0m
> "%HEADROOM_SAVED_URL%" echo %HR_CUR%
if "!HR_HR_OK!"=="1" (
    "%HERMES_BIN%" config set providers.deepseek-hr.base_url "%HEADROOM_BASE_URL%" >nul 2>&1
) else (
    "%HERMES_BIN%" config set model.base_url "%HEADROOM_BASE_URL%" >nul 2>&1
)
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось изменить base_url.%ESC%[0m
    exit /b 0
)
if "!HR_HR_OK!"=="1" (
    echo   %ESC%[1;32m+ %ESC%[0m Hermes подключён к прокси: providers.deepseek-hr.base_url = %HEADROOM_BASE_URL%
) else (
    echo   %ESC%[1;32m+ %ESC%[0m Hermes подключён к прокси: model.base_url = %HEADROOM_BASE_URL%
)
exit /b 0

REM ============================================================================
REM   :hr_disable_proxy — вернуть сохранённый base_url (прямой DeepSeek)
REM ============================================================================
:hr_disable_proxy
call :hr_get_current
if "!HR_HERMES_OK!"=="0" (
    echo   %ESC%[1;33m  ВНИМАНИЕ: hermes.exe не найден - откат base_url пропущен.%ESC%[0m
    exit /b 0
)
if not "!HR_CUR!"=="%HEADROOM_BASE_URL%" (
    echo   %ESC%[2m  Hermes и так не на прокси ^(%HR_CUR%^) - откат не нужен.%ESC%[0m
    exit /b 0
)
if not exist "%HEADROOM_SAVED_URL%" (
    echo   %ESC%[1;33m  Предупреждение: сохранённый base_url не найден.%ESC%[0m
    if "!HR_HR_OK!"=="1" (
        echo   %ESC%[33m  Откат не выполнен. Верни вручную: hermes config set providers.deepseek-hr.base_url https://api.deepseek.com/v1%ESC%[0m
    ) else (
        echo   %ESC%[33m  Откат не выполнен. Верни вручную: hermes config set model.base_url https://api.deepseek.com/v1%ESC%[0m
    )
    exit /b 0
)
set "HR_SAVED="
for /f "delims=" %%u in ('type "%HEADROOM_SAVED_URL%" 2^>nul') do set "HR_SAVED=%%u"
if not defined HR_SAVED (
    echo   %ESC%[1;33m  Предупреждение: файл %HEADROOM_SAVED_URL% пуст - откат не выполнен.%ESC%[0m
    exit /b 0
)
if "!HR_HR_OK!"=="1" (
    "%HERMES_BIN%" config set providers.deepseek-hr.base_url "%HR_SAVED%" >nul 2>&1
) else (
    "%HERMES_BIN%" config set model.base_url "%HR_SAVED%" >nul 2>&1
)
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось восстановить base_url.%ESC%[0m
    exit /b 0
)
if "!HR_HR_OK!"=="1" (
    echo   %ESC%[1;32m+ %ESC%[0m Hermes возвращён: providers.deepseek-hr.base_url = %HR_SAVED%
) else (
    echo   %ESC%[1;32m+ %ESC%[0m Hermes возвращён: model.base_url = %HR_SAVED%
)
exit /b 0

REM ============================================================================
REM   :hr_need_restart — напоминание о перезапуске Desktop
REM ============================================================================
:hr_need_restart
echo.
echo   %ESC%[1;33m  ВАЖНО: перезапусти Hermes Desktop, чтобы изменения base_url применились.%ESC%[0m
exit /b 0

REM ============================================================================
REM   :hr_ensure_model — скачать модель Kompress в HF_HOME (портабельно).
REM   Скачивает напрямую, при неудаче — через прокси 10809. Проверяет ONNX.
REM   Выход: 0 = модель на месте, 1 = НЕ скачана (установка провалена).
REM ============================================================================
:hr_ensure_model
if not exist "%HEADROOM_PY%" (
    echo   %ESC%[1;31m[ОШИБКА] python venv headroom не найден: %HEADROOM_PY%%ESC%[0m
    exit /b 1
)
if not exist "%SCRIPTS_DIR%\py\headroom_download_model.py" (
    echo   %ESC%[1;31m[ОШИБКА] Не найден скрипт скачивания: %SCRIPTS_DIR%\py\headroom_download_model.py%ESC%[0m
    exit /b 1
)
echo   %ESC%[2m  Модель Kompress (%HEADROOM_HF_MODEL%)...%ESC%[0m
if not exist "%HEADROOM_HF_HOME%\hub" mkdir "%HEADROOM_HF_HOME%\hub" 2>nul
set "HF_HOME=%HEADROOM_HF_HOME%"
"%HEADROOM_PY%" "%SCRIPTS_DIR%\py\headroom_download_model.py"
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Модель Kompress не скачана (напрямую и через прокси 10809).%ESC%[0m
    echo   %ESC%[33mПроверь интернет/прокси и повтори установку.%ESC%[0m
    exit /b 1
)
echo   %ESC%[1;32m+ %ESC%[0m Модель Kompress скачана в %HEADROOM_HF_HOME%
exit /b 0

REM ============================================================================
REM   :hr_set_hf_env — прописать HF_HOME службе Headroom (реестр NSSM).
REM   Через headroom_set_hf_env.ps1 (от админа), с обратной проверкой.
REM   Выход: 0 = записано и ПРОВЕРЕНО, 1 = не удалось.
REM ============================================================================
:hr_set_hf_env
if not exist "%SCRIPTS_DIR%\py\headroom_set_hf_env.ps1" (
    echo   %ESC%[1;31m[ОШИБКА] Не найден %SCRIPTS_DIR%\py\headroom_set_hf_env.ps1%ESC%[0m
    exit /b 1
)
echo   %ESC%[2m  Прописываю HF_HOME службе Headroom...%ESC%[0m
REM --- Путь 1: ps1 (с обратной проверкой внутри) ---
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\py\headroom_set_hf_env.ps1" -HeadroomDir "%HEADROOM_DIR%" -HfHome "%HEADROOM_HF_HOME%"
if errorlevel 1 (
    echo   %ESC%[1;33m  ps1 не сработал — пробую reg add напрямую...%ESC%[0m
)
REM --- Проверка: записалось ли HF_HOME ---
set "HF_CHECK="
for /f "delims=" %%u in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\Headroom\Parameters" /v AppEnvironmentExtra 2^>nul ^| findstr /C:"HF_HOME="') do set "HF_CHECK=%%u"
if not defined HF_CHECK (
    echo   %ESC%[2m  Путь 2: reg add (дублирующая запись)...%ESC%[0m
    reg add "HKLM\SYSTEM\CurrentControlSet\Services\Headroom\Parameters" /v AppEnvironmentExtra /t REG_MULTI_SZ /d "HEADROOM_WORKSPACE_DIR=%HEADROOM_DIR%\workspace\0HF_HOME=%HEADROOM_HF_HOME%" /f >nul 2>&1
    set "HF_CHECK="
    for /f "delims=" %%u in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\Headroom\Parameters" /v AppEnvironmentExtra 2^>nul ^| findstr /C:"HF_HOME="') do set "HF_CHECK=%%u"
)
if not defined HF_CHECK (
    echo   %ESC%[1;31m[ОШИБКА] Проверка реестра не нашла HF_HOME — запись не применилась.%ESC%[0m
    exit /b 1
)
echo   %ESC%[1;32m+ %ESC%[0m HF_HOME прописан и проверен: %HEADROOM_HF_HOME%
exit /b 0

REM ============================================================================
REM   :hr_restart_service — перезапуск службы Headroom с ожиданием RUNNING.
REM   Выход: 0 = служба RUNNING, 1 = не поднялась.
REM ============================================================================
:hr_restart_service
echo   %ESC%[2m  Перезапускаю службу Headroom...%ESC%[0m
if exist "%HEADROOM_NSSM%" (
    "%HEADROOM_NSSM%" stop Headroom >nul 2>&1
    timeout /t 2 /nobreak >nul 2>&1
    "%HEADROOM_NSSM%" start Headroom >nul 2>&1
) else (
    sc stop Headroom >nul 2>&1
    timeout /t 2 /nobreak >nul 2>&1
    sc start Headroom >nul 2>&1
)
timeout /t 5 /nobreak >nul 2>&1
set "HR_STATE="
for /f "delims=" %%u in ('sc query Headroom 2^>nul ^| findstr /C:"RUNNING"') do set "HR_STATE=%%u"
if not defined HR_STATE (
    echo   %ESC%[1;31m[ОШИБКА] Служба Headroom не перешла в RUNNING после перезапуска.%ESC%[0m
    exit /b 1
)
echo   %ESC%[1;32m+ %ESC%[0m Служба Headroom RUNNING.
exit /b 0

REM ============================================================================
REM   :hr_verify_compress — ЖЁСТКАЯ проверка: health + реальный тест сжатия.
REM   Выход: 0 = сжатие подтверждено, 1 = НЕ работает (установка провалена).
REM ============================================================================
:hr_verify_compress
if not exist "%SCRIPTS_DIR%\py\headroom_verify_compress.py" (
    echo   %ESC%[1;31m[ОШИБКА] Не найден скрипт проверки: %SCRIPTS_DIR%\py\headroom_verify_compress.py%ESC%[0m
    exit /b 1
)
echo   %ESC%[2m  Проверяю сжатие (health + реальный тест /v1/compress)...%ESC%[0m
"%HEADROOM_PY%" "%SCRIPTS_DIR%\py\headroom_verify_compress.py"
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Сжатие НЕ работает (noop/degraded).%ESC%[0m
    exit /b 1
)
echo   %ESC%[1;32m+ %ESC%[0m Сжатие подтверждено.
exit /b 0

REM ============================================================================
REM   [6] Тумблер: подключить/отключить прокси в Hermes
REM ============================================================================
:toggle_proxy
if not exist "%HERMES_BIN%" (
    echo   %ESC%[1;31m[ОШИБКА] hermes.exe не найден: %HERMES_BIN%%ESC%[0m
    pause
    goto status
)
call :hr_get_current
if "!HR_CUR!"=="%HEADROOM_BASE_URL%" (
    call :hr_disable_proxy
) else (
    call :hr_enable_proxy
)
call :hr_need_restart
pause
goto status

REM ============================================================================
REM   :ensure_nssm — гарантировать наличие nssm.exe (скачать при необходимости)
REM ============================================================================
:ensure_nssm
if exist "%HEADROOM_NSSM%" exit /b 0
echo   %ESC%[2m  NSSM не найден — скачиваю...%ESC%[0m
call :download "%HEADROOM_NSSM_URL%" "%HEADROOM_NSSM_ZIP%" "nssm-2.24.zip"
if errorlevel 1 exit /b 1
set "NSSM_UNPACK=%TEMP%\nssm-unpack"
if exist "%NSSM_UNPACK%" rmdir /s /q "%NSSM_UNPACK%" 2>nul
mkdir "%NSSM_UNPACK%" 2>nul
call :unzip "%HEADROOM_NSSM_ZIP%" "%NSSM_UNPACK%"
if not exist "%HEADROOM_DIR%\nssm" mkdir "%HEADROOM_DIR%\nssm" 2>nul
if exist "%NSSM_UNPACK%\nssm-2.24\win64\nssm.exe" (
    copy /Y "%NSSM_UNPACK%\nssm-2.24\win64\nssm.exe" "%HEADROOM_NSSM%" >nul
)
rmdir /s /q "%NSSM_UNPACK%" 2>nul
del /q "%HEADROOM_NSSM_ZIP%" 2>nul
if not exist "%HEADROOM_NSSM%" (
    echo   %ESC%[1;31m[ОШИБКА] nssm.exe не удалось получить.%ESC%[0m
    echo   %ESC%[33mСкачай nssm-2.24.zip вручную и положи nssm.exe в %HEADROOM_DIR%\nssm\%ESC%[0m
    exit /b 1
)
exit /b 0

REM ============================================================================
REM   :install_service — пересоздание службы Headroom через NSSM (нужен админ)
REM ============================================================================
:install_service
if not exist "%HEADROOM_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] headroom.exe не найден: %HEADROOM_EXE%%ESC%[0m
    echo   %ESC%[33mСначала установите HeadRoom через [1] «Установить/Обновить».%ESC%[0m
    exit /b 1
)
call :ensure_nssm
if errorlevel 1 exit /b 1
echo   %ESC%[2m  Настройка службы Headroom...%ESC%[0m
"%HEADROOM_NSSM%" stop Headroom >nul 2>&1
"%HEADROOM_NSSM%" remove Headroom confirm >nul 2>&1
"%HEADROOM_NSSM%" install Headroom "%HEADROOM_EXE%" proxy --openai-api-url %HEADROOM_UPSTREAM% --port %HEADROOM_PORT% --mode cache
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] nssm install не удался.%ESC%[0m
    exit /b 1
)
"%HEADROOM_NSSM%" set Headroom AppDirectory "%HEADROOM_DIR%"
"%HEADROOM_NSSM%" set Headroom AppStdout "%HEADROOM_DIR%\headroom.log"
"%HEADROOM_NSSM%" set Headroom AppStderr "%HEADROOM_DIR%\headroom.err.log"
"%HEADROOM_NSSM%" set Headroom AppRotateFiles 1
"%HEADROOM_NSSM%" set Headroom AppRotateBytes 10485760
"%HEADROOM_NSSM%" set Headroom DisplayName "Headroom AI proxy"
"%HEADROOM_NSSM%" set Headroom Description "Compression proxy for LLM (Hermes -> DeepSeek), port %HEADROOM_PORT%"
"%HEADROOM_NSSM%" set Headroom Start SERVICE_AUTO_START
"%HEADROOM_NSSM%" set Headroom AppEnvironmentExtra "HEADROOM_WORKSPACE_DIR=%HEADROOM_DIR%\workspace"
"%HEADROOM_NSSM%" start Headroom
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Служба не запустилась. Лог: %HEADROOM_DIR%\headroom.err.log%ESC%[0m
    exit /b 1
)
sc query Headroom | findstr STATE
exit /b 0

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
"%CURL%" -L --fail --noproxy "*" -C - -o "%DL_FILE%" "%DL_URL%"
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m  Напрямую не вышло - пробуем через прокси 10809...%ESC%[0m
    "%CURL%" -L --fail -x "http://127.0.0.1:10809" -C - --retry 8 --retry-delay 3 --retry-all-errors -o "%DL_FILE%" "%DL_URL%"
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
if errorlevel 1 exit /b 1
exit /b 0
