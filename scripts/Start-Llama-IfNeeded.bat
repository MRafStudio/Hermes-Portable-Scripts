@echo off
chcp 65001 >nul
REM scripts\Start-Llama-IfNeeded.bat - поднять Llama.cpp (дефолтная модель :5505) перед запуском Hermes (если установлен)
setlocal enabledelayedexpansion

set "SCRIPTS_DIR=%~dp0"
for %%i in ("%SCRIPTS_DIR%..") do set "ROOT_DIR=%%~fi"
set "DATA_DIR=%ROOT_DIR%\data"
set "LLAMA_DIR=%DATA_DIR%\llama"
set "LLM_MODELS=%DATA_DIR%\llm\models"
REM Дефолтная модель — из default_model.cfg (единый источник правды)
set "MODEL_FILE=Qwen3.6-35B-A3B-UD-IQ4_NL.gguf"
set "MMPROJ_FILE=mmproj-35B-F16.gguf"
if exist "%DATA_DIR%\llm\default_model.cfg" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "MODEL_FILE MMPROJ_FILE" "%DATA_DIR%\llm\default_model.cfg"') do (
        if "%%a"=="MODEL_FILE" set "MODEL_FILE=%%b"
        if "%%a"=="MMPROJ_FILE" set "MMPROJ_FILE=%%b"
    )
)

REM Проверки: есть ли llama.cpp + модель (иначе - тихо выходим)
if not exist "%LLAMA_DIR%\llama-server.exe" goto not_installed
if not exist "%LLM_MODELS%\%MODEL_FILE%" goto not_installed
if not exist "%LLM_MODELS%\%MMPROJ_FILE%" goto not_installed

REM   Порт-логика: база :5505 (дом). Если 5505 занят ДРУГИМ процессом (не llama) -
REM   используем :5506 (свой инстанс) и перенастраиваем Hermes-провайдер.
set "LLAMA_PORT=5505"
set "HERMES_BIN=%DATA_DIR%\hermes\hermes-agent\venv\Scripts\hermes.exe"

REM 1) Уже работает на 5505? (llama — отвечает на /health!)
curl -s -o nul --max-time 2 http://127.0.0.1:5505/health >nul 2>&1
if not errorlevel 1 (
    echo   Llama.cpp: уже работает ^(:5505^)
    goto llama_done
)

REM 2) Уже работает на 5506? (второй инстанс — полигон!)
curl -s -o nul --max-time 2 http://127.0.0.1:5506/health >nul 2>&1
if not errorlevel 1 (
    echo   Llama.cpp: уже работает ^(:5506^)
    set "LLAMA_PORT=5506"
    goto configure_hermes
)

REM 3) 5505 занят ДРУГИМ процессом? (LISTENING — но не llama!)
netstat -ano | findstr ":5505 " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo   [WARN] :5505 занят другим процессом - запускаю :5506 (свой инстанс)
    set "LLAMA_PORT=5506"
    goto start_llama
)

REM 4) Порт свободен - запускаем базу :5505
:start_llama
echo   Llama.cpp: запускаю ^(!MODEL_FILE! :!LLAMA_PORT!^)...
start /min "LlamaCPP !LLAMA_PORT!" cmd /c ""%LLAMA_DIR%\Start_llama.bat" %MODEL_FILE% !LLAMA_PORT! %LLM_MODELS%\%MMPROJ_FILE%"
REM ждём готовность (до 60с)
set "waited=0"
:wait_llama
timeout /t 2 >nul
curl -s -o nul --max-time 2 http://127.0.0.1:!LLAMA_PORT!/health >nul 2>&1
if not errorlevel 1 goto llama_ready
set /a waited+=2
if !waited! lss 60 goto wait_llama
echo   [WARN] Llama.cpp не ответил за 60с - Hermes стартует без локальной модели
goto llama_done
:llama_ready
echo   Llama.cpp готов ^(:!LLAMA_PORT!^)

REM 5) Hermes-провайдер на фактический порт (если не 5505 — переконфигурируем!)
:configure_hermes
if not "!LLAMA_PORT!"=="5505" (
    if exist "%HERMES_BIN%" (
        "%HERMES_BIN%" config set providers.llama.base_url "http://127.0.0.1:!LLAMA_PORT!/v1" >nul 2>&1
        echo   Hermes: providers.llama.base_url -> :!LLAMA_PORT! (переконфигурировано)
    )
) else (
    REM база на 5505 - дефолт (убеждаемся, что конфиг правильный - если отличается)
    if exist "%HERMES_BIN%" (
        set "CUR_URL="
        for /f "usebackq delims=" %%u in (`"%HERMES_BIN%" config get providers.llama.base_url 2^>nul`) do set "CUR_URL=%%u"
        if not "!CUR_URL!"=="" if not "!CUR_URL:5505=!"=="!CUR_URL!" goto llama_done
        "%HERMES_BIN%" config set providers.llama.base_url "http://127.0.0.1:5505/v1" >nul 2>&1
        echo   Hermes: providers.llama.base_url -> :5505
    )
)
:llama_done
:menu
exit /b 0

:not_installed
exit /b 0
