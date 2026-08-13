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
    if exist "%SystemDrive%\Users\%USERNAME%\AppData\Roaming\npm\npm.cmd" set "REAL_NPM_DIR=%SystemDrive%\Users\%USERNAME%\AppData\Roaming\npm"
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
REM   Проверка версии npm — hermes-agent требует npm <11.10 или >=11.17
REM   Несовместимая версия (11.10-11.16 или <11.10) — авто-обновление до npm@12
REM ============================================================================
set "NPM_VER="
for /f "delims=" %%v in ('"!NPM_CMD!" --version 2^>nul') do set "NPM_VER=%%v"
set "NPM_MAJOR=0"
set "NPM_MINOR=0"
for /f "tokens=1,2 delims=." %%a in ("!NPM_VER!") do (
    set "NPM_MAJOR=%%a"
    set "NPM_MINOR=%%b"
)
set "NPM_NEEDS_UPDATE=0"
if !NPM_MAJOR! lss 11 set "NPM_NEEDS_UPDATE=1"
if !NPM_MAJOR! equ 11 (
    if !NPM_MINOR! geq 10 if !NPM_MINOR! lss 17 set "NPM_NEEDS_UPDATE=1"
)
if !NPM_NEEDS_UPDATE! equ 1 (
    echo.
    echo %ESC%[1;33m[i]%ESC%[0m npm !NPM_VER! несовместим с hermes-agent ^(нужен 11.17+ или 12^).
    if "!AUTOCLOSE!"=="1" (
        echo %ESC%[1;33m→%ESC%[0m Авто-обновление до npm@12...
    ) else (
        set /p "NPM_CHOICE=%ESC%[33mОбновить npm до 12? (Enter — да, N — нет): %ESC%[0m"
    )
    if /i "!NPM_CHOICE!"=="N" (
        echo %ESC%[1;33m  .   npm не обновлён — сборка может не пройти.%ESC%[0m
    ) else (
        echo %ESC%[1;33m→%ESC%[0m Обновляем npm до npm@12 в реальном профиле...
        echo %ESC%[2m    "!NPM_CMD!" install -g npm@12%ESC%[0m
        set "APPDATA=!REAL_APPDATA!"
        call "!NPM_CMD!" install -g npm@12
        if !errorlevel! equ 0 (
            echo %ESC%[1;32m+ %ESC%[0m npm обновлён до 12.
            set "REAL_NPM_DIR=!REAL_APPDATA!\npm"
            if exist "!REAL_NPM_DIR!\npm.cmd" set "NPM_CMD=!REAL_NPM_DIR!\npm.cmd"
        ) else (
            echo %ESC%[1;31m  [ОШИБКА] Не удалось обновить npm.%ESC%[0m
        )
        set "APPDATA=%DATA_DIR%\appdata"
    )
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
echo   %ESC%[1;33m[1/5]%ESC%[0m %ESC%[1mПроверка компонентов...%ESC%[0m

REM Проверяем репозиторий
if not exist "%REPO_DIR%\apps\desktop\package.json" (
    echo   %ESC%[1;31m[ОШИБКА] Desktop app не найден в репозитории!%ESC%[0m
    echo   %ESC%[33m       Сначала выполните полную установку через главное меню.%ESC%[0m
    goto error_exit
)

REM Проверяем файлы RU локализации
if not exist "%RU_LOCALE_DIR%\ru.ts" (
    echo   %ESC%[1;31m[ОШИБКА] ru.ts не найден в %RU_LOCALE_DIR%%ESC%[0m
    goto error_exit
)

if not exist "%RU_LOCALE_DIR%\ru-constants.ts" (
    echo   %ESC%[1;31m[ОШИБКА] ru-constants.ts не найден в %RU_LOCALE_DIR%%ESC%[0m
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

REM --- ffmpeg (TTS голосовые) ---
if not exist "%HERMES_HOME%\bin\ffmpeg.exe" (
    echo   %ESC%[1;33m  .   ffmpeg отсутствует — устанавливаем...%ESC%[0m
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps1\install_ffmpeg.ps1" -HermesHome "%HERMES_HOME%"
)
if exist "%HERMES_HOME%\bin\ffmpeg.exe" (
    echo   %ESC%[1;32m  +   ffmpeg: OK%ESC%[0m
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
REM   ШАГ 2: Копирование файлов RU локализации в репозиторий
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/5]%ESC%[0m %ESC%[1mКопирование файлов RU локализации...%ESC%[0m

copy /Y "%RU_LOCALE_DIR%\ru.ts" "%I18N_DIR%\ru.ts" >nul
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось скопировать ru.ts%ESC%[0m
    goto error_exit
)
echo   %ESC%[1;32m  +   ru.ts скопирован.%ESC%[0m

copy /Y "%RU_LOCALE_DIR%\ru-constants.ts" "%SETTINGS_DIR%\ru-constants.ts" >nul
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось скопировать ru-constants.ts%ESC%[0m
    goto error_exit
)
echo   %ESC%[1;32m  +   ru-constants.ts скопирован.%ESC%[0m

REM ============================================================================
REM   ШАГ 3: Патчим конфиги TypeScript
REM ============================================================================
echo.
echo   %ESC%[1;33m[3/5]%ESC%[0m %ESC%[1mПатчим конфиги TypeScript...%ESC%[0m

set "PATCH_DIR=%SCRIPTS_DIR%\ps"

REM --- types.ts ---
set "TYPES_FILE=%I18N_DIR%\types.ts"
if exist "%TYPES_FILE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PATCH_DIR%\patch_types.ps1" -FilePath "%TYPES_FILE%"
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   types.ts пропатчен.%ESC%[0m
    ) else if !errorlevel! equ 1 (
        echo   %ESC%[1;33m  .   types.ts уже содержит 'ru'.%ESC%[0m
    ) else (
        echo   %ESC%[1;31m  [ОШИБКА] patch_types.ps1 не сработал... Код: !errorlevel!%ESC%[0m
        goto error_exit
    )
)

REM --- languages.ts ---
set "LANG_FILE=%I18N_DIR%\languages.ts"
if exist "%LANG_FILE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PATCH_DIR%\patch_languages.ps1" -FilePath "%LANG_FILE%"
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   languages.ts пропатчен.%ESC%[0m
    ) else if !errorlevel! equ 1 (
        echo   %ESC%[1;33m  .   languages.ts уже содержит 'ru'.%ESC%[0m
    ) else (
        echo   %ESC%[1;31m  [ОШИБКА] patch_languages.ps1 не сработал... Код: !errorlevel!%ESC%[0m
        goto error_exit
    )
)

REM --- catalog.ts ---
set "CATALOG_FILE=%I18N_DIR%\catalog.ts"
if exist "%CATALOG_FILE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PATCH_DIR%\patch_catalog.ps1" -FilePath "%CATALOG_FILE%"
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   catalog.ts пропатчен.%ESC%[0m
    ) else if !errorlevel! equ 1 (
        echo   %ESC%[1;33m  .   catalog.ts уже содержит 'ru'.%ESC%[0m
    ) else (
        echo   %ESC%[1;31m  [ОШИБКА] patch_catalog.ps1 не сработал... Код: !errorlevel!%ESC%[0m
        goto error_exit
    )
)

REM Правим локализацию в config.yaml
echo.
set "CONFIG_YAML=%HERMES_HOME%\config.yaml"
if exist "%CONFIG_YAML%" (
    echo   %ESC%[1;33m  -   Обновление локализации в config.yaml...%ESC%[0m
    "%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe" config set display.language ru
)

REM ============================================================================
REM   ШАГ 4: Пересборка Desktop с RU локализацией
REM ============================================================================
echo.
echo   %ESC%[1;33m[4/5]%ESC%[0m %ESC%[1mПересборка Desktop с RU локализацией...%ESC%[0m
echo   %ESC%[2m       Это может занять 1-3 минуты...%ESC%[0m

cd /d "%HERMES_HOME%\hermes-agent"

REM === Node.js уже определён в начале скрипта (NODE_CMD / NPM_CMD) ===
echo   %ESC%[1;33m  .   Используем Node.js:%ESC%[0m
echo   %ESC%[2m       !NODE_CMD!%ESC%[0m

REM Установка npm-зависимостей в корне репо (workspace)
echo   %ESC%[1;33m  .   Установка npm-зависимостей...%ESC%[0m
call "!NPM_CMD!" install 2>&1
if errorlevel 1 (
    echo   %ESC%[1;31m  [ОШИБКА] Не удалось установить npm-зависимости.%ESC%[0m
    goto error_exit
)
echo   %ESC%[1;32m  +   npm-зависимости установлены.%ESC%[0m

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

REM ============================================================================
REM   ШАГ 5: Проверка результата
REM ============================================================================
echo.
echo   %ESC%[1;33m[5/5]%ESC%[0m %ESC%[1mПроверка результата...%ESC%[0m

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
echo.
echo   %ESC%[1;31m[ОШИБКА] Пересборка прервана! Нажмите любую клавишу...%ESC%[0m
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause >nul
)
exit /b 1