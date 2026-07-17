@REM CreateConfig.bat — Создание Config.ini для Hermes Portable
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

if "!KOBOLD_ENABLED!"=="" set "KOBOLD_ENABLED=0"
if "!KOBOLD_MODEL!"=="" set "KOBOLD_MODEL=Qwen_Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"
if "!KOBOLD_MMPROJ!"=="" set "KOBOLD_MMPROJ=mmproj-Qwen_Qwen2.5-VL-7B-Instruct-f16.gguf"
if "!KOBOLD_PORT!"=="" set "KOBOLD_PORT=5001"
if "!KOBOLD_MODEL_REPO!"=="" set "KOBOLD_MODEL_REPO=bartowski/Qwen_Qwen2.5-VL-7B-Instruct-GGUF"

if exist "%CONFIG_FILE%" del /f /q "%CONFIG_FILE%" 2>nul

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
>> "%CONFIG_FILE%" echo KOBOLD_MODEL_REPO=!KOBOLD_MODEL_REPO!

exit /b 0