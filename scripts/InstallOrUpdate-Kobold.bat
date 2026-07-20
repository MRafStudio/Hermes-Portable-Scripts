@REM scripts\InstallOrUpdate-Kobold.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Параметры
REM   %1 = AUTOCLOSE (1 = авто, 0 = интерактив)
REM   %2 = MODE (full = всё, models = только недостающие модели)
REM ============================================================================
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

set "MODE=full"
if "%2"=="models" set "MODE=models"

set "CONTEXT_LENGTH=%~3"
set "MAX_TOKENS=%~4"

title KoboldCpp Portable

REM ============================================================================
REM   Пути и изоляция
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "CONFIG_FILE=%SCRIPTS_DIR%\Config.ini"

set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "KCPP_DIR=%ROOT_DIR%\kobold"
set "KCPP_EXE=%KCPP_DIR%\koboldcpp.exe"
set "MODELS_DIR=%KCPP_DIR%\models"
set "WHISPER_DIR=%KCPP_DIR%\models\whisper"
set "WHISPER_FILE=%WHISPER_DIR%\ggml-medium.bin"
set "HF_HOME=%DATA_DIR%\huggingface_cache"
set "HUGGINGFACE_HUB_CACHE=%HF_HOME%"
set "TRANSFORMERS_CACHE=%HF_HOME%"
set "PYTHON_DIR=%APPDATA%\uv\python\cpython-3.11.15-windows-x86_64-none"
set "PYTHON_EXE=%PYTHON_DIR%\python.exe"

REM Создаём изолированные папки
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%HOME%\Desktop" mkdir "%HOME%\Desktop" 2>nul
if not exist "%HF_HOME%" mkdir "%HF_HOME%" 2>nul
if not exist "%KCPP_DIR%" mkdir "%KCPP_DIR%" 2>nul
if not exist "%MODELS_DIR%" mkdir "%MODELS_DIR%" 2>nul
if not exist "%WHISPER_DIR%" mkdir "%WHISPER_DIR%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Получаем параметры моделей и адрес загрузки
REM ============================================================================
set "DEFAULT_MODEL="
set "DEFAULT_MMPROJ="
set "MODEL_REPO="
set "MODEL_SIZE="
set "MMPROJ_SIZE="

REM Настраиваем модели на основании расчётов
call "%SCRIPTS_DIR%\Model-Setup.bat" %AUTOCLOSE%
REM if !errorlevel! neq 0 exit /b 1

REM Получаем их из Config.ini
for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MODEL=" "%CONFIG_FILE%"') do set "DEFAULT_MODEL=%%b"
for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MMPROJ=" "%CONFIG_FILE%"') do set "DEFAULT_MMPROJ=%%b"
for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MODEL_REPO=" "%CONFIG_FILE%"') do set "MODEL_REPO=%%b"

set "DEFAULT_MODEL=%DEFAULT_MODEL: =%"
set "DEFAULT_MMPROJ=%DEFAULT_MMPROJ: =%"
set "MODEL_REPO=%MODEL_REPO: =%"

REM Проверяем, что Model-Setup реально записал параметры
if "!DEFAULT_MODEL!"=="" (
    echo   %ESC%[1;31m[ОШИБКА] KOBOLD_MODEL не задан в Config.ini%ESC%[0m
    echo   %ESC%[33m       Model-Setup.bat не записал параметры модели.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)
if "!MODEL_REPO!"=="" (
    echo   %ESC%[1;31m[ОШИБКА] KOBOLD_MODEL_REPO не задан в Config.ini%ESC%[0m
    echo   %ESC%[33m       Model-Setup.bat не записал параметры модели.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

REM Размеры берём из Model-Setup.bat (если он их определил) или дефолт
if "!MODEL_SIZE!"=="" set "MODEL_SIZE=?"
if "!MMPROJ_SIZE!"=="" set "MMPROJ_SIZE=?"

if "!CONTEXT_LENGTH!"=="" set "CONTEXT_LENGTH=65536"
if "!MAX_TOKENS!"=="" set "MAX_TOKENS=0"

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m              %ESC%[1;37mKoboldCpp Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление%ESC%[0m               %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM Показываем GPU и выбранную модель
if not "%GPU_TYPE%"=="UNKNOWN" (
    echo   %ESC%[1;32mGPU: %GPU_NAME% ^| %GPU_VRAM_MB% MB VRAM%ESC%[0m
    echo   %ESC%[1;33mВыбрана модель: %DEFAULT_MODEL% ^(%MODEL_SIZE%^)%ESC%[0m
    echo   %ESC%[2mРепозиторий: %MODEL_REPO%%ESC%[0m
    echo.
)

REM Режим только моделей
if "!MODE!"=="models" (
    echo   %ESC%[1;33m  i   Режим: только недостающие модели ^(пропускаем обновление KoboldCpp^).%ESC%[0m
    echo.
)

REM ============================================================================
REM   ШАГ 0: Проверка разрядности
REM ============================================================================
echo   %ESC%[1;33m[0/4]%ESC%[0m %ESC%[1mПроверка разрядности Windows...%ESC%[0m
set "ARCH_OK=0"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH_OK=1"
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "ARCH_OK=1"
if %ARCH_OK%==0 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Обнаружена 32-разрядная ^(x86^) версия Windows.%ESC%[0m
    echo   %ESC%[33m         KoboldCpp Portable требует 64-разрядную систему ^(x64^).%ESC%[0m
    echo.
    call :cleanup
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)
echo   %ESC%[1;32m  +   Система 64-разрядная (x64).%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 1: Получение версии с GitHub
REM ============================================================================
echo   %ESC%[1;33m[1/4]%ESC%[0m %ESC%[1mПроверка версии KoboldCpp...%ESC%[0m

set "TEMP_JSON=%TEMP%\kobold_release_%RANDOM%.json"
curl -fsSL -o "%TEMP_JSON%" "https://api.github.com/repos/LostRuins/koboldcpp/releases/latest"

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось получить информацию о версиях.%ESC%[0m
    call :cleanup
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

set "LATEST_VERSION="
for /f "tokens=2 delims=:" %%a in ('findstr /C:"\"tag_name\"" "%TEMP_JSON%"') do (
    set "LATEST_VERSION=%%a"
    set "LATEST_VERSION=!LATEST_VERSION:"=!"
    set "LATEST_VERSION=!LATEST_VERSION: =!"
    set "LATEST_VERSION=!LATEST_VERSION:,=!"
)

if not defined LATEST_VERSION (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось определить последнюю версию из ответа GitHub.%ESC%[0m
    call :cleanup
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

echo   %ESC%[2m       Последняя версия: %ESC%[1;33m!LATEST_VERSION!%ESC%[0m

set "LATEST_VERSION_CLEAN=!LATEST_VERSION!"
if "!LATEST_VERSION_CLEAN:~0,1!"=="v" set "LATEST_VERSION_CLEAN=!LATEST_VERSION_CLEAN:~1!"

REM ============================================================================
REM   ШАГ 2: Проверка и обновление KoboldCpp
REM   ПРОПУСКАЕМ если режим "только модели"
REM ============================================================================

if "!MODE!"=="models" (
    echo   %ESC%[1;33m[2/4]%ESC%[0m %ESC%[1mПроверка KoboldCpp...%ESC%[0m
    if exist "%KCPP_EXE%" (
        echo   %ESC%[1;32m  +   KoboldCpp уже установлен ^(пропускаем обновление^).%ESC%[0m
    ) else (
        echo   %ESC%[1;31m[ОШИБКА] KoboldCpp не найден!%ESC%[0m
        echo   %ESC%[33m         Режим "только модели" требует установленный KoboldCpp.%ESC%[0m
        echo   %ESC%[33m         Запустите полную установку через меню [1].%ESC%[0m
        call :cleanup
        if "%AUTOCLOSE%"=="0" pause
        exit /b 1
    )
    echo.
    goto :skip_kcpp_update
)

if exist "%KCPP_EXE%" (
    for /f "tokens=*" %%a in ('"%KCPP_EXE%" --version 2^>nul') do set "CURRENT_VERSION=%%a"
    echo   %ESC%[2m       Текущая версия: %ESC%[1;33m!CURRENT_VERSION!%ESC%[0m

    REM Сравнение по подстроке: надёжно при любом формате вывода --version
    echo !CURRENT_VERSION! | findstr /C:"!LATEST_VERSION_CLEAN!" >nul
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   У вас последняя версия.%ESC%[0m
        echo.
        goto :skip_kcpp_update
    ) else (
        echo   %ESC%[1;33m  -   Доступна новая версия.%ESC%[0m
    )
) else (
    echo   %ESC%[2m       KoboldCpp не установлен.%ESC%[0m
)

echo.
echo   %ESC%[1;33m[2/4]%ESC%[0m %ESC%[1mЗагрузка KoboldCpp...%ESC%[0m

REM Проверяем что JSON скачался
if not exist "%TEMP_JSON%" (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось скачать информацию о версии.%ESC%[0m
    call :cleanup
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

for /f "delims=" %%a in ('powershell -NoProfile -Command "(Get-Content '%TEMP_JSON%' | ConvertFrom-Json).assets | Where-Object { $_.name -eq 'koboldcpp.exe' } | Select-Object -ExpandProperty browser_download_url -First 1"') do set "DOWNLOAD_URL=%%a"

if "!DOWNLOAD_URL!"=="" (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось найти ссылку для скачивания.%ESC%[0m
    echo   %ESC%[33m         Проверьте содержимое %TEMP_JSON%%ESC%[0m
    call :cleanup
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

:download_kobold
echo   %ESC%[2m       Загрузка koboldcpp.exe...%ESC%[0m

REM Пробуем curl
curl -fSL -o "%KCPP_DIR%\koboldcpp_new.exe" --connect-timeout 30 --max-time 300 "!DOWNLOAD_URL!"
if !errorlevel! equ 0 goto :download_kobold_ok

echo   %ESC%[1;33m  ⚠  curl не справился, пробуем PowerShell...%ESC%[0m

REM Fallback: PowerShell
powershell -NoProfile -Command "try { $ProgressPreference = 'Continue'; Invoke-WebRequest -Uri '!DOWNLOAD_URL!' -OutFile '%KCPP_DIR%\koboldcpp_new.exe' -TimeoutSec 300 -UseBasicParsing } catch { exit 1 }"
if !errorlevel! equ 0 goto :download_kobold_ok

echo   %ESC%[1;31m[ОШИБКА] Не удалось загрузить KoboldCpp.%ESC%[0m
del "%KCPP_DIR%\koboldcpp_new.exe" 2>nul

REM В автоматическом режиме не спрашиваем — сразу выходим с ошибкой
if "!AUTOCLOSE!"=="1" (
    echo   %ESC%[1;33m  .   Автоматический режим — повтор невозможен.%ESC%[0m
    call :cleanup
    exit /b 1
)

echo.
echo   %ESC%[1;33m  ?   Попробовать заново? [Y/N]: %ESC%[0m
set /p "RETRY_KOBOLD="
if /I "!RETRY_KOBOLD!"=="Y" (
    echo   %ESC%[1;33m  -   Повторная попытка...%ESC%[0m
    goto :download_kobold
)

call :cleanup
pause
exit /b 1

:download_kobold_ok

if exist "%KCPP_EXE%" (
    if exist "%KCPP_DIR%\koboldcpp_old.exe" del "%KCPP_DIR%\koboldcpp_old.exe" 2>nul
    move "%KCPP_EXE%" "%KCPP_DIR%\koboldcpp_old.exe" >nul 2>nul
)

move "%KCPP_DIR%\koboldcpp_new.exe" "%KCPP_EXE%" >nul
echo   %ESC%[1;32m  +   KoboldCpp !LATEST_VERSION! установлен.%ESC%[0m
echo.

:skip_kcpp_update

del "%TEMP_JSON%" 2>nul

REM ============================================================================
REM   ШАГ 3: Whisper модель
REM ============================================================================
echo   %ESC%[1;33m[3/4]%ESC%[0m %ESC%[1mПроверка Whisper модели...%ESC%[0m

if exist "%WHISPER_FILE%" (
    echo   %ESC%[1;32m  +   Whisper модель уже установлена.%ESC%[0m
    goto :whisper_done
)

echo   %ESC%[1;33m  -   Загрузка Whisper ggml-medium.bin ^(~1.5 ГБ^)...%ESC%[0m

REM Проверяем Python
if not exist "%PYTHON_EXE%" (
    echo   %ESC%[1;31m  [ОШИБКА] Python не установлен!%ESC%[0m
    echo   %ESC%[33m         Сначала установите Python через меню [1].%ESC%[0m
    call :cleanup
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

REM Добавляем Python в PATH для поиска hf.exe
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%PATH%"

where hf >nul 2>nul
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  ⚠  hf.exe не найден. Установка HuggingFace Hub...%ESC%[0m
    call "%SCRIPTS_DIR%\InstallOrUpdate-HF.bat" 1
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m  [ОШИБКА] Не удалось установить HuggingFace Hub.%ESC%[0m
        call :cleanup
        if "%AUTOCLOSE%"=="0" pause
        exit /b 1
    )
)

:download_whisper
echo   %ESC%[1;33m  -   Загрузка через hf.exe...%ESC%[0m

hf download ggerganov/whisper.cpp ggml-medium.bin --local-dir "%WHISPER_DIR%"
if !errorlevel! equ 0 goto :download_whisper_ok

echo   %ESC%[1;33m  ⚠  hf.exe не справился, пробуем PowerShell...%ESC%[0m
powershell -NoProfile -Command "try { $ProgressPreference = 'Continue'; Invoke-WebRequest -Uri 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin' -OutFile '%WHISPER_FILE%' -TimeoutSec 300 -UseBasicParsing } catch { exit 1 }"
if !errorlevel! equ 0 goto :download_whisper_ok

echo   %ESC%[1;31m[ОШИБКА] Не удалось загрузить Whisper модель.%ESC%[0m
del "%WHISPER_FILE%" 2>nul

REM Whisper не критичен: в автоматическом режиме просто пропускаем
if "!AUTOCLOSE!"=="1" (
    echo   %ESC%[1;33m  ⚠  Whisper модель не загружена. Пропускаем...%ESC%[0m
    goto :whisper_done
)

echo.
echo   %ESC%[1;33m  ?   Попробовать заново? [Y/N]: %ESC%[0m
set /p "RETRY_WHISPER="
if /I "!RETRY_WHISPER!"=="Y" (
    echo   %ESC%[1;33m  -   Повторная попытка...%ESC%[0m
    goto :download_whisper
)

echo   %ESC%[1;33m  ⚠  Whisper модель не загружена. Пропускаем...%ESC%[0m
goto :whisper_done

:download_whisper_ok
echo   %ESC%[1;32m  +   Whisper модель загружена.%ESC%[0m

:whisper_done
echo.

REM ============================================================================
REM   ШАГ 4: LLM модель (авто-выбор по GPU)
REM ============================================================================
echo   %ESC%[1;33m[4/4]%ESC%[0m %ESC%[1mПроверка LLM модели...%ESC%[0m

set "MODEL_FILE=%MODELS_DIR%\%DEFAULT_MODEL%"
set "MMPROJ_FILE=%MODELS_DIR%\%DEFAULT_MMPROJ%"

set "MODEL_OK=0"
set "MMPROJ_OK=0"

if exist "%MODEL_FILE%" set "MODEL_OK=1"
if exist "%MMPROJ_FILE%" set "MMPROJ_OK=1"

if !MODEL_OK! equ 1 if !MMPROJ_OK! equ 1 (
    echo   %ESC%[1;32m  +   Модель и проектор уже установлены.%ESC%[0m
    echo   %ESC%[2m       %DEFAULT_MODEL%%ESC%[0m
    echo   %ESC%[2m       %DEFAULT_MMPROJ%%ESC%[0m
    goto model_done
)

REM Проверяем Python и hf.exe
if not exist "%PYTHON_EXE%" (
    echo   %ESC%[1;31m  [ОШИБКА] Python не установлен!%ESC%[0m
    echo   %ESC%[33m         Сначала установите Python через меню [1].%ESC%[0m
    call :cleanup
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%PATH%"

where hf >nul 2>nul
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  ⚠  hf.exe не найден. Установка HuggingFace Hub...%ESC%[0m
    call "%SCRIPTS_DIR%\InstallOrUpdate-HF.bat" 1
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m  [ОШИБКА] Не удалось установить HuggingFace Hub.%ESC%[0m
        call :cleanup
        if "%AUTOCLOSE%"=="0" pause
        exit /b 1
    )
)

REM ============================================================================
REM   Загрузка модели (ПРОПУСКАЕМ если уже есть — goto, а не провал сквозь метку!)
REM ============================================================================
if !MODEL_OK! equ 1 goto :llm_skip_download

echo.
echo   %ESC%[1;33m  -   Загрузка LLM модели...%ESC%[0m
echo   %ESC%[2m       %DEFAULT_MODEL% ^(%MODEL_SIZE%^)%ESC%[0m
echo   %ESC%[2m       Репозиторий: %MODEL_REPO%%ESC%[0m
echo.

:download_model_start
hf download %MODEL_REPO% %DEFAULT_MODEL% --local-dir "%MODELS_DIR%"
if !errorlevel! equ 0 goto download_model_ok

echo   %ESC%[1;33m  ⚠  hf.exe не справился, пробуем PowerShell...%ESC%[0m
powershell -NoProfile -Command "try { $ProgressPreference = 'Continue'; Invoke-WebRequest -Uri 'https://huggingface.co/%MODEL_REPO%/resolve/main/%DEFAULT_MODEL%' -OutFile '%MODEL_FILE%' -TimeoutSec 600 -UseBasicParsing } catch { exit 1 }"
if !errorlevel! equ 0 goto download_model_ok

echo   %ESC%[1;31m[ОШИБКА] Не удалось загрузить LLM модель.%ESC%[0m
del "%MODEL_FILE%" 2>nul

if "!AUTOCLOSE!"=="1" (
    echo   %ESC%[1;33m  .   Автоматический режим — повтор невозможен.%ESC%[0m
    call :cleanup
    exit /b 1
)

echo.
echo   %ESC%[1;33m  ?   Попробовать заново? [Y/N]: %ESC%[0m
set /p "RETRY_MODEL="
if /I "!RETRY_MODEL!"=="Y" (
    echo   %ESC%[1;33m  -   Повторная попытка...%ESC%[0m
    goto download_model_start
)

call :cleanup
pause
exit /b 1

:download_model_ok
echo   %ESC%[1;32m  +   LLM модель загружена.%ESC%[0m

:llm_skip_download

REM ============================================================================
REM   Загрузка проектора (ПРОПУСКАЕМ если уже есть)
REM ============================================================================
if !MMPROJ_OK! equ 1 goto :model_done

echo.
echo   %ESC%[1;33m  -   Загрузка проектора ^(vision^)...%ESC%[0m
echo   %ESC%[2m       %DEFAULT_MMPROJ% ^(%MMPROJ_SIZE%^)%ESC%[0m
echo.

:download_mmproj_start
hf download %MODEL_REPO% %DEFAULT_MMPROJ% --local-dir "%MODELS_DIR%"
if !errorlevel! equ 0 goto download_mmproj_ok

echo   %ESC%[1;33m  ⚠  hf.exe не справился, пробуем PowerShell...%ESC%[0m
powershell -NoProfile -Command "try { $ProgressPreference = 'Continue'; Invoke-WebRequest -Uri 'https://huggingface.co/%MODEL_REPO%/resolve/main/%DEFAULT_MMPROJ%' -OutFile '%MMPROJ_FILE%' -TimeoutSec 600 -UseBasicParsing } catch { exit 1 }"
if !errorlevel! equ 0 goto download_mmproj_ok

echo   %ESC%[1;31m[ОШИБКА] Не удалось загрузить проектор.%ESC%[0m
del "%MMPROJ_FILE%" 2>nul

if "!AUTOCLOSE!"=="1" (
    echo   %ESC%[1;33m  .   Автоматический режим — повтор невозможен.%ESC%[0m
    call :cleanup
    exit /b 1
)

echo.
echo   %ESC%[1;33m  ?   Попробовать заново? [Y/N]: %ESC%[0m
set /p "RETRY_MMPROJ="
if /I "!RETRY_MMPROJ!"=="Y" (
    echo   %ESC%[1;33m  -   Повторная попытка...%ESC%[0m
    goto download_mmproj_start
)

call :cleanup
pause
exit /b 1

:download_mmproj_ok
echo   %ESC%[1;32m  +   Проектор загружен.%ESC%[0m

:model_done
echo.

REM ============================================================================
REM   Обновление Config.ini — отмечаем KoboldCpp как установленный
REM ============================================================================
echo   %ESC%[1;33m  -   Обновление Config.ini...%ESC%[0m

call "%SCRIPTS_DIR%\CreateConfig.bat" "1" "!DEFAULT_MODEL!" "!DEFAULT_MMPROJ!"

echo   %ESC%[1;32m  +   Config.ini обновлён. KoboldCpp отмечен как установлен.%ESC%[0m
echo.

REM ============================================================================
REM   Патч config.yaml для KoboldCpp
REM ============================================================================
set "PATCH_PORT=5001"
for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_PORT=" "%ROOT_DIR%\scripts\Config.ini" 2^>nul') do set "PATCH_PORT=%%b"
set "PATCH_PORT=%PATCH_PORT: =%"

echo.
echo   %ESC%[1;33m  ─── Патч config.yaml для KoboldCpp ───%ESC%[0m
echo   %ESC%[2m       Путь: %ROOT_DIR%\data\hermes\config.yaml%ESC%[0m
echo.
echo   %ESC%[1m  Что изменит патч:%ESC%[0m
echo     %ESC%[1;33m*%ESC%[0m Hermes переключится на ЛОКАЛЬНУЮ LLM ^(KoboldCpp^)%ESC%[0m
echo     %ESC%[2m    Адрес: http://127.0.0.1:!PATCH_PORT! ^(custom сервер^)%ESC%[0m
echo     %ESC%[2m    Модель: !DEFAULT_MODEL!%ESC%[0m
echo     %ESC%[1;33m*%ESC%[0m Текущие настройки модели в config.yaml будут ПЕРЕЗАПИСАНЫ.%ESC%[0m
echo.
echo   %ESC%[2m  config.yaml всегда можно открыть и изменить вручную:%ESC%[0m
echo   %ESC%[2m  главное меню - Инструменты ^(Tools.bat^) - пункт [3] Открыть config.yaml%ESC%[0m
echo.
echo   %ESC%[1;37m[Y]%ESC%[0m %ESC%[1mДа, применить патч%ESC%[0m
echo   %ESC%[1;37m[N]%ESC%[0m %ESC%[1mНет, пропустить%ESC%[0m
echo.
set "PATCH_CHOICE="
set /p "PATCH_CHOICE=%ESC%[33mВыберите действие (Y/N): %ESC%[0m"

set "PATCH_CHOICE=%PATCH_CHOICE: =%"

if /I "%PATCH_CHOICE%"=="Y" (
    echo.
    call "%SCRIPTS_DIR%\PatchConfigKobold.bat" 0 !CONTEXT_LENGTH! !MAX_TOKENS!"
) else (
    echo   %ESC%[1;33m  .   Патч config.yaml пропущен.%ESC%[0m
    echo.
)

REM ============================================================================
REM   Финал
REM ============================================================================
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mУстановка / Обновление KoboldCpp завершены!%ESC%[0m
echo.
echo   %ESC%[1;33mПути:%ESC%[0m
echo   %ESC%[2m       KoboldCpp: %KCPP_DIR%%ESC%[0m
echo   %ESC%[2m       Модели:    %MODELS_DIR%%ESC%[0m
echo   %ESC%[2m       Кэш HF:    %HF_HOME%%ESC%[0m
echo.
echo   %ESC%[1;33mЗапуск:%ESC%[0m
echo   %ESC%[2m       koboldcpp.exe --model models\%DEFAULT_MODEL% --mmproj models\%DEFAULT_MMPROJ% --port 5001 --gpulayers 999 --contextsize 8192%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo.

call :cleanup

if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0

REM ============================================================================
REM   Подпрограмма: cleanup
REM ============================================================================
:cleanup
del "%TEMP%\kobold_release_*.json" 2>nul
exit /b 0