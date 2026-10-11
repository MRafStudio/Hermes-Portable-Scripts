@REM scripts\InstallOrUpdate-RU.bat
@REM Схема A: база — апстримный ru.ts (развивается вместе с Hermes), наш файл — слой ru-layer.ts
@REM с тем, чего у апстрима нет. Патчи types/languages/catalog больше не нужны: апстрим
@REM сам регистрирует русский. Подробности: scripts\py\i18n_build_layer.py, RU-WORKFLOW.md
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
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "PY_DIR=%SCRIPTS_DIR%\py"
set "VENV_PYTHON=%REPO_DIR%\venv\Scripts\python.exe"

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

REM ============================================================================
REM   Получение ESC (стандартный трюк, как в остальных скриптах)
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m               %ESC%[1;37mHermes Portable%ESC%[0m   %ESC%[1;33m-%ESC%[0m   %ESC%[1;33mУстановка RU локализации%ESC%[0m               %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка репозитория и Python
REM ============================================================================
if not exist "%DESKTOP_DIR%\package.json" (
    echo   %ESC%[1;31m[ОШИБКА] Desktop app не найден в репозитории...%ESC%[0m
    echo   %ESC%[33m       Сначала клонируйте репозиторий и установите Node.js.%ESC%[0m
    goto error_exit
)

set "PYTHON=%VENV_PYTHON%"
if not exist "%PYTHON%" set "PYTHON=python"

"%PYTHON%" -c "import sys" >nul 2>nul
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Python не найден ^(%VENV_PYTHON%^).%ESC%[0m
    echo   %ESC%[33m       Установите окружение Hermes через главное меню.%ESC%[0m
    goto error_exit
)

REM ============================================================================
REM   ШАГ 1/3: Эталоны — en.ts + модули en_*.ts + апстримный ru.ts (из git HEAD)
REM ============================================================================
echo   %ESC%[1;33m[1/3]%ESC%[0m %ESC%[1mСинхронизация эталонов ^(en + модули, апстримный ru^)...%ESC%[0m
"%PYTHON%" "%PY_DIR%\i18n_sync_refs.py"
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось синхронизировать эталоны локализации.%ESC%[0m
    goto error_exit
)

REM ============================================================================
REM   ШАГ 2/3: Наш слой ru-layer.ts + установка ru.ts (апстрим + подключение слоя)
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/3]%ESC%[0m %ESC%[1mСборка слоя и установка ru.ts в репозиторий...%ESC%[0m
"%PYTHON%" "%PY_DIR%\i18n_build_layer.py" --install
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось собрать/установить слой локализации.%ESC%[0m
    goto error_exit
)

REM --- старый ru-constants.ts от прежней схемы: удаляем, если остался в репозитории ---
if exist "%SETTINGS_DIR%\ru-constants.ts" del /q "%SETTINGS_DIR%\ru-constants.ts" 2>nul

REM ============================================================================
REM   ШАГ 3/3: config.yaml (язык интерфейса + рабочая директория сессий)
REM ============================================================================
echo.
echo   %ESC%[1;33m[3/3]%ESC%[0m %ESC%[1mНастройки config.yaml...%ESC%[0m

set "HERMES_EXE=%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe"
set "CONFIG_YAML=%HERMES_HOME%\config.yaml"
if exist "%CONFIG_YAML%" (
    echo   %ESC%[1;33m  -   Язык интерфейса: russian...%ESC%[0m
    "%HERMES_EXE%" config set display.language ru
)

REM Рабочая директория сессий: явный terminal.cwd в config.yaml
REM (иначе Electron берёт системный профиль через WinAPI — сессии падают в C:\Users\<user>!)
set "TERM_CWD=%ROOT_DIR%\data\home"
if exist "%CONFIG_YAML%" (
    echo   %ESC%[1;33m  -   Рабочая директория сессий ^(terminal.cwd^)...%ESC%[0m
    "%HERMES_EXE%" config set terminal.cwd "%TERM_CWD%"
)

REM --- SOUL.md (только если ещё нет - личность не перезаписываем!) ---
set "SOUL_SRC=%SCRIPTS_DIR%\profiles\default_soul.md"
set "SOUL_DST=%HERMES_HOME%\SOUL.md"
if not exist "%SOUL_DST%" (
    if exist "%SOUL_SRC%" (
        copy /Y "%SOUL_SRC%" "%SOUL_DST%" >nul
        if !errorlevel! equ 0 echo   %ESC%[1;32m  +   SOUL.md создан из default_soul.md.%ESC%[0m
    )
)

REM ============================================================================
REM   Завершение
REM ============================================================================
echo.
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mRU локализация установлена ^(схема A: апстрим-база + наш слой^)%ESC%[0m
echo   %ESC%[2m  Сводка: python scripts\py\i18n_status.py%ESC%[0m
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
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause >nul
)
exit /b 1
