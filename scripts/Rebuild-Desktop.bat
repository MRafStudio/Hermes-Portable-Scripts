@REM scripts\Rebuild-Desktop.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Параметры: 1 = AUTOCLOSE (не ждать нажатия клавиши)
REM ============================================================================
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Пересборка Desktop

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DESKTOP_DIR=%REPO_DIR%\apps\desktop"
set "NODE_DIR=%HERMES_HOME%\node"
set "NODE_EXE=%NODE_DIR%\node.exe"
set "UV_DIR=%HERMES_HOME%\bin"
set "UV_EXE=%UV_DIR%\uv.exe"
set "VENV_PYTHON=%REPO_DIR%\venv\Scripts\python.exe"

REM Пути к файлам локализации
set "RU_LOCALE_DIR=%SCRIPTS_DIR%\ru-locale"
set "I18N_DIR=%REPO_DIR%\apps\desktop\src\i18n"
set "SETTINGS_DIR=%REPO_DIR%\apps\desktop\src\app\settings"

REM ============================================================================
REM   Сохраняем РЕАЛЬНЫЕ пути ДО изоляции
REM   (нужны для поиска глобального Node.js)
REM ============================================================================
set "REAL_LOCALAPPDATA=%LOCALAPPDATA%"
set "REAL_APPDATA=%APPDATA%"

REM ============================================================================
REM   Изоляция данных (ничего в систему!)
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "PYTHONUSERBASE=%DATA_DIR%\python-userbase"
set "PYTHONPATH="
set "PYTHONHOME="
set "PYTHONSTARTUP="
set "PYTHONIOENCODING=utf-8"
set "PIP_CACHE_DIR=%TEMP%\pip-cache"
set "HF_HOME=%DATA_DIR%\huggingface"
set "HF_HUB_DISABLE_SYMLINKS=1"
set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"

REM ============================================================================
REM   Создание директорий
REM ============================================================================
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%HOME%\Desktop" mkdir "%HOME%\Desktop" 2>nul
if not exist "%PYTHONUSERBASE%" mkdir "%PYTHONUSERBASE%" 2>nul
if not exist "%HF_HOME%" mkdir "%HF_HOME%" 2>nul
if not exist "%PIP_CACHE_DIR%" mkdir "%PIP_CACHE_DIR%" 2>nul
if not exist "%HERMES_HOME%" mkdir "%HERMES_HOME%" 2>nul

REM ============================================================================
REM   ПОЛНАЯ ИЗОЛЯЦИЯ PATH
REM ============================================================================
set "PATH=%NODE_DIR%;%HERMES_HOME%\bin;%ProgramFiles%\Git\cmd;%windir%\system32;%windir%;%windir%\System32\Wbem;%windir%\System32\WindowsPowerShell\v1.0"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Определение Node.js (глобальный -> локальный) — ДО любых операций!
REM   Это скрипт пересборки: Node обязателен. Нет ни глобального,
REM   ни локального — сообщаем и выходим (установка через главное меню).
REM ============================================================================
set "NODE_CMD="
set "NPM_CMD="
set "IS_GLOBAL_NODE=0"
set "GLOBAL_NODE="

REM --- 1. Глобальный Node.js: стандартные пути (ПРИОРИТЕТ) ---
if exist "%ProgramFiles%\nodejs\node.exe" set "GLOBAL_NODE=%ProgramFiles%\nodejs"
if not defined GLOBAL_NODE if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "GLOBAL_NODE=%ProgramFiles(x86)%\nodejs"
if not defined GLOBAL_NODE if exist "%REAL_LOCALAPPDATA%\Programs\nodejs\node.exe" set "GLOBAL_NODE=%REAL_LOCALAPPDATA%\Programs\nodejs"

REM --- 2. Глобальный Node.js: реестр (HKLM + WOW6432Node + HKCU) ---
if not defined GLOBAL_NODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKLM\SOFTWARE\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" (
            if exist "%%c\node.exe" set "GLOBAL_NODE=%%c"
        )
    )
)
if not defined GLOBAL_NODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" (
            if exist "%%c\node.exe" set "GLOBAL_NODE=%%c"
        )
    )
)
if not defined GLOBAL_NODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKCU\SOFTWARE\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" (
            if exist "%%c\node.exe" set "GLOBAL_NODE=%%c"
        )
    )
)

if defined GLOBAL_NODE (
    set "NODE_CMD=!GLOBAL_NODE!\node.exe"
    set "NPM_CMD=!GLOBAL_NODE!\npm.cmd"
    set "IS_GLOBAL_NODE=1"
    REM --- СРАЗУ пересобираем PATH под глобальный Node.js ---
    set "PATH=!GLOBAL_NODE!;%HERMES_HOME%\bin;%ProgramFiles%\Git\cmd;%windir%\system32;%windir%;%windir%\System32\Wbem;%windir%\System32\WindowsPowerShell\v1.0"
    REM npm 12 из реального профиля имеет приоритет (свежий hermes-agent требует npm >=12; глобальный npm 11.16 несовместим)
    set "REAL_NPM_DIR="
    REM Портативный профиль (%APPDATA% -> data\appdata) содержит рабочий npm 12.x - он приоритетнее
    if exist "%APPDATA%\npm\npm.cmd" set "REAL_NPM_DIR=%APPDATA%\npm"
    if not defined REAL_NPM_DIR if exist "%SystemDrive%\Users\%USERNAME%\AppData\Roaming\npm\npm.cmd" set "REAL_NPM_DIR=%SystemDrive%\Users\%USERNAME%\AppData\Roaming\npm"
    if not defined REAL_NPM_DIR (
        for /d %%d in ("%SystemDrive%\Users\%USERNAME%.*") do (
            if not defined REAL_NPM_DIR (
                if exist "%%d\AppData\Roaming\npm\npm.cmd" set "REAL_NPM_DIR=%%d\AppData\Roaming\npm"
            )
        )
    )
    if defined REAL_NPM_DIR (
        set "NPM_CMD=!REAL_NPM_DIR!\npm.cmd"
        set "PATH=!REAL_NPM_DIR!;!PATH!"
    )
    goto :node_ready
)

REM --- 3. Локальный Node.js (fallback, если глобального нет) ---
if exist "%NODE_EXE%" (
    set "NODE_CMD=%NODE_EXE%"
    set "NPM_CMD=%NODE_DIR%\npm.cmd"
    goto :node_ready
)

REM --- Node.js не найден вообще: пересборка невозможна ---
cls
echo.
echo %ESC%[1;31m################################################################################%ESC%[0m
echo %ESC%[1;31m##                                                                            ##%ESC%[0m
echo %ESC%[1;31m##%ESC%[0m                        %ESC%[1;37mNode.js не найден в системе%ESC%[0m                         %ESC%[1;31m##%ESC%[0m
echo %ESC%[1;31m##                                                                            ##%ESC%[0m
echo %ESC%[1;31m################################################################################%ESC%[0m
echo.
echo %ESC%[1;31m[ОШИБКА] Node.js не найден ни глобально, ни локально.%ESC%[0m
echo.
echo %ESC%[1;33mПересборка Desktop невозможна без Node.js.%ESC%[0m
echo %ESC%[1;37m  Выполните полную установку через главное меню%ESC%[0m
echo %ESC%[1;37m  или запустите scripts\InstallOrUpdate-NodeJS.bat%ESC%[0m
echo.
if "%AUTOCLOSE%"=="0" pause
exit /b 1

:node_ready
REM ============================================================================
REM   Node.js/pnpm — общий резолвер (hermes-agent: engines.node ^>=26, pnpm 12.x).
REM   npm install в этом репозитории запрещён (pnpm-workspace.yaml, engines.npm),
REM   поэтому npm больше не обновляем: ставим и собираем через pnpm.
REM ============================================================================
call "%SCRIPTS_DIR%\Find-Node-Toolchain.bat"
if "!HAS_NODE!"=="1" set "NODE_EXE=!NODE_CMD!"
if "!NODE_TOO_OLD!"=="1" (
    echo %ESC%[1;33m[!]%ESC%[0m Node.js !NODE_VER! ниже требуемой ^(hermes-agent: engines.node ^>=26^).
)

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                 %ESC%[1;37mHermes Portable%ESC%[0m   —   %ESC%[1;33mПересборка Desktop%ESC%[0m                   %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM --- Какой Node.js выбран (определён выше) ---
if "!IS_GLOBAL_NODE!"=="1" (
    echo   %ESC%[1;33m  .   Node.js: глобальный%ESC%[0m
    echo   %ESC%[2m       !GLOBAL_NODE!\%ESC%[0m
) else (
    echo   %ESC%[1;33m  .   Node.js: локальный%ESC%[0m
    echo   %ESC%[2m       %NODE_DIR%\%ESC%[0m
)

REM ============================================================================
REM   ШАГ 1: Проверка компонентов
REM ============================================================================
echo.
echo   %ESC%[1;33m[1/4]%ESC%[0m %ESC%[1mПроверка компонентов...%ESC%[0m

REM Проверяем репозиторий
if not exist "%REPO_DIR%\apps\desktop\package.json" (
    echo   %ESC%[1;31m[ОШИБКА] Desktop app не найден в репозитории!%ESC%[0m
    echo   %ESC%[33m       Сначала выполните полную установку через главное меню.%ESC%[0m
    goto error_exit
)

REM Инструменты локализации (схема A)
if not exist "%SCRIPTS_DIR%\py\i18n_sync_refs.py" (
    echo   %ESC%[1;31m[ОШИБКА] не найден SCRIPTS_DIR\py\i18n_sync_refs.py%ESC%[0m
    goto error_exit
)
if not exist "%SCRIPTS_DIR%\py\i18n_build_layer.py" (
    echo   %ESC%[1;31m[ОШИБКА] не найден SCRIPTS_DIR\py\i18n_build_layer.py%ESC%[0m
    goto error_exit
)

echo   %ESC%[1;32m  +   Компоненты на месте.%ESC%[0m

REM ============================================================================
REM   Проверка инструментов: rg, ffmpeg, playwright (доустановка при отсутствии)
REM ============================================================================
echo   %ESC%[1;33m  -   Проверка инструментов ^(rg, ffmpeg, playwright^)...%ESC%[0m

REM --- ripgrep (быстрый поиск, критичен для Hermes) ---
if not exist "%HERMES_HOME%\bin\rg.exe" (
    echo   %ESC%[1;33m  .   ripgrep отсутствует — устанавливаем...%ESC%[0m
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps1\install_rg.ps1" -HermesHome "%HERMES_HOME%"
)
if exist "%HERMES_HOME%\bin\rg.exe" (
    echo   %ESC%[1;32m  +   ripgrep: OK%ESC%[0m
) else (
    echo   %ESC%[1;33m  .   ripgrep не установлен ^(будет findstr^).%ESC%[0m
)

REM --- ffmpeg-набор (ffmpeg/ffprobe/ffplay: TTS, аудио, медиа) ---
if not exist "%HERMES_HOME%\bin\ffmpeg.exe" goto :install_ffmpeg_toolkit
if exist "%HERMES_HOME%\bin\ffprobe.exe" goto :ffmpeg_toolkit_ok
:install_ffmpeg_toolkit
echo   %ESC%[1;33m  .   ffmpeg-набор отсутствует — устанавливаем...%ESC%[0m
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps1\install_ffmpeg.ps1" -HermesHome "%HERMES_HOME%"
:ffmpeg_toolkit_ok
if exist "%HERMES_HOME%\bin\ffmpeg.exe" (
    if exist "%HERMES_HOME%\bin\ffprobe.exe" (
        echo   %ESC%[1;32m  +   ffmpeg-набор: OK%ESC%[0m
    ) else (
        echo   %ESC%[1;33m  .   ffmpeg не установлен ^(TTS ограничен^).%ESC%[0m
    )
) else (
    echo   %ESC%[1;33m  .   ffmpeg не установлен ^(TTS ограничен^).%ESC%[0m
)

REM --- Playwright (browser tools) ---
if not exist "%VENV_PYTHON%" (
    echo   %ESC%[1;33m  .   venv не найден — playwright пропущен.%ESC%[0m
) else (
    "%VENV_PYTHON%" -c "import playwright" >nul 2>nul
    if !errorlevel! neq 0 (
        echo   %ESC%[1;33m  .   playwright отсутствует — устанавливаем пакет...%ESC%[0m
        if exist "%UV_EXE%" (
            "%UV_EXE%" pip install --python "%VENV_PYTHON%" playwright
        ) else (
            echo   %ESC%[1;33m  .   uv не найден — пакет playwright не установлен.%ESC%[0m
        )
    )
    "%VENV_PYTHON%" -c "import playwright" >nul 2>nul
    if !errorlevel! equ 0 (
        echo   %ESC%[1;33m  .   Установка браузера Chromium ^(если ещё не установлен^)...%ESC%[0m
        "%VENV_PYTHON%" -m playwright install chromium
        echo   %ESC%[1;32m  +   Playwright: OK%ESC%[0m
    ) else (
        echo   %ESC%[1;33m  .   playwright пакет не установлен — browser tools ограничены.%ESC%[0m
    )
)

REM ============================================================================
REM   ШАГ 2: RU локализация (схема A: апстрим-база + наш слой ru-layer.ts)
REM   Эталоны, слой, установка ru.ts и настройки config.yaml — внутри вызываемого:
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/4]%ESC%[0m %ESC%[1mRU локализация (схема A)...%ESC%[0m

call "%SCRIPTS_DIR%\InstallOrUpdate-RU.bat" 1
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Установка RU локализации не удалась.%ESC%[0m
    goto error_exit
)
echo   %ESC%[1;32m  +   RU локализация установлена.%ESC%[0m

REM ============================================================================
REM   ОБЯЗАТЕЛЬНО: остановить службы Hermes ПЕРЕД пересборкой.
REM   Службы держат venv\Scripts\*.exe и файлы release: сборка падает с os error 32.
REM   Продолжаем только после реального STOPPED.
REM ============================================================================
call "%SCRIPTS_DIR%\Hermes-Services.bat" stop
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Службы Hermes не остановлены — пересборка прервана.%ESC%[0m
    echo   %ESC%[33m       Остановите их вручную ^(scripts\Stop-Hermes-Service.bat^) и повторите.%ESC%[0m
    goto error_exit
)

REM ============================================================================
REM   ШАГ 4: Пересборка Desktop с RU локализацией
REM ============================================================================
echo.
echo   %ESC%[1;33m[3/4]%ESC%[0m %ESC%[1mПересборка Desktop с RU локализацией...%ESC%[0m
echo   %ESC%[2m       Это может занять 1-3 минуты...%ESC%[0m

cd /d "%HERMES_HOME%\hermes-agent"

REM === Node.js уже определён в начале скрипта (NODE_CMD / NPM_CMD) ===
echo   %ESC%[1;33m  .   Используем Node.js:%ESC%[0m
echo   %ESC%[2m       !NODE_CMD!%ESC%[0m

REM Установка зависимостей в корне репо (workspace) — только pnpm
echo   %ESC%[1;33m  .   Установка зависимостей через pnpm...%ESC%[0m
if "!HAS_PNPM!"=="0" (
    echo   %ESC%[1;31m  [ОШИБКА] pnpm не найден ^(нужен !PNPM_EXPECTED!^).%ESC%[0m
    goto error_exit
)
call "!PNPM_CMD!" install --frozen-lockfile 2>&1
if errorlevel 1 (
    echo   %ESC%[1;31m  [ОШИБКА] Не удалось установить зависимости ^(pnpm^).%ESC%[0m
    goto error_exit
)
echo   %ESC%[1;32m  +   Зависимости установлены ^(pnpm^).%ESC%[0m

REM Electron-рантайм готовим ЯВНО: pnpm его postinstall не выполняет
REM (strictDepBuilds), и упаковка падает с "Electron binary is missing or stale".
REM Вызов идемпотентен: готовая dist проверяется и не скачивается заново.
if exist "%HERMES_HOME%\hermes-agent\scripts\build\electron-runtime.mjs" (
    echo   %ESC%[1;33m  .   Проверка Electron-рантайма...%ESC%[0m
    call "!NODE_CMD!" "%HERMES_HOME%\hermes-agent\scripts\build\electron-runtime.mjs" --source "%HERMES_HOME%\hermes-agent"
    if errorlevel 1 (
        echo   %ESC%[1;33m  !   Electron-рантайм не подготовлен — упаковка может упасть.%ESC%[0m
    ) else (
        echo   %ESC%[1;32m  +   Electron-рантайм готов.%ESC%[0m
    )
)

REM Добавляем node_modules/.bin в PATH
set "PATH=%HERMES_HOME%\hermes-agent\node_modules\.bin;%PATH%"

cd /d "%HERMES_HOME%\hermes-agent\apps\desktop"

REM Очистка кэша electron-builder для чистой пересборки
if exist "release" rmdir /s /q "release" 2>nul

REM Запускаем сборку
call "!NPM_CMD!" run pack 2>&1

if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Сборка Desktop не удалась.%ESC%[0m
    goto error_exit
)

echo   %ESC%[1;32m  +   Desktop собран.%ESC%[0m

REM Возвращаем службы, которые работали до пересборки
call "%SCRIPTS_DIR%\Hermes-Services.bat" start

REM ============================================================================
REM   ШАГ 5: Проверка результата
REM ============================================================================
echo.
echo   %ESC%[1;33m[4/4]%ESC%[0m %ESC%[1mПроверка результата...%ESC%[0m

set "EXE_FOUND=0"
set "EXE_PATH="

for %%P in (
    "%DESKTOP_DIR%\release\win-unpacked\Hermes.exe"
    "%DESKTOP_DIR%\release\win-ia32-unpacked\Hermes.exe"
    "%DESKTOP_DIR%\release\win-arm64-unpacked\Hermes.exe"
    "%DESKTOP_DIR%\release\win-x64-unpacked\Hermes.exe"
) do (
    if exist "%%P" (
        set "EXE_FOUND=1"
        set "EXE_PATH=%%P"
        goto :exe_found
    )
)

:exe_found
if !EXE_FOUND! equ 0 (
    echo   %ESC%[1;31m  -   Hermes.exe не найден после сборки!%ESC%[0m
    goto error_exit
)

echo   %ESC%[1;32m  +   Hermes.exe найден:%ESC%[0m
echo   %ESC%[2m       !EXE_PATH!%ESC%[0m

REM ============================================================================
REM   Завершение — УСПЕХ: сразу запускаем!
REM ============================================================================
echo.
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1;32mПересборка Desktop завершена!%ESC%[0m
echo   %ESC%[2m  Desktop: !EXE_PATH!%ESC%[0m
echo   %ESC%[2m  Язык:    Русский доступен в Settings → Appearance%ESC%[0m
echo   %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1;33mЗапуск Hermes...%ESC%[0m

REM === ЗАПУСК БЕЗ ОСТАНОВКИ ===
call "%SCRIPTS_DIR%\Start-Hermes-Desktop.bat" 1

echo   %ESC%[1;32m  +   Hermes запущен!%ESC%[0m
echo.
echo   %ESC%[1;32mОкно закроется через 3 секунды...%ESC%[0m
call "%SCRIPTS_DIR%\SmartPause.bat" 3
exit /b 0

REM ============================================================================
REM   ВЫХОДЫ
REM ============================================================================
:error_exit
REM Службы останавливались ради пересборки — возвращаем их, чтобы Hermes не остался лежать
call "%SCRIPTS_DIR%\Hermes-Services.bat" start >nul 2>&1
echo.
echo   %ESC%[1;31m[ОШИБКА] Пересборка прервана! Нажмите любую клавишу...%ESC%[0m
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause >nul
)
exit /b 1