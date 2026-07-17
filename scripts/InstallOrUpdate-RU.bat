REM scripts\InstallOrUpdate-RU.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Параметры
REM   %1 = AUTOCLOSE (0/1) — авто-закрытие после завершения (для вызова из других скриптов)
REM ============================================================================
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Установка RU

REM ============================================================================
REM   Определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "NODE_DIR=%HERMES_HOME%\node"
set "NODE_EXE=%NODE_DIR%\node.exe"
set "RU_LOCALE_DIR=%SCRIPTS_DIR%\ru-locale"
set "EN_LOCALE_DIR=%SCRIPTS_DIR%\en-locale"

REM Пути к файлам Hermes Desktop
set "I18N_DIR=%REPO_DIR%\apps\desktop\src\i18n"
set "SETTINGS_DIR=%REPO_DIR%\apps\desktop\src\app\settings"
set "DESKTOP_DIR=%REPO_DIR%\apps\desktop"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%RU_LOCALE_DIR%" mkdir "%RU_LOCALE_DIR%" 2>nul
if not exist "%EN_LOCALE_DIR%" mkdir "%EN_LOCALE_DIR%" 2>nul

REM Получение ESC (без PS_WRAPPER!)
for /f %%a in ('powershell -NoProfile -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

REM cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m               %ESC%[1;37mHermes Portable%ESC%[0m   %ESC%[1;33m-%ESC%[0m   %ESC%[1;33mУстановка RU локализации%ESC%[0m               %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка репозитория
REM ============================================================================
if not exist "%DESKTOP_DIR%\package.json" (
    echo   %ESC%[1;31m[ОШИБКА] Desktop app не найден в репозитории...%ESC%[0m
    echo   %ESC%[33m       Сначала клонируйте репозиторий и установите Node.js.%ESC%[0m
    goto error_exit
)

REM ============================================================================
REM   ШАГ 1/4: Проверка локальных файлов
REM ============================================================================
echo   %ESC%[1;33m[1/4]%ESC%[0m %ESC%[1mПроверка файлов локализации...%ESC%[0m

if not exist "%RU_LOCALE_DIR%\ru.ts" (
    echo   %ESC%[1;31m[ОШИБКА] ru.ts не найден в %RU_LOCALE_DIR%%ESC%[0m
    goto error_exit
)

if not exist "%RU_LOCALE_DIR%\ru-constants.ts" (
    echo   %ESC%[1;31m[ОШИБКА] ru-constants.ts не найден в %RU_LOCALE_DIR%%ESC%[0m
    goto error_exit
)

echo   %ESC%[1;32m  +   Файлы локализации найдены.%ESC%[0m

REM ============================================================================
REM   ШАГ 2/5: Копирование en.ts из репозитория
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/5]%ESC%[0m %ESC%[1mКопирование en.ts и zh.ts из репозитория...%ESC%[0m

set "REPO_I18N_DIR=%REPO_DIR%\apps\desktop\src\i18n"

REM --- en.ts ---
if exist "%REPO_I18N_DIR%\en.ts" (
    copy /Y "%REPO_I18N_DIR%\en.ts" "%EN_LOCALE_DIR%\en.ts" >nul
    for %%F in ("%EN_LOCALE_DIR%\en.ts") do set "EN_SIZE=%%~zF"
    echo   %ESC%[1;32m  +   en.ts скопирован из репозитория ^(!EN_SIZE! байт^).%ESC%[0m
) else (
    echo   %ESC%[1;33m  !   en.ts не найден в репозитории. Пробуем скачать...%ESC%[0m
    set "EN_TS_URL=https://raw.githubusercontent.com/NousResearch/hermes-agent/main/apps/desktop/src/i18n/en.ts"
    curl -L -o "%EN_LOCALE_DIR%\en.ts" "%EN_TS_URL%"
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m[ОШИБКА] Не удалось загрузить en.ts%ESC%[0m
        goto error_exit
    )
    for %%F in ("%EN_LOCALE_DIR%\en.ts") do set "EN_SIZE=%%~zF"
    if !EN_SIZE! lss 100 (
        echo   %ESC%[1;31m[ОШИБКА] en.ts пустой или битый ^(!EN_SIZE! байт^)%ESC%[0m
        goto error_exit
    )
    echo   %ESC%[1;32m  +   en.ts загружен ^(!EN_SIZE! байт^).%ESC%[0m
)

:apply_ru
REM ============================================================================
REM   ШАГ 3/4: Копирование файлов RU в локальный репозиторий
REM ============================================================================
echo.
echo   %ESC%[1;33m[3/4]%ESC%[0m %ESC%[1mКопирование файлов RU локализации в репозиторий...%ESC%[0m

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

REM --- default_soul.md → SOUL.md ---
set "SOUL_SRC=%SCRIPTS_DIR%\patch\default_soul.md"
set "SOUL_DST=%HERMES_HOME%\SOUL.md"

if exist "%SOUL_SRC%" (
    copy /Y "%SOUL_SRC%" "%SOUL_DST%" >nul
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   SOUL.md обновлён из default_soul.md.%ESC%[0m
    ) else (
        echo   %ESC%[1;33m  !   Не удалось скопировать SOUL.md.%ESC%[0m
    )
) else (
    echo   %ESC%[1;33m  .   default_soul.md не найден, пропускаем.%ESC%[0m
)

REM ============================================================================
REM   ШАГ 4/4: Патчим конфиги TypeScript и config.yaml
REM ============================================================================
echo.
echo   %ESC%[1;33m[4/4]%ESC%[0m %ESC%[1mПатчим конфиги TypeScript...%ESC%[0m

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
set "CONFIG_YAML=%HERMES_HOME%\config.yaml"
if exist "%CONFIG_YAML%" (
    echo   %ESC%[1;33m  -   Обновление локализации в config.yaml...%ESC%[0m
    powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\patch\patch_locale_yaml.ps1" -ConfigPath "%CONFIG_YAML%" -Locale ru
)

REM ============================================================================
REM   Завершение
REM ============================================================================
:ru_done
echo.
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mRU локализация установлена%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m

if "%AUTOCLOSE%"=="1" (
    exit /b 0
) else (
    echo.
    echo   %ESC%[1;33m  →  Нажмите любую клавишу для возврата в меню...%ESC%[0m
    pause >nul
    exit /b 0
)

REM ============================================================================
REM   ВЫХОДЫ
REM ============================================================================
:error_exit
echo.
echo   %ESC%[1;31m[ОШИБКА] Произошла ошибка! Нажмите любую клавишу...%ESC%[0m
pause >nul
exit /b 1