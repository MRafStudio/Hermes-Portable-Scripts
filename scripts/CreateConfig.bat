@REM CreateConfig.bat — Создание Config.ini для Hermes Portable
@REM ============================================================================
@REM Только параметры KoboldCpp. Остальное настраивается через .env!
@REM ============================================================================
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM Путь к папке scripts (где лежит этот bat)
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

REM Корень проекта = папка выше scripts
for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "CONFIG_FILE=%SCRIPTS_DIR%\Config.ini"

REM ============================================================================
REM   Параметры
REM ============================================================================
set "KOBOLD_ENABLED=%~1"
set "KOBOLD_MODEL=%~2"
set "KOBOLD_MMPROJ=%~3"
set "KOBOLD_PORT=%~4"

if "!KOBOLD_ENABLED!"=="" set "KOBOLD_ENABLED=0"
if "!KOBOLD_MODEL!"=="" set "KOBOLD_MODEL=Qwen_Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"
if "!KOBOLD_MMPROJ!"=="" set "KOBOLD_MMPROJ=mmproj-Qwen_Qwen2.5-VL-7B-Instruct-f16.gguf"
if "!KOBOLD_PORT!"=="" set "KOBOLD_PORT=5001"

REM Очищаем файл если существует
if exist "%CONFIG_FILE%" del /f /q "%CONFIG_FILE%" 2>nul

REM ============================================================================
REM   Пишем Config.ini построчно
REM ============================================================================
>> "%CONFIG_FILE%" echo ; Hermes Portable — Configuration
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

exit /b 0