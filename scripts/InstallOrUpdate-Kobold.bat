@REM scripts\InstallOrUpdate-Kobold.bat — KoboldCPP: установка/обновление (Hermes Portable)
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title KoboldCPP — Установка / Обновление

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DATA_DIR=%ROOT_DIR%\data"

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
REM   Параметры KoboldCPP (жёстко привязан к Hermes: data\kobold, порт 5101)
REM ============================================================================
set "KCPP_DIR=%DATA_DIR%\kobold"
set "KCPP_EXE=%KCPP_DIR%\koboldcpp.exe"
set "MODELS_DIR=%KCPP_DIR%\models"
set "KCPP_PORT=5101"

set "MODEL_REPO=empero-ai/Qwythos-9B-Claude-Mythos-5-1M-GGUF"

set "KCPP_VER=1.118.1"
set "KCPP_FALLBACK_URL=https://github.com/LostRuins/koboldcpp/releases/download/v%KCPP_VER%/koboldcpp.exe"

set "HERMES_EXE=%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe"
set "PYTHON_EXE=%HERMES_HOME%\hermes-agent\venv\Scripts\python.exe"
set "CONFIG_YAML=%HERMES_HOME%\config.yaml"

REM ============================================================================
REM   Определение curl (системный → git-curl)
REM ============================================================================
set "CURL="
if exist "%SYSTEMROOT%\System32\curl.exe" set "CURL=%SYSTEMROOT%\System32\curl.exe"
if not defined CURL for /f "delims=" %%c in ('where curl 2^>nul') do if not defined CURL set "CURL=%%c"
if not defined CURL for /f "delims=" %%c in ('where git 2^>nul') do if not defined CURL set "CURL=%%~dpccurl.exe"

REM ============================================================================
REM   Определение hf (huggingface_hub CLI — загрузка с прогрессом и докачкой)
REM ============================================================================
set "HF_EXE=%HERMES_HOME%\hermes-agent\venv\Scripts\hf.exe"
if not exist "%HF_EXE%" set "HF_EXE="
if not defined HF_EXE for /f "delims=" %%h in ('where hf 2^>nul') do if not defined HF_EXE set "HF_EXE=%%h"

REM ============================================================================
REM   Статус
REM ============================================================================
:status
set "KCPP_INSTALLED=0"
if exist "%KCPP_EXE%" set "KCPP_INSTALLED=1"


REM ============================================================================
REM   Меню
REM ============================================================================
:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                      Hermes%ESC%[0m — %ESC%[1;33mKoboldCPP (локальная LLM)%ESC%[0m                   %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
if !KCPP_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m KoboldCPP %ESC%[2m^(v%KCPP_VER%^)%ESC%[0m — установлен в %ESC%[2m%KCPP_DIR%%ESC%[0m
) else (
    echo   %ESC%[1;33m. %ESC%[0m KoboldCPP — не установлен
)
"%PYTHON_EXE%" "%SCRIPTS_DIR%\py\kobold_models.py" status "%MODELS_DIR%"
echo   %ESC%[2m       Порт: %KCPP_PORT% (отличается от стандартного 5001)%ESC%[0m
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановить / обновить KoboldCPP%ESC%[0m
echo       %ESC%[2mСкачивание koboldcpp.exe + проектор + модель ^(BF16 или Q8_0^),%ESC%[0m
echo       %ESC%[2mнастройка Hermes ^(модель для vision^) и создание start_kobold.bat%ESC%[0m
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в меню «Расширения и плагины»%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-1): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" goto exit
if "%choice%"=="1" goto install_kobold
goto menu

REM ============================================================================
REM   [1] Установка / обновление
REM ============================================================================
:install_kobold
cls
echo.
echo %ESC%[1;33m-%ESC%[0m %ESC%[1mKoboldCPP — установка / обновление...%ESC%[0m
echo.
echo   %ESC%[2mКуда ставим: %KCPP_DIR%%ESC%[0m
echo   %ESC%[2mПорт API:   %KCPP_PORT% (чтобы не конфликтовать со сторонним KoboldCPP на 5001)%ESC%[0m
echo   %ESC%[2mИсточник:   GitHub releases (koboldcpp.exe) + Hugging Face (модель, проектор)%ESC%[0m
echo.


REM --- Выбор модели (справочник kobold_models.py; Enter = модель из config.yaml) ---
set "MODEL_COUNT=2"
for /f "delims=" %%c in ('call "%PYTHON_EXE%" "%SCRIPTS_DIR%\py\kobold_models.py" count 2^>nul') do set "MODEL_COUNT=%%c"
REM --- настроенная модель из config.yaml (через hermes config get) ---
set "CFG_MODEL="
if exist "%HERMES_EXE%" (
    for /f "delims=" %%m in ('call "%HERMES_EXE%" config get model.default 2^>nul') do set "CFG_MODEL=%%m"
    if "!CFG_MODEL:~0,18!"=="Config key not set" set "CFG_MODEL="
)
REM --- короткое имя для подсказки [Enter = ...] ---
set "ENTER_LABEL="
if defined CFG_MODEL (
    for /f "delims=" %%l in ('call "%PYTHON_EXE%" "%SCRIPTS_DIR%\py\kobold_models.py" label "!CFG_MODEL!" 2^>nul') do set "ENTER_LABEL=%%l"
)
if not defined ENTER_LABEL set "ENTER_LABEL=установленная"
"%PYTHON_EXE%" "%SCRIPTS_DIR%\py\kobold_models.py" menu "%MODELS_DIR%"
echo.
set "model_choice="
set /p "model_choice=%ESC%[33mВыберите модель (1-!MODEL_COUNT!) %ESC%[2m[Enter = !ENTER_LABEL!]%ESC%[0m %ESC%[33m: %ESC%[0m"
set "model_choice=%model_choice: =%"
set "PICK="
for /f "delims=" %%p in ('call "%PYTHON_EXE%" "%SCRIPTS_DIR%\py\kobold_models.py" pick "!model_choice!" "!CFG_MODEL!" "%MODELS_DIR%" 2^>nul') do set "PICK=%%p"
if not defined PICK (
    echo   %ESC%[1;31mНекорректный выбор.%ESC%[0m
    pause
    goto install_kobold
)
for /f "tokens=1-4 delims=|" %%a in ("!PICK!") do (
    set "MODEL_FILE=%%b"
    set "MMPROJ_FILE=%%c"
    set "MODEL_REPO=%%d"
)
set "MODEL_ID=koboldcpp/!MODEL_FILE:.gguf=!"
set "MODEL_URL=https://huggingface.co/%MODEL_REPO%/resolve/main/%MODEL_FILE%"
set "MMPROJ_URL=https://huggingface.co/%MODEL_REPO%/resolve/main/%MMPROJ_FILE%"

echo.
echo %ESC%[33m  Основная модель: %ESC%[1m%MODEL_FILE%%ESC%[0m
set "confirm="
set /p "confirm=%ESC%[33m  Продолжить (y/N)? %ESC%[0m"
if /i not "%confirm%"=="y" goto menu

REM ============================================================================
REM   Скачивание
REM ============================================================================
if not exist "%KCPP_DIR%" mkdir "%KCPP_DIR%" 2>nul
if not exist "%MODELS_DIR%" mkdir "%MODELS_DIR%" 2>nul

echo.
echo %ESC%[1;33m 1/3 KoboldCPP.exe%ESC%[0m
REM --- актуальная версия (GitHub latest tag) ---
set "LATEST_VERSION="
for /f "delims=" %%v in ('powershell -NoProfile -NonInteractive -Command "$j = Invoke-RestMethod -Uri 'https://api.github.com/repos/LostRuins/koboldcpp/releases/latest' -Headers @{'User-Agent'='HermesPortable'} -TimeoutSec 30; $j.tag_name" 2^>nul') do set "LATEST_VERSION=%%v"
set "LATEST_VERSION_CLEAN=!LATEST_VERSION!"
if "!LATEST_VERSION_CLEAN:~0,1!"=="v" set "LATEST_VERSION_CLEAN=!LATEST_VERSION_CLEAN:~1!"
REM --- установленная версия ---
set "CURRENT_VERSION="
if exist "%KCPP_EXE%" for /f "tokens=1" %%v in ('"%KCPP_EXE%" --version 2^>nul') do set "CURRENT_VERSION=%%v"
echo   %ESC%[2m    Установленная: %ESC%[1m!CURRENT_VERSION!%ESC%[0m %ESC%[2m^| актуальная: %ESC%[0m!LATEST_VERSION!
set "NEED_DL=1"
if defined CURRENT_VERSION if defined LATEST_VERSION_CLEAN if "!CURRENT_VERSION!"=="!LATEST_VERSION_CLEAN!" set "NEED_DL=0"
if "!NEED_DL!"=="0" (
    echo   %ESC%[1;32m    Версии совпадают — обновление не требуется.%ESC%[0m
) else (
    if defined LATEST_VERSION_CLEAN if exist "%KCPP_EXE%" (
        echo   %ESC%[2m    Удаляю старую версию для обновления...%ESC%[0m
        del "%KCPP_EXE%" 2>nul
    )
    set "KCPP_URL="
    for /f "delims=" %%u in ('powershell -NoProfile -NonInteractive -Command "$j = Invoke-RestMethod -Uri 'https://api.github.com/repos/LostRuins/koboldcpp/releases/latest' -Headers @{'User-Agent'='HermesPortable'} -TimeoutSec 30; ($j.assets | Where-Object { $_.name -eq 'koboldcpp.exe' } | Select-Object -First 1).browser_download_url" 2^>nul') do set "KCPP_URL=%%u"
    if not defined KCPP_URL set "KCPP_URL=%KCPP_FALLBACK_URL%"
    call :download "%KCPP_URL%" "%KCPP_EXE%" "koboldcpp.exe"
)

echo.
echo %ESC%[1;33m 2/3 Проектор ^(vision^)%ESC%[0m
if not exist "%MODELS_DIR%\%MMPROJ_FILE%" (
    call :download_hf "%MODEL_REPO%" "%MMPROJ_FILE%" "%MODELS_DIR%"
) else (
    echo   %ESC%[2m    Проектор уже есть — пропуск.%ESC%[0m
)

echo.
echo %ESC%[1;33m 3/3 Модель%ESC%[0m
if not exist "%MODELS_DIR%\%MODEL_FILE%" (
    call :download_hf "%MODEL_REPO%" "%MODEL_FILE%" "%MODELS_DIR%"
) else (
    echo   %ESC%[2m    Модель уже есть — пропуск.%ESC%[0m
)

REM ============================================================================
REM   Настройка Hermes (модель для vision) + start_kobold.bat
REM ============================================================================
echo.
echo %ESC%[1;33m Настройка Hermes...%ESC%[0m

if exist "%PYTHON_EXE%" (
    "%PYTHON_EXE%" "%SCRIPTS_DIR%\py\kobold_gen_startbat.py" "%KCPP_DIR%" "%MODEL_FILE%" "%MMPROJ_FILE%" "%KCPP_PORT%"
    if errorlevel 1 echo   %ESC%[1;31m[ОШИБКА] start_kobold.bat не создан.%ESC%[0m
) else (
    echo   %ESC%[1;33m    python не найден — start_kobold.bat пропущен.%ESC%[0m
)

if exist "%HERMES_EXE%" if exist "%CONFIG_YAML%" (
    set "CUR_MODEL="
    if exist "%PYTHON_EXE%" (
        for /f "delims=" %%m in ('call "%PYTHON_EXE%" "%SCRIPTS_DIR%\py\kobold_check_main_model.py" "%HERMES_EXE%" 2^>nul') do set "CUR_MODEL=%%m"
    )
    if defined CUR_MODEL (
        echo   %ESC%[1;33m. %ESC%[0m Основная модель уже настроена: %ESC%[1m!CUR_MODEL!%ESC%[0m — не трогаю
        echo   %ESC%[2m    Vision → KoboldCPP ^(локальная мультимодальная модель^)%ESC%[0m
        "%HERMES_EXE%" config set auxiliary.vision.model "%MODEL_ID%" >nul 2>&1
        "%HERMES_EXE%" config set auxiliary.vision.base_url "http://127.0.0.1:%KCPP_PORT%/v1" >nul 2>&1
        echo   %ESC%[1;32m+ %ESC%[0m Hermes: vision = %MODEL_ID% ^(порт %KCPP_PORT%^)
    ) else (
        echo   %ESC%[1;33m. %ESC%[0m Основная модель не настроена.
        set "use_kobold="
        set /p "use_kobold=%ESC%[33mСделать KoboldCPP основной моделью (включая vision) [Y/n]? %ESC%[0m"
        if /i not "!use_kobold!"=="n" (
            set "MODEL_KEY=model.default"
            findstr /c:"^model.default:" "%CONFIG_YAML%" >nul 2>&1 || set "MODEL_KEY=model.name"
            "%HERMES_EXE%" config set !MODEL_KEY! "%MODEL_ID%" >nul 2>&1
            "%HERMES_EXE%" config set model.provider custom >nul 2>&1
            "%HERMES_EXE%" config set model.base_url "http://127.0.0.1:%KCPP_PORT%/v1" >nul 2>&1
            "%HERMES_EXE%" config set auxiliary.vision.model "%MODEL_ID%" >nul 2>&1
            "%HERMES_EXE%" config set auxiliary.vision.base_url "http://127.0.0.1:%KCPP_PORT%/v1" >nul 2>&1
            echo   %ESC%[1;32m+ %ESC%[0m Hermes: основная модель = %MODEL_ID% ^(порт %KCPP_PORT%^)
        ) else (
            "%HERMES_EXE%" config set auxiliary.vision.model "%MODEL_ID%" >nul 2>&1
            "%HERMES_EXE%" config set auxiliary.vision.base_url "http://127.0.0.1:%KCPP_PORT%/v1" >nul 2>&1
            echo   %ESC%[1;33m. %ESC%[0m Основная модель не тронута; vision → KoboldCPP
        )
    )
    if exist "%PYTHON_EXE%" (
        "%PYTHON_EXE%" "%SCRIPTS_DIR%\py\kobold_add_custom_provider.py" "%CONFIG_YAML%" "%MODEL_ID%" "http://127.0.0.1:%KCPP_PORT%/v1"
    )
) else (
    echo   %ESC%[1;33m    Hermes не установлен — настройка конфигурации пропущена.%ESC%[0m
)

echo.
echo %ESC%[1;32m Готово!%ESC%[0m
echo.
echo   %ESC%[2mЗапуск KoboldCPP: %KCPP_DIR%\start_kobold.bat%ESC%[0m
echo   %ESC%[2mAPI: http://127.0.0.1:%KCPP_PORT%/v1%ESC%[0m
echo.
pause
goto status

REM ============================================================================
REM   :download URL FILE NAME — curl → PowerShell (TLS12)
REM ============================================================================
:download
set "DL_URL=%~1"
set "DL_FILE=%~2"
set "DL_NAME=%~3"
echo   %ESC%[2m    Загрузка %DL_NAME% ...%ESC%[0m
if defined CURL (
    "%CURL%" -L -C - --retry 5 --retry-delay 5 -# -o "%DL_FILE%" "%DL_URL%"
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m    curl не справился — переключение на PowerShell ^(TLS12^)...%ESC%[0m
    powershell -NoProfile -NonInteractive -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; try { Invoke-WebRequest -Uri '%DL_URL%' -OutFile '%DL_FILE%' -UseBasicParsing -TimeoutSec 600 } catch { exit 1 }"
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;31m[ОШИБКА] Загрузка не удалась: %DL_NAME%%ESC%[0m
    echo   %ESC%[33mURL: %DL_URL%%ESC%[0m
    pause
    exit /b 1
)
echo   %ESC%[1;32m    OK: %DL_NAME%%ESC%[0m
goto :eof

REM ============================================================================
REM   :download_hf REPO FILE DIR — hf download (tqdm-прогресс, докачка) → curl fallback
REM ============================================================================
:download_hf
set "DL_REPO=%~1"
set "DL_FILE=%~2"
set "DL_DIR=%~3"
if not defined HF_EXE (
    call :download "https://huggingface.co/%DL_REPO%/resolve/main/%DL_FILE%" "%DL_DIR%\%DL_FILE%" "%DL_FILE%"
    goto :eof
)
echo   %ESC%[2m    hf download %DL_FILE% ...%ESC%[0m
"%HF_EXE%" download "%DL_REPO%" "%DL_FILE%" --local-dir "%DL_DIR%"
if errorlevel 1 (
    echo   %ESC%[1;33m    hf не справился — переключение на curl...%ESC%[0m
    call :download "https://huggingface.co/%DL_REPO%/resolve/main/%DL_FILE%" "%DL_DIR%\%DL_FILE%" "%DL_FILE%"
)
goto :eof

:exit
exit /b 0
