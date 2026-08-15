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
set "PY=%ROOT_DIR%\data\hermes\hermes-agent\venv\Scripts\python.exe"
set "TEMP_DIR=%ROOT_DIR%\data\temp"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%" 2>nul

set "MODEL=%~1"
set "PORT=%~2"
if "%PORT%"=="" set "PORT=5505"
set "MMPROJ=%~3"
set "MAXCTX=262144"
set "THINKING=1"
set "MODEL_ID="

REM Дефолтная модель — из default_model.cfg (единый источник правды), аргументы имеют приоритет
if exist "%CFG_FILE%" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "MODEL_FILE MMPROJ_FILE MAXCTX THINKING MODEL_ID" "%CFG_FILE%"') do (
        if "%%a"=="MODEL_FILE" if "%MODEL%"=="" set "MODEL=%%b"
        if "%%a"=="MMPROJ_FILE" if "%MMPROJ%"=="" set "MMPROJ=%%b"
        if "%%a"=="MAXCTX" set "MAXCTX=%%b"
        if "%%a"=="THINKING" set "THINKING=%%b"
        if "%%a"=="MODEL_ID" set "MODEL_ID=%%b"
    )
)
if "%MODEL%"=="" set "MODEL=Qwen3.6-35B-A3B-UD-IQ4_NL.gguf"
if "%MMPROJ%"=="" set "MMPROJ=%LLM_MODELS%\mmproj-Qwen-35B-F16.gguf"
if not exist "%MMPROJ%" set "MMPROJ=%LLM_MODELS%\mmproj-Qwen-35B-F16.gguf"

REM Файловый обмен: python собирает флаг думания с правильным экранированием (кавычки-танцы — в python, не в cmd)
set "THINK_FLAG="
if exist "%PY%" (
    "%PY%" "%SCRIPTS_DIR%\py\llama_models.py" thinking_flag start "%THINKING%" > "%TEMP_DIR%\llama_thinking_flag.txt" 2>nul
    set /p THINK_FLAG=<"%TEMP_DIR%\llama_thinking_flag.txt"
)

REM Файловый обмен: KV-квант + запас токенов на вызов — из библиотеки моделей (llama_models.py server_flags)
set "SERVER_FLAGS="
if exist "%PY%" if not "%MODEL_ID%"=="" (
    "%PY%" "%SCRIPTS_DIR%\py\llama_models.py" server_flags "%MODEL_ID%" > "%TEMP_DIR%\llama_server_flags.txt" 2>nul
    set /p SERVER_FLAGS=<"%TEMP_DIR%\llama_server_flags.txt"
)

set "MODEL_PATH=%LLM_MODELS%\%MODEL%"
if not exist "%MODEL_PATH%" (
    echo [ERROR] модель не найдена: %MODEL%
    echo Скачай через InstallOrUpdate-Models.bat
    pause
    exit /b 1
)

REM Отвязка: llama-server — отдельный процесс (start /min), окно свернуто, лог — в своё окно
start "LlamaCPP %MODEL%" /min "%LLAMA_DIR%\llama-server.exe" -m "%MODEL_PATH%" --mmproj "%MMPROJ%" --alias llama/%MODEL:~0,-5% -c %MAXCTX% %SERVER_FLAGS% -ngl 999 --flash-attn 1 --parallel 2 %THINK_FLAG% --port %PORT% --host 127.0.0.1
REM --- ПОЛНАЯ синхронизация Hermes: llama/<модель> + реальный порт (единая точка запуска сервера) ---
set "HERMES_BIN=%ROOT_DIR%\data\hermes\hermes-agent\venv\Scripts\hermes.exe"
if exist "%HERMES_BIN%" (
    "%HERMES_BIN%" config set model.default "llama/%MODEL:~0,-5%" >nul 2>&1
    "%HERMES_BIN%" config set model.provider "llama" >nul 2>&1
    "%HERMES_BIN%" config set model.base_url "http://127.0.0.1:%PORT%/v1" >nul 2>&1
    "%HERMES_BIN%" config set providers.llama.model "llama/%MODEL:~0,-5%" >nul 2>&1
    "%HERMES_BIN%" config set providers.llama.base_url "http://127.0.0.1:%PORT%/v1" >nul 2>&1
    REM --- модель для зрения (auxiliary.vision) = та же llama-модель ---
    "%HERMES_BIN%" config set auxiliary.vision.model "llama/%MODEL:~0,-5%" >nul 2>&1
    "%HERMES_BIN%" config set auxiliary.vision.provider "llama" >nul 2>&1
    "%HERMES_BIN%" config set auxiliary.vision.base_url "http://127.0.0.1:%PORT%/v1" >nul 2>&1
)
echo Сервер запущен в отдельном окне (свернуто).
exit /b 0
