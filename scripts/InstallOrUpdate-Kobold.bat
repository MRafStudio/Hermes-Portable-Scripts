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
set "MODEL_BF16=Qwythos-9B-Claude-Mythos-5-1M-BF16.gguf"
set "MODEL_Q8=Qwythos-9B-Claude-Mythos-5-1M-Q8_0.gguf"
set "MMPROJ_FILE=mmproj-Qwythos-9B-Claude-Mythos-5-1M-F16.gguf"

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
REM   Статус
REM ============================================================================
:status
set "KCPP_INSTALLED=0"
if exist "%KCPP_EXE%" set "KCPP_INSTALLED=1"

set "MODEL_FILE="
if exist "%MODELS_DIR%\%MODEL_BF16%" set "MODEL_FILE=%MODEL_BF16%"
if exist "%MODELS_DIR%\%MODEL_Q8%" set "MODEL_FILE=%MODEL_Q8%"

REM ============================================================================
REM   Меню
REM ============================================================================
:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                    Hermes%ESC%[0m — %ESC%[1;33mKoboldCPP (локальная LLM)%ESC%[0m                %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
if !KCPP_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m KoboldCPP %ESC%[2m^(v%KCPP_VER%^)%ESC%[0m — установлен в %ESC%[2m%KCPP_DIR%%ESC%[0m
) else (
    echo   %ESC%[1;33m. %ESC%[0m KoboldCPP — не установлен
)
if exist "%MODELS_DIR%\%MODEL_BF16%" (
    echo   %ESC%[1;32m+ %ESC%[0m Модель: %ESC%[2m%MODEL_BF16% ^(BF16, ^>= 24 GB^)%ESC%[0m
) else if exist "%MODELS_DIR%\%MODEL_Q8%" (
    echo   %ESC%[1;32m+ %ESC%[0m Модель: %ESC%[2m%MODEL_Q8% ^(Q8_0, ^>= 16 GB^)%ESC%[0m
) else (
    echo   %ESC%[1;33m. %ESC%[0m Модель: не установлена
)
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
echo   %ESC%[2mПорт API:   %KCPP_PORT% ^(чтобы не конфликтовать со сторонним KoboldCPP на 5001^)%ESC%[0m
echo   %ESC%[2mИсточник:   GitHub releases ^(koboldcpp.exe^) + Hugging Face ^(модель, проектор^)%ESC%[0m
echo.


REM --- Выбор модели ---
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mQwythos-9B BF16%ESC%[0m %ESC%[2m^(17.9 GB^)%ESC%[0m — для видеокарт с памятью ^(^>= 24 GB^)
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mQwythos-9B Q8_0%ESC%[0m %ESC%[2m^(9.5 GB^)%ESC%[0m — для видеокарт с памятью ^(^>= 16 GB^)
echo.
set "model_choice="
set /p "model_choice=%ESC%[33mВыберите модель (1-2): %ESC%[0m"
set "model_choice=%model_choice: =%"
if "%model_choice%"=="1" (
    set "MODEL_FILE=%MODEL_BF16%"
) else if "%model_choice%"=="2" (
    set "MODEL_FILE=%MODEL_Q8%"
) else (
    echo   %ESC%[1;31mНекорректный выбор.%ESC%[0m
    pause
    goto install_kobold
)
set "MODEL_ID=koboldcpp/!MODEL_FILE:.gguf=!"
set "MODEL_URL=https://huggingface.co/%MODEL_REPO%/resolve/main/%MODEL_FILE%"
set "MMPROJ_URL=https://huggingface.co/%MODEL_REPO%/resolve/main/%MMPROJ_FILE%"

echo.
echo   %ESC%[33m  Будет загружено: %ESC%[1m%MODEL_FILE%%ESC%[0m
echo   %ESC%[33m  Продолжить ^(y/N^)? %ESC%[0m
set "confirm="
set /p "confirm="
if /i not "%confirm%"=="y" goto menu

REM ============================================================================
REM   Скачивание
REM ============================================================================
if not exist "%KCPP_DIR%" mkdir "%KCPP_DIR%" 2>nul
if not exist "%MODELS_DIR%" mkdir "%MODELS_DIR%" 2>nul

echo.
echo %ESC%[1;33m 1/3 KoboldCPP.exe%ESC%[0m
if exist "%KCPP_EXE%" (
    echo   %ESC%[2m    koboldcpp.exe уже есть — удаляю для обновления...%ESC%[0m
    del "%KCPP_EXE%" 2>nul
)
set "KCPP_URL="
for /f "delims=" %%u in ('powershell -NoProfile -NonInteractive -Command "$j = Invoke-RestMethod -Uri 'https://api.github.com/repos/LostRuins/koboldcpp/releases/latest' -Headers @{'User-Agent'='HermesPortable'} -TimeoutSec 30; ($j.assets | Where-Object { $_.name -eq 'koboldcpp.exe' } | Select-Object -First 1).browser_download_url" 2^>nul') do set "KCPP_URL=%%u"
if not defined KCPP_URL set "KCPP_URL=%KCPP_FALLBACK_URL%"
call :download "%KCPP_URL%" "%KCPP_EXE%" "koboldcpp.exe"

echo.
echo %ESC%[1;33m 2/3 Проектор ^(vision^)%ESC%[0m
if not exist "%MODELS_DIR%\%MMPROJ_FILE%" (
    call :download "%MMPROJ_URL%" "%MODELS_DIR%\%MMPROJ_FILE%" "%MMPROJ_FILE%"
) else (
    echo   %ESC%[2m    Проектор уже есть — пропуск.%ESC%[0m
)

echo.
echo %ESC%[1;33m 3/3 Модель%ESC%[0m
if not exist "%MODELS_DIR%\%MODEL_FILE%" (
    call :download "%MODEL_URL%" "%MODELS_DIR%\%MODEL_FILE%" "%MODEL_FILE%"
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
        for /f "delims=" %%m in ('"%PYTHON_EXE%" "%SCRIPTS_DIR%\py\kobold_check_main_model.py" "%CONFIG_YAML%" 2^>nul') do set "CUR_MODEL=%%m"
    )
    if defined CUR_MODEL (
        echo   %ESC%[1;33m. %ESC%[0m Основная модель уже настроена: %ESC%[1m!CUR_MODEL!%ESC%[0m — не трогаю
        echo   %ESC%[2m    Vision → KoboldCPP (локальная мультимодальная модель)%ESC%[0m
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
    "%CURL%" -L -C - --retry 5 --retry-delay 5 -o "%DL_FILE%" "%DL_URL%" >nul 2>&1
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m    curl не справился — переключение на PowerShell ^(TLS12^)...%ESC%[0m
    powershell -NoProfile -NonInteractive -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; try { Invoke-WebRequest -Uri '%DL_URL%' -OutFile '%DL_FILE%' -UseBasicParsing -TimeoutSec 600 } catch { exit 1 }" >nul 2>&1
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;31m[ОШИБКА] Загрузка не удалась: %DL_NAME%%ESC%[0m
    echo   %ESC%[33mURL: %DL_URL%%ESC%[0m
    pause
    exit /b 1
)
echo   %ESC%[1;32m    OK: %DL_NAME%%ESC%[0m
goto :eof

:exit
exit /b 0
