@REM scripts\InstallOrUpdate-Plugins.bat — Расширения и плагины Hermes Portable
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Расширения и плагины

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DATA_DIR=%ROOT_DIR%\data"
set "PY=%HERMES_HOME%\hermes-agent\venv\Scripts\python.exe"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul

REM ============================================================================
REM   Получение ESC (стандартный трюк, без PowerShell)
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Параметры плагинов
REM ============================================================================
set "LLM_DIR=%DATA_DIR%\llm"
set "LLM_EXE=%LLM_DIR%\llama-server.exe"
set "MODELS_DIR=%LLM_DIR%\models"
set "SERVICE_NAME=LlamaCPP"

REM ============================================================================
REM   Статусы плагинов
REM ============================================================================
REM   CRLF-нормализация .bat (ОБЯЗАТЕЛЬНО для Windows! после git pull/write_file
REM   .bat могут получить LF - cmd ломается: 'VERSION' is not recognized!)
REM ============================================================================
if exist "%PY%" (
    "%PY%" "%SCRIPTS_DIR%\py\normalize_crlf.py" "%ROOT_DIR%"
    if !errorlevel! equ 0 (
        echo %ESC%[1;32m  +   CRLF: все .bat в порядке ^(Windows-формат^)!%ESC%[0m
    ) else (
        echo %ESC%[1;33m  .   CRLF: файлы с LF найдены - исправьте или повторите.%ESC%[0m
    )
)

:status
set "LLAMA_EXE=%DATA_DIR%\llama\llama-server.exe"
set "LLM_INSTALLED=0"
if exist "%LLAMA_EXE%" set "LLM_INSTALLED=1"

set "LLM_MODEL="
set "LLM_ANY=0"
if exist "%MODELS_DIR%\*.gguf" set "LLM_ANY=1"
if exist "%LLM_DIR%\default_model.cfg" (
    for /f "tokens=1,* delims==" %%a in ('findstr /b "MODEL_LABEL" "%LLM_DIR%\default_model.cfg"') do set "LLM_MODEL=%%b"
)

set "SERVICE_INSTALLED=0"
sc query "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 set "SERVICE_INSTALLED=1"

set "MEMOS_INSTALLED=0"
set "MEMOS_VERSION=?"
if exist "%HERMES_HOME%\memos-plugin\package.json" (
    set "MEMOS_INSTALLED=1"
    for /f "usebackq tokens=2 delims=:, " %%v in (`findstr /c:"\"version\"" "%HERMES_HOME%\memos-plugin\package.json"`) do (
        set "MEMOS_VERSION=%%v"
        set "MEMOS_VERSION=!MEMOS_VERSION:"=!"
    )
)

REM ============================================================================
REM   Меню
REM ============================================================================
:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                         Hermes%ESC%[0m — %ESC%[1;33mРасширения и плагины%ESC%[0m                     %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
if !LLM_INSTALLED! equ 1 (
    if !LLM_ANY! equ 0 (
        echo   %ESC%[1;32m+ %ESC%[0m Llama.cpp — установлен %ESC%[2m^(модели не установлены^)%ESC%[0m
    ) else if defined LLM_MODEL (
        echo   %ESC%[1;32m+ %ESC%[0m Llama.cpp — установлен %ESC%[2m^(модель !LLM_MODEL!^)%ESC%[0m
    ) else (
        echo   %ESC%[1;32m+ %ESC%[0m Llama.cpp — установлен %ESC%[2m^(модели есть - дефолт не назначен^)%ESC%[0m
    )
) else (
    echo   %ESC%[1;33m. %ESC%[0m Llama.cpp — не установлен
)
if !SERVICE_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m Служба Llama.cpp — установлена
) else (
    echo   %ESC%[1;33m. %ESC%[0m Служба Llama.cpp — не установлена
)
if !MEMOS_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m MemOS %ESC%[2m^(v!MEMOS_VERSION!^)%ESC%[0m — память агента: установлен
) else (
    echo   %ESC%[1;33m. %ESC%[0m MemOS — память агента: не установлен
)
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mLlama.cpp — установка/обновление%ESC%[0m
echo       %ESC%[2mЛокальная LLM: скачивание, настройка Hermes, порт 5505%ESC%[0m
echo.
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mЗагрузка и назначение дефолтных моделей%ESC%[0m
echo       %ESC%[2mУстановленные модели, назначение дефолтной, переключение Hermes%ESC%[0m
echo.

echo   %ESC%[1;37m[3]%ESC%[0m %ESC%[1mСлужба Llama.cpp%ESC%[0m
if !SERVICE_INSTALLED! equ 1 (
    echo       %ESC%[2mУдалить службу ^(файлы сохраняются^)%ESC%[0m
) else (
    echo       %ESC%[2mАвтозапуск Llama.cpp при старте Windows%ESC%[0m
)
echo.

echo   %ESC%[1;37m[4]%ESC%[0m %ESC%[1mMemOS — память агента%ESC%[0m
if !MEMOS_INSTALLED! equ 1 (
    echo       %ESC%[2mОбновить до актуальной версии из npm ^(настройки сохраняются^)%ESC%[0m
) else (
    echo       %ESC%[2mУстановить: L1/L2/L3 память, гибридный поиск, viewer :18800%ESC%[0m
)
echo.

echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-4): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" goto exit
if "%choice%"=="1" goto install_llama
if "%choice%"=="2" goto install_models
if "%choice%"=="3" goto llama_service
if "%choice%"=="4" goto install_memos
goto menu

REM ============================================================================
REM   [1] Llama.cpp — установка / обновление
REM ============================================================================
:install_llama
call "%SCRIPTS_DIR%\InstallOrUpdate-Llama.bat"
goto status

REM ============================================================================
REM   [2] Модели — загрузка и назначение дефолтной
REM ============================================================================
:install_models
call "%SCRIPTS_DIR%\InstallOrUpdate-Models.bat"
goto status

REM ============================================================================
REM   [3] Служба Llama.cpp — установка / удаление
REM ============================================================================
:llama_service
call "%SCRIPTS_DIR%\Llama-Service.bat"
goto status

REM ============================================================================
REM   [4] MemOS — установка / обновление / проверка (отдельный скрипт)
REM ============================================================================
:install_memos
call "%SCRIPTS_DIR%\InstallOrUpdate-Memos.bat"
goto status

:exit
exit /b 0
