@echo off
chcp 65001 >nul
REM scripts\Start-Llama-IfNeeded.bat - единая точка настройки LLM перед запуском Hermes.
REM   А: llama установлена + модель указана -> поднять llama + синхронизировать Hermes (5 ключей) + MemOS (sync-memos-llm.ps1).
REM   Б: llama установлена, но модель НЕ указана -> внешний провайдер Hermes: Б2 настроить MemOS, Б1 подсказать меню.
REM   llama не установлена -> тихий выход.
setlocal enabledelayedexpansion

set "SCRIPTS_DIR=%~dp0"
for %%i in ("%SCRIPTS_DIR%..") do set "ROOT_DIR=%%~fi"
set "DATA_DIR=%ROOT_DIR%\data"
set "LLAMA_DIR=%DATA_DIR%\llama"
set "LLM_MODELS=%DATA_DIR%\llm\models"
set "HERMES_BIN=%DATA_DIR%\hermes\hermes-agent\venv\Scripts\hermes.exe"

REM Дефолтная модель - из default_model.cfg (единый источник правды)
set "MODEL_FILE="
set "MMPROJ_FILE="
if exist "%DATA_DIR%\llm\default_model.cfg" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "MODEL_FILE MMPROJ_FILE" "%DATA_DIR%\llm\default_model.cfg"') do (
        if "%%a"=="MODEL_FILE" set "MODEL_FILE=%%b"
        if "%%a"=="MMPROJ_FILE" set "MMPROJ_FILE=%%b"
    )
)


REM --- Маркер MemOS (\.memos-enabled): помним включение плагина ---
REM   конфиг грохнут + маркер есть -> memory.provider=memtensor восстанавливается СРАЗУ
REM   конфиг жив: memtensor -> маркер остаётся; НЕ memtensor -> маркер удаляется
set "MEMOS_HOME_DIR=%DATA_DIR%\hermes\memos-plugin"
set "MEMOS_MARKER=%MEMOS_HOME_DIR%\.memos-enabled"
if exist "%MEMOS_HOME_DIR%" (
    if exist "%DATA_DIR%\hermes\config.yaml" (
        set "MP="
        if exist "%HERMES_BIN%" for /f "delims=" %%p in ('"%HERMES_BIN%" config get memory.provider 2^>nul') do set "MP=%%p"
        if /i "!MP!"=="memtensor" (
            if not exist "%MEMOS_MARKER%" type nul > "%MEMOS_MARKER%"
        ) else (
            if exist "%MEMOS_MARKER%" del "%MEMOS_MARKER%"
        )
    ) else (
        if exist "%MEMOS_MARKER%" if exist "%HERMES_BIN%" (
            "%HERMES_BIN%" config set memory.provider memtensor >nul 2>&1
            echo   MemOS: memory.provider=memtensor восстановлен
        )
    )
)

REM --- Рабочая директория сессий: terminal.cwd = %ROOT_DIR%\data\home ---
if exist "%HERMES_BIN%" (
    "%HERMES_BIN%" config set terminal.cwd "%ROOT_DIR%\data\home" >nul 2>&1
)

REM llama установлена?
if not exist "%LLAMA_DIR%\llama-server.exe" goto not_installed

REM модель указана и скачана? (иначе - сценарий Б)
if "!MODEL_FILE!"=="" goto no_local_llama
if not exist "%LLM_MODELS%\%MODEL_FILE%" goto no_local_llama

REM === А: поднять llama ===
set "LLAMA_PORT=5505"

REM 1) Уже работает на 5505? (llama - отвечает на /health!)
curl -s -o nul --max-time 2 http://127.0.0.1:5505/health >nul 2>&1
if not errorlevel 1 (
    echo   Llama.cpp: уже работает ^(:5505^)
    goto configure_hermes
)

REM 2) Уже работает на 5506? (второй инстанс - полигон!)
curl -s -o nul --max-time 2 http://127.0.0.1:5506/health >nul 2>&1
if not errorlevel 1 (
    echo   Llama.cpp: уже работает ^(:5506^)
    set "LLAMA_PORT=5506"
    goto configure_hermes
)

REM 3) 5505 занят ДРУГИМ процессом? (LISTENING - но не llama!)
netstat -ano | findstr ":5505 " | findstr "LISTENING" >nul 2>&1
if not errorlevel 1 (
    echo   [WARN] :5505 занят другим процессом - запускаю :5506 (свой инстанс)
    set "LLAMA_PORT=5506"
    goto start_llama
)

REM 4) Порт свободен - запускаем базу :5505
:start_llama
echo   Llama.cpp: запускаю ^(!MODEL_FILE! :!LLAMA_PORT!^)...
start /min "LlamaCPP !LLAMA_PORT!" cmd /c ""%SCRIPTS_DIR%\Start-llama.bat" %MODEL_FILE% !LLAMA_PORT! %LLM_MODELS%\%MMPROJ_FILE%"
REM ждём готовность (до 60с)
set "waited=0"
:wait_llama
timeout /t 2 >nul
curl -s -o nul --max-time 2 http://127.0.0.1:!LLAMA_PORT!/health >nul 2>&1
if not errorlevel 1 goto llama_ready
set /a waited+=2
if !waited! lss 20 goto wait_llama
echo   [WARN] Llama.cpp не ответил за 20с - Hermes стартует без локальной модели
goto llama_done
:llama_ready
echo   Llama.cpp готов ^(:!LLAMA_PORT!^)

REM 5) Hermes: ПОЛНАЯ синхронизация на фактический порт + модель (единая логика с Start-llama.bat!)
:configure_hermes
if exist "%HERMES_BIN%" (
    "%HERMES_BIN%" config set model.default "llama/%MODEL_FILE:~0,-5%" >nul 2>&1
    "%HERMES_BIN%" config set model.provider "llama" >nul 2>&1
    "%HERMES_BIN%" config set model.base_url "http://127.0.0.1:!LLAMA_PORT!/v1" >nul 2>&1
    "%HERMES_BIN%" config set providers.llama.model "llama/%MODEL_FILE:~0,-5%" >nul 2>&1
    "%HERMES_BIN%" config set providers.llama.base_url "http://127.0.0.1:!LLAMA_PORT!/v1" >nul 2>&1
    echo   Hermes: llama/%MODEL_FILE:~0,-5% на :!LLAMA_PORT!
)
REM MemOS (если включена) подхватит ту же LLM
call :sync_memos
goto llama_done

REM === Б: локальная llama не настроена - проверяем внешний провайдер Hermes ===
:no_local_llama
set "MODEL_PROVIDER="
if exist "%HERMES_BIN%" for /f "delims=" %%p in ('"%HERMES_BIN%" config get model.provider 2^>nul') do set "MODEL_PROVIDER=%%p"
if defined MODEL_PROVIDER if not "!MODEL_PROVIDER!"=="" if not "!MODEL_PROVIDER!"=="llama" (
    REM Б2: внешний провайдер настроен - MemOS подхватит его
    call :sync_memos
    goto llama_done
)
REM Б1: внешнего провайдера нет - подсказка
echo   [INFO] Локальная llama не настроена и внешний LLM-провайдер не задан.
echo   Настрой внешнюю LLM: главное меню [1]-^>[9] удалённый сервер Hermes либо [5]-^>[2] облачная LLM.
echo   Либо назначь локальную модель: InstallOrUpdate-Models.bat.
goto llama_done

REM === sync-memos-llm.ps1: MemOS подхватывает активную LLM (если MemOS включена) ===
:sync_memos
if exist "%SCRIPTS_DIR%\ps1\sync-memos-llm.ps1" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps1\sync-memos-llm.ps1" -RootDir "%ROOT_DIR%"
)
exit /b 0

:llama_done
:menu
call :inject_roles
exit /b 0

:not_installed
call :inject_roles
exit /b 0

REM === Инжекция ролей (scripts\roles\*.yaml) в config.yaml ===
REM   Вызывается ПОСЛЕ восстановления конфига (:configure_hermes) -
REM   если config.yaml был удалён, он уже пересоздан hermes config set.
REM   Инжектор: только hermes config get/set + бэкап в .backup перед изменением.
:inject_roles
if exist "%DATA_DIR%\hermes\hermes-agent\venv\Scripts\python.exe" if exist "%SCRIPTS_DIR%\roles" (
    "%DATA_DIR%\hermes\hermes-agent\venv\Scripts\python.exe" "%SCRIPTS_DIR%\py\install_roles.py" --root "%ROOT_DIR%"
)

exit /b 0
