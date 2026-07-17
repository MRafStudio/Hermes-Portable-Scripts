@REM scripts\InstallOrUpdate-HF.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Hermes Portable — Установка HuggingFace Hub

REM ============================================================================
REM   Определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"
set "DATA_DIR=%ROOT_DIR%\data"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "VENV_DIR=%REPO_DIR%\venv"
set "VENV_PYTHON=%VENV_DIR%\Scripts\python.exe"
set "UV_DIR=%HERMES_HOME%\bin"
set "UV_EXE=%UV_DIR%\uv.exe"

REM --- uv-Python: базовый интерпретатор (НЕ venv!) — главная цель для hf.exe ---
REM --- KoboldCpp находит hf через PATH, ему venv Hermes не нужен ---
set "PYTHON_DIR=%DATA_DIR%\appdata\uv\python\cpython-3.11.15-windows-x86_64-none"
set "PYTHON_EXE=%PYTHON_DIR%\python.exe"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "PIP_CACHE_DIR=%DATA_DIR%\pip-cache"
set "HF_HOME=%DATA_DIR%\huggingface"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%PIP_CACHE_DIR%" mkdir "%PIP_CACHE_DIR%" 2>nul
if not exist "%HF_HOME%" mkdir "%HF_HOME%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Проверка компонентов (venv НЕ требуется: KoboldCpp работает без Hermes!)
REM ============================================================================
if not exist "%UV_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] UV не найден%ESC%[0m
    echo   %ESC%[33m       Путь: %UV_EXE%%ESC%[0m
    echo   %ESC%[33m       Сначала запустите полную установку Hermes.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

if not exist "%PYTHON_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] Автономный Python (uv) не найден%ESC%[0m
    echo   %ESC%[33m       Путь: %PYTHON_EXE%%ESC%[0m
    echo   %ESC%[33m       Сначала запустите полную установку Hermes.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m               %ESC%[1;37mHermes Portable%ESC%[0m   %ESC%[1;33m—%ESC%[0m   %ESC%[1;33mУстановка HuggingFace Hub%ESC%[0m              %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   PATH: uv-Python первым (главная цель), venv — если есть
REM ============================================================================
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%UV_DIR%;%PATH%"
if exist "%VENV_DIR%\Scripts" set "PATH=%VENV_DIR%\Scripts;%PATH%"

REM ============================================================================
REM   Проверка установленного hf.exe (берём ПЕРВОЕ совпадение where)
REM ============================================================================
echo   %ESC%[1;33m[1/2]%ESC%[0m %ESC%[1mПроверка HuggingFace Hub...%ESC%[0m

where hf >nul 2>nul
if !errorlevel! equ 0 (
    set "HF_PATH="
    for /f "tokens=*" %%a in ('where hf 2^>nul') do if not defined HF_PATH set "HF_PATH=%%a"
    echo   %ESC%[1;32m  +   HuggingFace Hub уже установлен.%ESC%[0m
    echo   %ESC%[2m       Путь: !HF_PATH!%ESC%[0m
    echo.
    echo   %ESC%[1;33m  →   Обновление...%ESC%[0m
    goto hf_update
)

echo   %ESC%[1;33m  →   HuggingFace Hub не найден. Установка...%ESC%[0m
goto hf_install

:hf_install
REM ============================================================================
REM   Установка huggingface-hub
REM   Цель 1: uv-Python. Флаг --break-system-packages ОБЯЗАТЕЛЕН:
REM   uv отказывается модифицировать интерпретатор, которым управляет сам
REM   ("externally managed"). Это не venv — правило одного venv соблюдено.
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/2]%ESC%[0m %ESC%[1mУстановка huggingface-hub...%ESC%[0m
echo   %ESC%[2m       Цель 1: автономный Python (для KoboldCpp)%ESC%[0m

"%UV_EXE%" pip install --python "%PYTHON_EXE%" --break-system-packages huggingface-hub

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось установить huggingface-hub.%ESC%[0m
    echo   %ESC%[33m       Проверьте соединение с интернетом.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

if exist "%VENV_PYTHON%" (
    echo   %ESC%[2m       Цель 2: venv Hermes%ESC%[0m
    "%UV_EXE%" pip install --python "%VENV_PYTHON%" huggingface-hub
    if !errorlevel! neq 0 (
        echo   %ESC%[1;33m  ⚠  В venv Hermes установить не удалось — не критично.%ESC%[0m
    )
)

echo   %ESC%[1;32m  +   HuggingFace Hub установлен.%ESC%[0m
goto hf_done

:hf_update
REM ============================================================================
REM   Обновление huggingface-hub (те же цели, тот же флаг)
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/2]%ESC%[0m %ESC%[1mОбновление huggingface-hub...%ESC%[0m
echo   %ESC%[2m       Цель 1: автономный Python (для KoboldCpp)%ESC%[0m

"%UV_EXE%" pip install --python "%PYTHON_EXE%" --break-system-packages --upgrade huggingface-hub

if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  .   Не удалось обновить. Используется текущая версия.%ESC%[0m
) else (
    if exist "%VENV_PYTHON%" (
        echo   %ESC%[2m       Цель 2: venv Hermes%ESC%[0m
        "%UV_EXE%" pip install --python "%VENV_PYTHON%" --upgrade huggingface-hub >nul 2>nul
    )
    echo   %ESC%[1;32m  +   HuggingFace Hub обновлён.%ESC%[0m
)

:hf_done
echo.
echo   %ESC%[1;33m  →   Проверка hf.exe...%ESC%[0m

where hf >nul 2>nul
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m  [ОШИБКА] hf.exe не найден в PATH.%ESC%[0m
    echo   %ESC%[33m         Попробуйте перезапустить скрипт.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

echo   %ESC%[1;32m  +   hf.exe доступен.%ESC%[0m

echo.
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1;32mHuggingFace Hub готов%ESC%[0m
echo   %ESC%[2m  hf.exe: доступен%ESC%[0m
echo   %ESC%[2m  HF_HOME: %HF_HOME%%ESC%[0m
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m

if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0