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
"%PY%" "%SCRIPTS_DIR%\py\llama_models.py" list
echo.
set "MID="
set /p "MID=%ESC%[33mВыбери ID модели или Enter для отмены: %ESC%[0m"
if "%MID%"=="" goto exit

set "PICK="
for /f "delims=" %%p in ('""%PY%" "%SCRIPTS_DIR%\py\llama_models.py" pick "%MID%" "llama/x" "%MODELS_DIR%""') do set "PICK=%%p"
if not defined PICK (
    echo   %ESC%[1;31mНекорректный выбор.%ESC%[0m
    pause
    goto exit
)
for /f "tokens=1-6 delims=|" %%a in ("!PICK!") do (
    set "MODEL_FILE=%%b"
    set "MMPROJ_FILE=%%c"
    set "MODEL_REPO=%%d"
    set "MODEL_MAXCTX=%%e"
    set "MMPROJ_SRC=%%f"
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
echo %ESC%[1;32m Готово! Модель в %MODELS_DIR%%ESC%[0m
echo   %ESC%[2mКонтекст модели: %MODEL_MAXCTX% ^| запуск: start_llama.bat%ESC%[0m
pause

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
