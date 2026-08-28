@REM scripts\InstallOrUpdate-Models.bat — модели llama.cpp: установка/обновление (Hermes Portable)
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Llama.cpp — Модели

REM ============================================================================
REM   Пути
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DATA_DIR=%ROOT_DIR%\data"
set "LLM_DIR=%DATA_DIR%\llm"
set "MODELS_DIR=%LLM_DIR%\models"
set "PY=%REPO_DIR%\venv\Scripts\python.exe"
set "CFG_FILE=%LLM_DIR%\default_model.cfg"
set "HERMES_BIN=%REPO_DIR%\venv\Scripts\hermes.exe"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "HOME=%DATA_DIR%\home"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%MODELS_DIR%" mkdir "%MODELS_DIR%" 2>nul

REM ============================================================================
REM   ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   uv (для установки huggingface_hub в venv)
REM ============================================================================
set "UV=%HERMES_HOME%\bin\uv.exe"
if not exist "%UV%" set "UV="
if not defined UV for /f "delims=" %%u in ('where uv 2^>nul') do if not defined UV set "UV=%%u"

REM ============================================================================
REM   Обеспечение hf (huggingface_hub CLI) в venv Hermes
REM ============================================================================
set "HF=%REPO_DIR%\venv\Scripts\hf.exe"
if exist "%HF%" (
    echo   %ESC%[2m    hf уже есть.%ESC%[0m
) else (
    echo.
    echo %ESC%[1;33m hf не найден - устанавливаю huggingface_hub в venv...%ESC%[0m
    if defined UV (
        "%UV%" pip install --python "%PY%" "huggingface_hub[cli]"
    )
    if exist "%HF%" (
        echo   %ESC%[1;32m+ %ESC%[0m hf установлен.
    ) else (
        echo   %ESC%[1;33m  hf не установился - модель попробуем скачать напрямую curl.%ESC%[0m
    )
)

REM ============================================================================
REM   curl
REM ============================================================================
set "CURL="
if exist "%SYSTEMROOT%\System32\curl.exe" set "CURL=%SYSTEMROOT%\System32\curl.exe"
if not defined CURL for /f "delims=" %%c in ('where curl 2^>nul') do if not defined CURL set "CURL=%%c"

REM ============================================================================
REM   Прокси-фоллбэк (github/HF из РФ режутся напрямую)
REM ============================================================================
set "PROXY=http://127.0.0.1:10809"

REM ============================================================================
REM   Выбор модели (база llama_models.py — единый справочник)
REM ============================================================================
:pick
echo.
echo   %ESC%[1;32mДоступные модели (llama_models.py)%ESC%[0m
"%PY%" "%SCRIPTS_DIR%\py\llama_models.py" list "%MODELS_DIR%"
echo.

REM --- дефолтная модель (из default_model.cfg — единый источник правды) ---
call :load_default
set "HAS_DEFAULT=0"
if defined MODEL_FILE set "HAS_DEFAULT=1"
if defined MODEL_FILE (
    echo   %ESC%[1;32mДефолтная: %ESC%[0m%MODEL_LABEL% %ESC%[2m^(%MODEL_FILE%^)%ESC%[0m
) else (
    echo   %ESC%[1;33mДефолтная модель не назначена%ESC%[0m %ESC%[2m^(первая установленная станет дефолтной^)%ESC%[0m
)
echo.

set "MID="
set /p "MID=%ESC%[33mВыбери ID модели, 0 - отключить локальную llama, Enter - отмена: %ESC%[0m"
if "%MID%"=="" goto exit
if "%MID%"=="0" goto clear_default

set "PICK="
for /f "delims=" %%p in ('""%PY%" "%SCRIPTS_DIR%\py\llama_models.py" pick "%MID%" "%MODELS_DIR%""') do set "PICK=%%p"
if not defined PICK (
    echo   %ESC%[1;31mНекорректный выбор.%ESC%[0m
    pause
    goto exit
)
for /f "tokens=1-10 delims=|" %%a in ("!PICK!") do (
    set "MODEL_ID=%%a"
    set "MODEL_FILE=%%b"
    set "MMPROJ_FILE=%%c"
    set "MODEL_REPO=%%d"
    set "MODEL_MAXCTX=%%e"
    set "MMPROJ_SRC=%%f"
    set "MODEL_LABEL=%%g"
    set "MODEL_ALIAS=%%h"
    set "MODEL_KV=%%i"
    set "MODEL_NPREDICT=%%j"
)

REM --- если модель уже установлена — сразу к назначению дефолта ---
if defined MODEL_FILE if exist "%MODELS_DIR%\%MODEL_FILE%" (
    echo.
    echo   %ESC%[2m  Модель уже установлена - проверяю проектор ^(vision^)...%ESC%[0m
    if not exist "%MODELS_DIR%\%MMPROJ_FILE%" (
        echo %ESC%[1;33m  Проектор %MMPROJ_FILE% не найден - загружаю...%ESC%[0m
        call :download_hf "%MODEL_REPO%" "%MMPROJ_SRC%" "%MODELS_DIR%"
        if not "%MMPROJ_SRC%"=="%MMPROJ_FILE%" (
            move /y "%MODELS_DIR%\%MMPROJ_SRC%" "%MODELS_DIR%\%MMPROJ_FILE%" >nul 2>&1
        )
    )
    goto ask_default
)

echo.
echo   Модель:    %MODEL_FILE%
echo   Проектор:  %MMPROJ_FILE%  ^(источник: %MMPROJ_SRC%^)
echo   Репозиторий: %MODEL_REPO%
set "confirm="
set /p "confirm=%ESC%[33mСкачать эту модель (y/N)? %ESC%[0m"
if /i not "%confirm%"=="y" goto exit

REM ============================================================================
REM   Скачивание модели + проектора (если нет) в общий каталог
REM ============================================================================
echo.
echo %ESC%[1;33m 1/2 Модель%ESC%[0m
if not exist "%MODELS_DIR%\%MODEL_FILE%" (
    call :download_hf "%MODEL_REPO%" "%MODEL_FILE%" "%MODELS_DIR%"
) else (
    echo   %ESC%[2m    уже есть - пропускаю.%ESC%[0m
)
echo %ESC%[1;33m 2/2 Проектор ^(vision^)%ESC%[0m
if not exist "%MODELS_DIR%\%MMPROJ_FILE%" (
    call :download_hf "%MODEL_REPO%" "%MMPROJ_SRC%" "%MODELS_DIR%"
    if not "%MMPROJ_SRC%"=="%MMPROJ_FILE%" (
        move /y "%MODELS_DIR%\%MMPROJ_SRC%" "%MODELS_DIR%\%MMPROJ_FILE%" >nul 2>&1
    )
) else (
    echo   %ESC%[2m    уже есть - пропускаю.%ESC%[0m
)
echo.
echo %ESC%[1;32m Готово. Модель в %MODELS_DIR%%ESC%[0m

REM ============================================================================
REM   Назначение дефолтной модели (первая установленная — автоматически)
REM ============================================================================
:ask_default
echo.
if "!HAS_DEFAULT!"=="1" (
    set "dflt_prompt=Сделать дефолтной (y/N)? "
    set "dflt_default=n"
) else (
    set "dflt_prompt=Назначить дефолтной (Y/n)? "
    set "dflt_default=y"
)
set "setdef="
set /p "setdef=%ESC%[33m!dflt_prompt!%ESC%[0m"
if "!setdef!"=="" set "setdef=!dflt_default!"
if /i "!setdef!"=="y" (
    call :set_default
) else (
    echo   %ESC%[2m  Дефолт не менялся.%ESC%[0m
)
goto exit

REM ============================================================================
REM   :load_default — чтение default_model.cfg (единый источник правды)
REM ============================================================================
:load_default
set "MODEL_ID="
set "MODEL_LABEL="
set "MODEL_FILE="
set "MMPROJ_FILE="
set "MODEL_MAXCTX="
set "MODEL_ALIAS="
if exist "%CFG_FILE%" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "MODEL_ID MODEL_LABEL MODEL_FILE MMPROJ_FILE MAXCTX MODEL_ALIAS" "%CFG_FILE%"') do (
        if "%%a"=="MODEL_ID" set "MODEL_ID=%%b"
        if "%%a"=="MODEL_LABEL" set "MODEL_LABEL=%%b"
        if "%%a"=="MODEL_FILE" set "MODEL_FILE=%%b"
        if "%%a"=="MMPROJ_FILE" set "MMPROJ_FILE=%%b"
        if "%%a"=="MAXCTX" set "MODEL_MAXCTX=%%b"
        if "%%a"=="MODEL_ALIAS" set "MODEL_ALIAS=%%b"
    )
)
exit /b 0

REM ============================================================================
REM   :set_default — запись cfg + переключение Hermes + перезапуск llama
REM ============================================================================
:set_default
(
echo MODEL_ID=%MODEL_ID%
echo MODEL_LABEL=%MODEL_LABEL%
echo MODEL_FILE=%MODEL_FILE%
echo MMPROJ_FILE=%MMPROJ_FILE%
echo MAXCTX=%MODEL_MAXCTX%
echo MODEL_ALIAS=%MODEL_ALIAS%
) > "%CFG_FILE%"
echo   %ESC%[1;32m+ %ESC%[0m Дефолт записан: %MODEL_LABEL%

REM --- переключение Hermes на llama-провайдер (:5505) ---
if exist "%HERMES_BIN%" (
    "%HERMES_BIN%" config set model.default "%MODEL_ALIAS%" >nul 2>&1
    "%HERMES_BIN%" config set model.provider "llama" >nul 2>&1
    "%HERMES_BIN%" config set model.base_url "http://127.0.0.1:5505/v1" >nul 2>&1
    "%HERMES_BIN%" config set providers.llama.model "%MODEL_ALIAS%" >nul 2>&1
    "%HERMES_BIN%" config set providers.llama.base_url "http://127.0.0.1:5505/v1" >nul 2>&1
    REM --- модель для зрения (auxiliary.vision) = та же llama-модель ---
    "%HERMES_BIN%" config set auxiliary.vision.model "%MODEL_ALIAS%" >nul 2>&1
    "%HERMES_BIN%" config set auxiliary.vision.provider "llama" >nul 2>&1
    "%HERMES_BIN%" config set auxiliary.vision.base_url "http://127.0.0.1:5505/v1" >nul 2>&1
    echo   Hermes: переключён на llama :5505 ^(%MODEL_ALIAS%^)
) else (
    echo   %ESC%[1;33m  Hermes CLI не найден - конфиг Hermes не тронут.%ESC%[0m
)

REM --- перезапуск llama с новой моделью (через LlamaCppWindowsManager) ---
call :restart_llama
exit /b 0

REM ============================================================================
REM   :restart_llama — переключение llama-сервера через LlamaCppWindowsManager
REM   (llwmctl: регистрация моделей из %MODELS_DIR%, загрузка новой модели)
REM ============================================================================
:restart_llama
set "LLWMCTL=%DATA_DIR%\llama-manager\llwmctl.exe"

if not exist "%LLWMCTL%" (
    echo   %ESC%[1;33m  LlamaCppWindowsManager не установлен - модель применится после установки менеджера.%ESC%[0m
    goto hermes_restart
)

"%LLWMCTL%" status >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[1;33m  LlamaCppWindowsManager не запущен.%ESC%[0m
    echo   %ESC%[2m    Запустите менеджер ^([3] в меню «Расширения и плагины»^) и загрузите модель: %MODEL_LABEL%%ESC%[0m
    goto hermes_restart
)

echo   %ESC%[2m  Регистрирую модели из %MODELS_DIR%...%ESC%[0m
"%LLWMCTL%" models import --folder "%MODELS_DIR%" >nul 2>&1
"%LLWMCTL%" models scan >nul 2>&1

echo   %ESC%[2m  Переключаю llama-сервер на %MODEL_LABEL% ...%ESC%[0m
"%LLWMCTL%" load "%MODEL_FILE%" --wait >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[1;33m  Не удалось загрузить модель через llwmctl - загрузите её вручную в менеджере.%ESC%[0m
) else (
    echo   %ESC%[1;32m+ %ESC%[0m llama-сервер переключён: %MODEL_LABEL%
)

:hermes_restart

REM --- перезапуск Hermes, если он работает службой ---
call "%SCRIPTS_DIR%\Find-Hermes-Service.bat" "%ROOT_DIR%" <nul
if defined SERVICE_NAME (
    set "hsrv="
    set /p "hsrv=%ESC%[33mПерезапустить службу Hermes ^(%SERVICE_NAME%^) сейчас ^(y/N^)? %ESC%[0m"
    if /i "!hsrv!"=="y" (
        echo   Перезапуск службы Hermes...
        sc stop "%SERVICE_NAME%" >nul 2>&1
        timeout /t 2 >nul
        sc start "%SERVICE_NAME%" >nul 2>&1
        if errorlevel 1 (
            echo   %ESC%[1;33m  Служба Hermes не перезапустилась - нужны права администратора.%ESC%[0m
        )
    )
) else (
    echo   %ESC%[2m  Hermes службой не установлен - конфиг применится при следующем запуске.%ESC%[0m
)

call "%SCRIPTS_DIR%\SmartPause.bat" 5
exit /b 0

:clear_default
(
echo MODEL_ID=
echo MODEL_LABEL=
echo MODEL_FILE=
echo MMPROJ_FILE=
echo MAXCTX=
echo MODEL_ALIAS=
) > "%CFG_FILE%"
echo   %ESC%[1;32m+ %ESC%[0m Локальная llama отключена - дефолтная модель снята.
echo   %ESC%[2m    Конфиг Hermes и MemOS настроятся при следующем запуске Start.bat.%ESC%[0m
pause
goto exit

:exit
exit /b 0

REM ============================================================================
REM   :download_hf REPO FILE DIR — hf download -> curl fallback
REM ============================================================================
:download_hf
set "DL_REPO=%~1"
set "DL_FILE=%~2"
set "DL_DIR=%~3"
if defined HF (
    echo   %ESC%[2m    hf download %DL_FILE% ...%ESC%[0m
    "%HF%" download "%DL_REPO%" "%DL_FILE%" --local-dir "%DL_DIR%"
    if not errorlevel 1 exit /b 0
    echo   %ESC%[1;33m    hf не справился - фоллбэк curl...%ESC%[0m
)
call :download "https://huggingface.co/%DL_REPO%/resolve/main/%DL_FILE%" "%DL_DIR%\%DL_FILE%" "%DL_FILE%"
exit /b 0

REM ============================================================================
REM   :download URL FILE NAME — скачивание: напрямую -> прокси -> PowerShell
REM ============================================================================
:download
set "DL_URL=%~1"
set "DL_FILE=%~2"
set "DL_NAME=%~3"
if exist "%DL_FILE%" del "%DL_FILE%" 2>nul
echo   %ESC%[2m    Загрузка %DL_NAME% ...%ESC%[0m
REM сначала напрямую (90% скриптов ходят напрямую!)
"%CURL%" -L --fail --noproxy "*" -C - -o "%DL_FILE%" "%DL_URL%"
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m    Напрямую не вышло - пробуем через прокси %PROXY%...%ESC%[0m
    "%CURL%" -L --fail -x "%PROXY%" -C - --retry 8 --retry-delay 3 --retry-all-errors -o "%DL_FILE%" "%DL_URL%"
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m    Прокси не помог - переключение на PowerShell...%ESC%[0m
    powershell -NoProfile -NonInteractive -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; try { Invoke-WebRequest -Uri '%DL_URL%' -OutFile '%DL_FILE%' -UseBasicParsing -TimeoutSec 600 } catch { exit 1 }"
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;31m[ОШИБКА] Загрузка не удалась...%ESC%[0m
    echo   %ESC%[33mURL: %DL_URL%%ESC%[0m
    exit /b 1
)
echo   %ESC%[1;32m    OK: %DL_NAME%%ESC%[0m
exit /b 0

