@REM scripts\InstallOrUpdate-Llama.bat — llama.cpp server: установка/обновление (Hermes Portable)
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Llama.cpp — Установка / Обновление

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DATA_DIR=%ROOT_DIR%\data"
set "LLAMA_DIR=%DATA_DIR%\llama"
set "LLM_MODELS=%DATA_DIR%\llm\models"
set "PY=%REPO_DIR%\venv\Scripts\python.exe"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "HOME=%DATA_DIR%\home"

if not exist "%LLAMA_DIR%" mkdir "%LLAMA_DIR%" 2>nul
if not exist "%LLM_MODELS%" mkdir "%LLM_MODELS%" 2>nul

REM ============================================================================
REM   Получение ESC (стандартный трюк, без PowerShell)
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   1/4 Проверка llama.cpp (если нет - скачиваем свежий релиз с GitHub)
REM ============================================================================
if exist "%LLAMA_DIR%\llama-server.exe" (
    echo %ESC%[1;32m+ %ESC%[0m llama.cpp: установлен %ESC%[2m^(%LLAMA_DIR%^)%ESC%[0m
    set "LLAMA_NEED=0"
) else (
    echo %ESC%[1;33m. %ESC%[0m llama.cpp: скачиваю свежий релиз ^(GitHub, CUDA 13.3^)...
    cd /d "%LLAMA_DIR%"
    curl -L --noproxy "*" -o llama-bin.zip "https://github.com/ggml-org/llama.cpp/releases/latest/download/llama-bin-win-cuda-13.3-x64.zip" >nul 2>&1
    if errorlevel 1 (
        echo   %ESC%[31m[ERROR]%ESC%[0m не удалось скачать llama.cpp
        pause
        goto menu
    )
    curl -L --noproxy "*" -o llama-cudart.zip "https://github.com/ggml-org/llama.cpp/releases/latest/download/cudart-llama-bin-win-cuda-13.3-x64.zip" >nul 2>&1
    if errorlevel 1 (
        echo   %ESC%[31m[ERROR]%ESC%[0m не удалось скачать CUDA runtime
        pause
        goto menu
    )
    unzip -q -o llama-bin.zip 2>nul
    unzip -q -o llama-cudart.zip 2>nul
    del llama-bin.zip llama-cudart.zip 2>nul
    if not exist "%LLAMA_DIR%\llama-server.exe" (
        echo   %ESC%[31m[ERROR]%ESC%[0m llama-server.exe не найден после распаковки
        pause
        goto menu
    )
    echo %ESC%[1;32m+ %ESC%[0m llama.cpp: установлен
)

REM ============================================================================
REM   2/4 Выбор модели (общая база llama_models.py — модели общие!)
REM ============================================================================
:pick_model
echo.
echo %ESC%[1;37mДоступные модели%ESC%[0m ^(общая библиотека llama_models.py^):
"%PY%" "%SCRIPTS_DIR%\py\llama_models.py" list
echo.
set "MID="
set /p "MID=%ESC%[33mВыбери ID модели или Enter для отмены: %ESC%[0m"
if "%MID%"=="" goto menu

set "PICK="
for /f "delims=" %%p in ('""%PY%" "%SCRIPTS_DIR%\py\llama_models.py" pick "%MID%" "llama/x" "%LLM_MODELS%""') do set "PICK=%%p"
if not defined PICK (
    echo   %ESC%[31m[ERROR]%ESC%[0m неверный ID модели
    goto pick_model
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
echo   Контекст:  %MODEL_MAXCTX%
echo   Репозиторий: %MODEL_REPO%
set "confirm="
set /p "confirm=%ESC%[33mУстановить эту модель (y/N)? %ESC%[0m"
if /i not "%confirm%"=="y" goto menu

REM ============================================================================
REM   3/4 Скачивание модели + проектора (если нет) в общий каталог
REM ============================================================================
echo.
echo %ESC%[1;33m 1/2 Модель%ESC%[0m
if not exist "%LLM_MODELS%\%MODEL_FILE%" (
    call :download_hf "%MODEL_REPO%" "%MODEL_FILE%" "%LLM_MODELS%"
) else (
    echo   %ESC%[2m    уже есть - пропускаю%ESC%[0m
)
echo %ESC%[1;33m 2/2 Проектор ^(vision^)%ESC%[0m
if not exist "%LLM_MODELS%\%MMPROJ_FILE%" (
    call :download_hf "%MODEL_REPO%" "%MMPROJ_SRC%" "%LLM_MODELS%"
    if not "%MMPROJ_SRC%"=="%MMPROJ_FILE%" (
        move /y "%LLM_MODELS%\%MMPROJ_SRC%" "%LLM_MODELS%\%MMPROJ_FILE%" >nul 2>&1
    )
) else (
    echo   %ESC%[2m    уже есть - пропускаю%ESC%[0m
)

REM ============================================================================
REM   Генерация start_llama.bat (llama.cpp-флаги)
REM   НЕ перегенерируем, если файл уже есть (правки пользователя сохраняются!)
REM ============================================================================
if exist "%LLAMA_DIR%\start_llama.bat" (
    echo   %ESC%[2m    start_llama.bat уже есть - правки пользователя сохраняются%ESC%[0m
    echo   %ESC%[2m    ^(для перегенерации: удали файл или ответь y на вопрос ниже^)%ESC%[0m
    set "reg="
    set /p "reg=%ESC%[33mПерегенерировать start_llama.bat (y/N)? %ESC%[0m"
    if /i not "%reg%"=="y" goto skip_gen
)
"%PY%" "%SCRIPTS_DIR%\py\llama_gen_startbat.py" "%LLAMA_DIR%" "%MODEL_FILE%" "%MMPROJ_FILE%" 8080 %MODEL_MAXCTX%
if errorlevel 1 (
    echo   %ESC%[31m[ERROR]%ESC%[0m генерация start_llama.bat не удалась
    pause
    goto menu
)
:skip_gen

REM ============================================================================
REM   4/4 Настройка Hermes (providers.llama + default + context_length)
REM ============================================================================
set "HERMES_EXE=%REPO_DIR%\venv\Scripts\hermes.exe"
set "MODEL_DEF=llama/%MODEL_FILE:~0,-5%"
call "%HERMES_EXE%" config set providers.llama.model "%MODEL_DEF%" >nul 2>&1
call "%HERMES_EXE%" config set providers.llama.base_url "http://127.0.0.1:8080/v1" >nul 2>&1
call "%HERMES_EXE%" config set providers.llama.api_mode "openai" >nul 2>&1
call "%HERMES_EXE%" config set model.default "%MODEL_DEF%" >nul 2>&1
if defined MODEL_MAXCTX (
    call "%HERMES_EXE%" config set model.context_length "%MODEL_MAXCTX%" >nul 2>&1
    call "%HERMES_EXE%" config set providers.llama.context_length "%MODEL_MAXCTX%" >nul 2>&1
)
echo.
echo %ESC%[1;32m+ %ESC%[0m Hermes настроен: llama.cpp :8080, модель %MODEL_FILE%
echo   Контекст %MODEL_MAXCTX% ^| запуск: %LLAMA_DIR%\start_llama.bat
echo.
echo %ESC%[1;32m Готово!%ESC%[0m
pause
goto menu

REM ============================================================================
REM   Скачивание с HuggingFace (hf из домовского venv, напрямую без прокси)
REM ============================================================================
:download_hf
set "HF=%REPO_DIR%\venv\Scripts\hf"
set "HF_REPO=%~1"
set "HF_FILE=%~2"
set "HF_DIR=%~3"
"%HF%" download "%HF_REPO%" "%HF_FILE%" --local-dir "%HF_DIR%" >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[31m[ERROR]%ESC%[0m не удалось скачать %HF_FILE%
)
exit /b 0

:menu
exit /b 0
