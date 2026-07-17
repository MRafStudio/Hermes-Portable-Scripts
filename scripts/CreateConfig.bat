@REM CreateConfig.bat — Создание/обновление Config.ini для Hermes Portable
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"
for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"
set "CONFIG_FILE=%SCRIPTS_DIR%\Config.ini"

set "KOBOLD_ENABLED=%~1"
set "KOBOLD_MODEL=%~2"
set "KOBOLD_MMPROJ=%~3"
set "KOBOLD_PORT=%~4"
set "KOBOLD_MODEL_REPO=%~5"

REM ============================================================================
REM   Читаем ТЕКУЩИЕ значения ДО перезаписи!
REM   Пустой аргумент означает "не менять", а не "сбросить в дефолт".
REM   Иначе вызов с 3 аргументами затирает порт и репозиторий.
REM ============================================================================
set "PREV_ENABLED="
set "PREV_MODEL="
set "PREV_MMPROJ="
set "PREV_PORT="
set "PREV_REPO="

if exist "%CONFIG_FILE%" (
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_ENABLED=" "%CONFIG_FILE%"') do set "PREV_ENABLED=%%b"
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MODEL=" "%CONFIG_FILE%"') do set "PREV_MODEL=%%b"
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MMPROJ=" "%CONFIG_FILE%"') do set "PREV_MMPROJ=%%b"
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_PORT=" "%CONFIG_FILE%"') do set "PREV_PORT=%%b"
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MODEL_REPO=" "%CONFIG_FILE%"') do set "PREV_REPO=%%b"
)

REM ============================================================================
REM   Приоритет: аргумент > прежнее значение > дефолт
REM ============================================================================
if "!KOBOLD_ENABLED!"=="" set "KOBOLD_ENABLED=!PREV_ENABLED!"
if "!KOBOLD_ENABLED!"=="" set "KOBOLD_ENABLED=0"

if "!KOBOLD_MODEL!"=="" set "KOBOLD_MODEL=!PREV_MODEL!"
if "!KOBOLD_MODEL!"=="" set "KOBOLD_MODEL=Qwen_Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"

if "!KOBOLD_MMPROJ!"=="" set "KOBOLD_MMPROJ=!PREV_MMPROJ!"
if "!KOBOLD_MMPROJ!"=="" set "KOBOLD_MMPROJ=mmproj-Qwen_Qwen2.5-VL-7B-Instruct-f16.gguf"

if "!KOBOLD_PORT!"=="" set "KOBOLD_PORT=!PREV_PORT!"
if "!KOBOLD_PORT!"=="" set "KOBOLD_PORT=5001"

if "!KOBOLD_MODEL_REPO!"=="" set "KOBOLD_MODEL_REPO=!PREV_REPO!"
if "!KOBOLD_MODEL_REPO!"=="" set "KOBOLD_MODEL_REPO=bartowski/Qwen_Qwen2.5-VL-7B-Instruct-GGUF"

REM ============================================================================
REM   Перезаписываем конфиг (> в первой строке сам очищает файл, del не нужен)
REM ============================================================================
> "%CONFIG_FILE%" echo ; Hermes Portable — Configuration
>> "%CONFIG_FILE%" echo ; ================================
>> "%CONFIG_FILE%" echo ; Только параметры KoboldCpp.
>> "%CONFIG_FILE%" echo ; Для настройки LLM/API ключей — редактируй .env вручную или через hermes setup
>> "%CONFIG_FILE%" echo.
>> "%CONFIG_FILE%" echo ; --- Local LLM (KoboldCpp) ---
>> "%CONFIG_FILE%" echo ; Установите KOBOLD_ENABLED=1 если KoboldCpp с моделями установлен
>> "%CONFIG_FILE%" echo ; При запуске Hermes будет автоматически стартовать KoboldCpp
>> "%CONFIG_FILE%" echo KOBOLD_ENABLED=!KOBOLD_ENABLED!
>> "%CONFIG_FILE%" echo KOBOLD_PORT=!KOBOLD_PORT!
>> "%CONFIG_FILE%" echo KOBOLD_MODEL=!KOBOLD_MODEL!
>> "%CONFIG_FILE%" echo KOBOLD_MMPROJ=!KOBOLD_MMPROJ!
>> "%CONFIG_FILE%" echo KOBOLD_MODEL_REPO=!KOBOLD_MODEL_REPO!

exit /b 0