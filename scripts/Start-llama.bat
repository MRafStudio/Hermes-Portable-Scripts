@echo off
REM scripts\Start-llama.bat — запуск llama-server (EDINственный скрипт запуска — в репозитории!)
REM Использование: Start-llama.bat [MODEL] [PORT] [MMPROJ]  (дефолты: default_model.cfg / 5505 / mmproj из cfg)
chcp 65001 >nul
setlocal enabledelayedexpansion

REM Start-llama.bat живёт в scripts\ (единый источник) - каталоги вычисляем сами
set "SCRIPTS_DIR=%~dp0"
for %%i in ("%SCRIPTS_DIR%..") do set "ROOT_DIR=%%~fi"
set "LLAMA_DIR=%ROOT_DIR%\data\llama"
set "LLM_MODELS=%ROOT_DIR%\data\llm\models"
set "CFG_FILE=%ROOT_DIR%\data\llm\default_model.cfg"

set "MODEL=%~1"
set "PORT=%~2"
if "%PORT%"=="" set "PORT=5505"
set "MMPROJ=%~3"
set "MAXCTX=262144"

REM Дефолтная модель — из default_model.cfg (единый источник правды), аргументы имеют приоритет
if exist "%CFG_FILE%" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "MODEL_FILE MMPROJ_FILE MAXCTX" "%CFG_FILE%"') do (
        if "%%a"=="MODEL_FILE" if "%MODEL%"=="" set "MODEL=%%b"
        if "%%a"=="MMPROJ_FILE" if "%MMPROJ%"=="" set "MMPROJ=%%b"
        if "%%a"=="MAXCTX" set "MAXCTX=%%b"
    )
)
if "%MODEL%"=="" set "MODEL=Qwen3.6-35B-A3B-UD-IQ4_NL.gguf"
if "%MMPROJ%"=="" set "MMPROJ=%LLM_MODELS%\mmproj-Qwen-35B-F16.gguf"
if not exist "%MMPROJ%" set "MMPROJ=%LLM_MODELS%\mmproj-Qwen-35B-F16.gguf"

set "MODEL_PATH=%LLM_MODELS%\%MODEL%"
if not exist "%MODEL_PATH%" (
    echo [ERROR] модель не найдена: %MODEL%
    echo Скачай через InstallOrUpdate-Models.bat
    pause
    exit /b 1
)

REM Отвязка: llama-server — отдельный процесс (start /min), окно свернуто, лог — в своё окно
start "LlamaCPP %MODEL%" /min "%LLAMA_DIR%\llama-server.exe" -m "%MODEL_PATH%" --mmproj "%MMPROJ%" --alias llama/%MODEL:~0,-5% -c %MAXCTX% --cache-type-k q4_0 --cache-type-v q4_0 -ngl 999 --flash-attn 1 --parallel 2 --port %PORT% --host 127.0.0.1
REM --- ПОЛНАЯ синхронизация Hermes: llama/<модель> + реальный порт (единая точка запуска сервера) ---
set "HERMES_BIN=%ROOT_DIR%\data\hermes\hermes-agent\venv\Scripts\hermes.exe"
if exist "%HERMES_BIN%" (
    "%HERMES_BIN%" config set model.default "llama/%MODEL:~0,-5%" >nul 2>&1
    "%HERMES_BIN%" config set model.provider "llama" >nul 2>&1
    "%HERMES_BIN%" config set model.base_url "http://127.0.0.1:%PORT%/v1" >nul 2>&1
    "%HERMES_BIN%" config set providers.llama.model "llama/%MODEL:~0,-5%" >nul 2>&1
    "%HERMES_BIN%" config set providers.llama.base_url "http://127.0.0.1:%PORT%/v1" >nul 2>&1
)
echo Сервер запущен в отдельном окне (свернуто).
exit /b 0
