@echo off
REM scripts\start_llama.bat — запуск llama-server (EDINственный скрипт запуска — в репозитории!)
REM Использование: start_llama.bat [MODEL] [PORT] [MMPROJ]  (дефолты: Qwen3.6-35B / 5505 / mmproj-35B-F16)
chcp 65001 >nul
setlocal enabledelayedexpansion

set "LLAMA_DIR=%~dp0"
for %%i in ("%LLAMA_DIR%..\..") do set "ROOT_DIR=%%~fi"
set "LLM_MODELS=%ROOT_DIR%\data\llm\models"

set "MODEL=%~1"
if "%MODEL%"=="" set "MODEL=Qwen3.6-35B-A3B-UD-IQ4_NL.gguf"
set "PORT=%~2"
if "%PORT%"=="" set "PORT=5505"
set "MMPROJ=%~3"
if "%MMPROJ%"=="" set "MMPROJ=%LLM_MODELS%\mmproj-35B-F16.gguf"
if not exist "%MMPROJ%" set "MMPROJ=%LLM_MODELS%\mmproj-35B-F16.gguf"

set "MODEL_PATH=%LLM_MODELS%\%MODEL%"
if not exist "%MODEL_PATH%" (
    echo [ERROR] модель не найдена: %MODEL%
    echo Скачай через InstallOrUpdate-Llama.bat
    pause
    exit /b 1
)

REM Отвязка: llama-server — отдельный процесс (start /min), окно свернуто, лог — в своё окно
start "LlamaCPP %MODEL%" /min "%LLAMA_DIR%\llama-server.exe" -m "%MODEL_PATH%" --mmproj "%MMPROJ%" --alias llama/%MODEL:~0,-5% -c 262144 -ngl 999 --flash-attn 1 --parallel 1 --image-min-tokens 1024 --port %PORT% --host 127.0.0.1
echo Сервер запущен в отдельном окне (свернуто).
exit /b 0
