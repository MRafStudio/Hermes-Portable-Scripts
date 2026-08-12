@echo off
chcp 65001 >nul
REM scripts\Start-Llama-IfNeeded.bat - поднять Llama.cpp (1 инстанс: Qwen3.6-35B :8080) перед запуском Hermes (если установлен)
setlocal enabledelayedexpansion

set "SCRIPTS_DIR=%~dp0"
for %%i in ("%SCRIPTS_DIR%..") do set "ROOT_DIR=%%~fi"
set "DATA_DIR=%ROOT_DIR%\data"
set "LLAMA_DIR=%DATA_DIR%\llama"
set "KCPP_MODELS=%DATA_DIR%\kobold\models"
set "MODEL_QWEN=Qwen3.6-35B-A3B-UD-IQ4_NL.gguf"
set "MMPROJ_FILE=mmproj-35B-F16.gguf"

REM Проверки: есть ли llama.cpp + модель (иначе - тихо выходим)
if not exist "%LLAMA_DIR%\llama-server.exe" goto not_installed
if not exist "%KCPP_MODELS%\%MODEL_QWEN%" goto not_installed
if not exist "%KCPP_MODELS%\%MMPROJ_FILE%" goto not_installed

REM   Инстанс 1: Qwen3.6-35B :8080 (если не отвечает - запускаем)
curl -s -o nul --max-time 2 http://127.0.0.1:8080/health >nul 2>&1
if not errorlevel 1 (
    echo   Llama.cpp: уже работает ^(:8080^)
) else (
    echo   Llama.cpp: запускаю ^(Qwen3.6-35B :8080^)...
    start /min "LlamaCPP Qwen 8080" cmd /c ""%LLAMA_DIR%\start_llama.bat" %MODEL_QWEN% 8080"
    REM ждём готовность (до 60с)
    set "waited=0"
    :wait_llama
    timeout /t 2 >nul
    curl -s -o nul --max-time 2 http://127.0.0.1:8080/health >nul 2>&1
    if not errorlevel 1 goto llama_ready
    set /a waited+=2
    if !waited! lss 60 goto wait_llama
    echo   [WARN] Llama.cpp не ответил за 60с - Hermes стартует без локальной модели
    goto menu
    :llama_ready
    echo   Llama.cpp готов ^(:8080^)
)
:menu
exit /b 0

:not_installed
exit /b 0
