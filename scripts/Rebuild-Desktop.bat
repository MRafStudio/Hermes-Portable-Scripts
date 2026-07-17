@REM scripts\Rebuild-Desktop.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

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

REM Пути к файлам локализации
set "RU_LOCALE_DIR=%SCRIPTS_DIR%\ru-locale"
set "I18N_DIR=%REPO_DIR%\apps\desktop\src\i18n"
set "SETTINGS_DIR=%REPO_DIR%\apps\desktop\src\app\settings"

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

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                 %ESC%[1;37mHermes Portable%ESC%[0m   —   %ESC%[1;33mПересборка Desktop%ESC%[0m                   %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

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

REM Проверяем Node.js
if not exist "%NODE_DIR%\node.exe" (
    echo   %ESC%[1;31m[ОШИБКА] Node.js не найден: %NODE_DIR%\node.exe%ESC%[0m
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
REM   ШАГ 2: Копирование файлов RU локализации в репозиторий
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/4]%ESC%[0m %ESC%[1mКопирование файлов RU локализации...%ESC%[0m

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
echo   %ESC%[1;33m[3/4]%ESC%[0m %ESC%[1mПатчим конфиги TypeScript...%ESC%[0m

set "PATCH_DIR=%SCRIPTS_DIR%\patch"

REM --- types.ts ---
set "TYPES_FILE=%I18N_DIR%\types.ts"
if exist "%TYPES_FILE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PATCH_DIR%\patch_types.ps1" -FilePath "%TYPES_FILE%"
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   types.ts пропатчен.%ESC%[0m
    ) else if !errorlevel! equ 1 (
        echo   %ESC%[1;33m  .   types.ts уже содержит 'ru'.%ESC%[0m
    ) else (
        echo   %ESC%[1;31m  [ОШИБКА] patch_types.ps1 не сработал... Код: %errorlevel%%ESC%[0m
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
        echo   %ESC%[1;31m  [ОШИБКА] patch_languages.ps1 не сработал... Код: %errorlevel%%ESC%[0m
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
        echo   %ESC%[1;31m  [ОШИБКА] patch_catalog.ps1 не сработал... Код: %errorlevel%%ESC%[0m
        goto error_exit
    )
)

REM Правим локализацию в config.yaml
echo.
set "CONFIG_YAML=%HERMES_HOME%\config.yaml"
if exist "%CONFIG_YAML%" (
    echo   %ESC%[1;33m  -   Обновление локализации в config.yaml...%ESC%[0m
    powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\patch\patch_locale_yaml.ps1" -ConfigPath "%CONFIG_YAML%" -Locale ru
)

REM ============================================================================
REM   ШАГ 4: Сборка Desktop
REM ============================================================================
echo.
echo   %ESC%[1;33m[4/4]%ESC%[0m %ESC%[1mСборка Desktop...%ESC%[0m
echo   %ESC%[2m       Это может занять 1-3 минуты...%ESC%[0m

cd /d "%REPO_DIR%"

REM Убедимся, что npm доступен
set "PATH=%NODE_DIR%;%PATH%"

REM Установка npm-зависимостей в корне репо (workspace)
echo   %ESC%[1;33m  .   Установка npm-зависимостей...%ESC%[0m
call "%NODE_DIR%\npm.cmd" install 2>&1
if errorlevel 1 (
    echo   %ESC%[1;31m  [ОШИБКА] Не удалось установить npm-зависимости.%ESC%[0m
    goto error_exit
)
echo   %ESC%[1;32m  +   npm-зависимости установлены.%ESC%[0m

REM Добавляем node_modules/.bin в PATH
set "PATH=%REPO_DIR%\node_modules\.bin;%PATH%"

cd /d "%DESKTOP_DIR%"

REM Очистка кэша electron-builder для чистой пересборки
if exist "release" rmdir /s /q "release" 2>nul

REM Запускаем сборку
echo   %ESC%[1;33m  .   Запуск npm run pack...%ESC%[0m
call "%NODE_DIR%\npm.cmd" run pack 2>&1

if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Сборка Desktop не удалась.%ESC%[0m
    goto error_exit
)

echo   %ESC%[1;32m  +   Desktop собран.%ESC%[0m

REM ============================================================================
REM   Проверка результата
REM ============================================================================
echo.
echo   %ESC%[1;33mПроверка результата...%ESC%[0m

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
pause >nul
exit /b 1