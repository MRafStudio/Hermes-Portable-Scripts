@REM scripts\PatchConfigKobold.bat
@REM Патч config.yaml для KoboldCpp
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

set "CONTEXT_LENGTH=%~2"
set "MAX_TOKENS=%~3"

title Hermes Portable — Патч config.yaml для KoboldCpp

REM ============================================================================
REM   Пути
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "CONFIG_YAML=%HERMES_HOME%\config.yaml"
set "PATCH_SCRIPT=%SCRIPTS_DIR%\patch\patch_config_llm_yaml.ps1"
set "BACKUP_FILE=%CONFIG_YAML%.bak"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM Без cls: при вызове из цепочки не стираем лог родительского скрипта
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m             %ESC%[1;37mHermes Portable%ESC%[0m   —   %ESC%[1;33mПатч config.yaml для KoboldCpp%ESC%[0m           %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка файлов
REM ============================================================================
if not exist "%CONFIG_YAML%" (
    echo   %ESC%[1;33m  i   config.yaml не найден:%ESC%[0m
    echo   %ESC%[2m       %CONFIG_YAML%%ESC%[0m
    echo.
    echo   %ESC%[1;33m  .   Патч пропущен.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

if not exist "%PATCH_SCRIPT%" (
    echo   %ESC%[1;31m[ОШИБКА] Скрипт патча не найден:%ESC%[0m
    echo   %ESC%[2m       %PATCH_SCRIPT%%ESC%[0m
    echo.
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

REM ============================================================================
REM   Бэкап
REM ============================================================================
if not exist "%BACKUP_FILE%" (
    echo   %ESC%[1;33m  -   Создание бэкапа...%ESC%[0m
    copy /y "%CONFIG_YAML%" "%BACKUP_FILE%" >nul
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   Бэкап создан: %BACKUP_FILE%%ESC%[0m
    ) else (
        echo   %ESC%[1;31m  [ОШИБКА] Не удалось создать бэкап!%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        exit /b 1
    )
) else (
    echo   %ESC%[1;33m  .   Бэкап уже существует: %BACKUP_FILE%%ESC%[0m
)
echo.

REM ============================================================================
REM   Выполнение патча
REM ============================================================================
echo   %ESC%[1;33m  -   Применение патча config.yaml...%ESC%[0m
echo   %ESC%[2m       Путь: %CONFIG_YAML%%ESC%[0m
echo.

powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PATCH_SCRIPT%" -ConfigPath "%CONFIG_YAML%" -ContextLength %CONTEXT_LENGTH% -MaxTokens 0
set "PATCH_RESULT=%errorlevel%"

echo.

if %PATCH_RESULT% equ 0 (
    echo   %ESC%[1;32m  +   Патч config.yaml применён.%ESC%[0m
) else if %PATCH_RESULT% equ 1 (
    echo   %ESC%[1;33m  .   config.yaml уже настроен для KoboldCpp.%ESC%[0m
) else (
    echo   %ESC%[1;31m[ОШИБКА] Патч не применён ^(код: %PATCH_RESULT%^).%ESC%[0m
    echo   %ESC%[33m       Восстановите из бэкапа: %BACKUP_FILE%%ESC%[0m
)

echo.

if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 3
) else (
    REM pause
)

REM ============================================================================
REM   Коды возврата: 0 = применён, 1 = уже настроен — оба НЕ ошибки!
REM   Наружу отдаём 0 в обоих случаях; ошибки (2+) — как есть.
REM ============================================================================
if %PATCH_RESULT% leq 1 (
    exit /b 0
) else (
    exit /b %PATCH_RESULT%
)