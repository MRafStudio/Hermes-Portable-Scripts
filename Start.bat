@REM Start.bat — Главное меню Hermes Portable
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Hermes Portable
pushd %~dp0

REM ============================================================================
REM   Пути (относительно Start.bat)
REM ============================================================================
for %%F in ("%~dp0") do set "ROOT_DIR=%%~fF"
set "ROOT_DIR=%ROOT_DIR:~0,-1%"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "CONFIG_FILE=%SCRIPTS_DIR%\Config.ini"

REM HERMES_HOME — критично для Hermes!
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "DATA_DIR=%ROOT_DIR%\data"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"

REM ============================================================================
REM   Изоляция данных (ничего в систему!)
REM ============================================================================
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "PYTHONUSERBASE=%DATA_DIR%\python-userbase"
set "PYTHONPATH="
set "PYTHONHOME="
set "PYTHONSTARTUP="
set "PYTHONIOENCODING=utf-8"
set "PIP_CACHE_DIR=%TEMP%\pip-cache"
set "HF_HOME=%DATA_DIR%\huggingface"
set "HF_HUB_DISABLE_SYMLINKS=1"
set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%HOME%\Desktop" mkdir "%HOME%\Desktop" 2>nul
if not exist "%PYTHONUSERBASE%" mkdir "%PYTHONUSERBASE%" 2>nul
if not exist "%HF_HOME%" mkdir "%HF_HOME%" 2>nul
if not exist "%HERMES_HOME%" mkdir "%HERMES_HOME%" 2>nul

REM ============================================================================
REM   PowerShell wrapper (изоляция) — ТОЛЬКО В START.BAT!
REM ============================================================================
set "PS_WRAPPER=%TEMP%\ps_wrapper.bat"
(
    echo @echo off
    echo set "LOCALAPPDATA=%DATA_DIR%\localappdata"
    echo set "APPDATA=%DATA_DIR%\appdata"
    echo set "TEMP=%TEMP%"
    echo set "TMP=%TMP%"
    echo set "HOME=%HOME%"
    echo set "USERPROFILE=%USERPROFILE%"
    echo powershell -NoProfile -NonInteractive %%*
) > "%PS_WRAPPER%"

for /f "usebackq" %%a in (`%PS_WRAPPER% -Command "Write-Host ([char]27) -NoNewline"`) do set "ESC=%%a"

REM ============================================================================
REM   Определение GPU (для статуса и авто-настройки Kobold)
REM ============================================================================
set "GPU_TYPE=UNKNOWN"
set "GPU_NAME=Не определена"
set "GPU_VRAM_MB=0"
set "GPU_VRAM_NUM=0"

if exist "%SCRIPTS_DIR%\DetectGPU.bat" (
    call "%SCRIPTS_DIR%\DetectGPU.bat"
)

REM ============================================================================
REM   Авто-создание / обновление Config.ini
REM ============================================================================
set "CONFIG_NEED_CREATE=0"
if not exist "%CONFIG_FILE%" (
    set "CONFIG_NEED_CREATE=1"
) else (
    REM Проверяем наличие ключевых параметров
    findstr /B /C:"KOBOLD_ENABLED=" "%CONFIG_FILE%" >nul 2>nul
    if !errorlevel! neq 0 set "CONFIG_NEED_CREATE=1"
)

if "!CONFIG_NEED_CREATE!"=="1" (
    if exist "%CONFIG_FILE%" (
        echo %ESC%[1;33m⚠  Config.ini устарел. Обновление с сохранением настроек...%ESC%[0m

        set "OLD_KOBOLD_ENABLED="
        set "OLD_KOBOLD_MODEL="
        set "OLD_KOBOLD_MMPROJ="

        for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_ENABLED=" "%CONFIG_FILE%"') do set "OLD_KOBOLD_ENABLED=%%b"
        for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MODEL=" "%CONFIG_FILE%"') do set "OLD_KOBOLD_MODEL=%%b"
        for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MMPROJ=" "%CONFIG_FILE%"') do set "OLD_KOBOLD_MMPROJ=%%b"

        set "OLD_KOBOLD_ENABLED=%OLD_KOBOLD_ENABLED: =%"
        set "OLD_KOBOLD_MODEL=%OLD_KOBOLD_MODEL: =%"
        set "OLD_KOBOLD_MMPROJ=%OLD_KOBOLD_MMPROJ: =%"

        if "!OLD_KOBOLD_ENABLED!"=="" set "OLD_KOBOLD_ENABLED=0"
        if "!OLD_KOBOLD_MODEL!"=="" set "OLD_KOBOLD_MODEL=models\Qwen_Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"
        if "!OLD_KOBOLD_MMPROJ!"=="" set "OLD_KOBOLD_MMPROJ=models\mmproj-Qwen_Qwen2.5-VL-7B-Instruct-f16.gguf"

        call "%SCRIPTS_DIR%\CreateConfig.bat" "!OLD_KOBOLD_ENABLED!" "!OLD_KOBOLD_MODEL!" "!OLD_KOBOLD_MMPROJ!"

    ) else (
        echo %ESC%[1;33m-%ESC%[0m %ESC%[1mСоздание Config.ini...%ESC%[0m
        call "%SCRIPTS_DIR%\CreateConfig.bat"
    )
    echo %ESC%[1;32m + Config.ini готов.%ESC%[0m
    echo.
    goto menu
)

:menu
REM ============================================================================
REM   Чтение Config.ini (единственное — перечитываем при каждом возврате)
REM ============================================================================
set "KOBOLD_ENABLED=0"
set "KOBOLD_MODEL=models\Qwen_Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"
set "KOBOLD_MMPROJ=models\mmproj-Qwen_Qwen2.5-VL-7B-Instruct-f16.gguf"

if exist "%CONFIG_FILE%" (
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_ENABLED=" "%CONFIG_FILE%"') do set "KOBOLD_ENABLED=%%b"
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MODEL=" "%CONFIG_FILE%"') do set "KOBOLD_MODEL=%%b"
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_MMPROJ=" "%CONFIG_FILE%"') do set "KOBOLD_MMPROJ=%%b"
)

set "KOBOLD_ENABLED=%KOBOLD_ENABLED: =%"
set "KOBOLD_MODEL=%KOBOLD_MODEL: =%"
set "KOBOLD_MMPROJ=%KOBOLD_MMPROJ: =%"

cls
echo.
echo %ESC%[1;36m################################################################################%ESC%[0m
echo %ESC%[1;36m##                                                                            ##%ESC%[0m
echo %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                 Hermes AI Agent (Portable)%ESC%[0m — %ESC%[1;33mГлавное меню%ESC%[0m                 %ESC%[1;36m##%ESC%[0m
echo %ESC%[1;36m##                                                                            ##%ESC%[0m
echo %ESC%[1;36m################################################################################%ESC%[0m

REM GPU (если определена)
if not "%GPU_TYPE%"=="UNKNOWN" (
    if "%GPU_TYPE%"=="NVIDIA" (
        echo %ESC%[1;32m Найден * GPU: %GPU_NAME% ^| %GPU_VRAM_MB% MB VRAM *%ESC%[0m
    ) else if "%GPU_TYPE%"=="AMD" (
        echo %ESC%[1;32m Найден * GPU: %GPU_NAME% ^| %GPU_VRAM_MB% MB VRAM *%ESC%[0m
    ) else if "%GPU_TYPE%"=="INTEL" (
        echo %ESC%[1;33m Найден * GPU: %GPU_NAME% ^| %GPU_VRAM_MB% MB ^(производительность низкая^) *%ESC%[0m
    )
    echo.
)

REM ============================================================================
REM   Проверка статуса готовности компонентов и элементов запуска
REM ============================================================================
echo %ESC%[1;33mСтатус готовности:%ESC%[0m

REM Desktop app — проверяем все возможные пути
set "DESKTOP_INSTALLED=0"
for %%P in (
    "%REPO_DIR%\apps\desktop\release\win-unpacked\Hermes.exe"
    "%REPO_DIR%\apps\desktop\release\win-ia32-unpacked\Hermes.exe"
    "%REPO_DIR%\apps\desktop\release\win-arm64-unpacked\Hermes.exe"
    "%REPO_DIR%\apps\desktop\release\win-x64-unpacked\Hermes.exe"
) do (
    if exist "%%P" (
        set "DESKTOP_INSTALLED=1"
        set "DESKTOP_EXE_PATH=%%P"
        goto :desktop_found
    )
)
:desktop_found
if !DESKTOP_INSTALLED! equ 1 (
    echo %ESC%[1;32m+ %ESC%[0m Desktop App %ESC%[2m^(Hermes.exe^)%ESC%[0m
) else (
    echo %ESC%[1;33m. %ESC%[0m Desktop App %ESC%[2m^(не собран^)%ESC%[0m
)

REM KoboldCpp — показываем ТОЛЬКО если явно включен в Config.ini
set "KCPP_INSTALLED=0"
if "%KOBOLD_ENABLED%"=="1" (
    if exist "%ROOT_DIR%\kobold\koboldcpp.exe" (
        echo %ESC%[1;32m+ %ESC%[0m KoboldCpp %ESC%[2m^(LLM сервер^)%ESC%[0m
        set "KCPP_INSTALLED=1"
    ) else (
        echo %ESC%[1;31m- %ESC%[0m KoboldCpp — не найден %ESC%[2m^(ожидался в kobold\^)%ESC%[0m
    )
)

echo.
echo %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановка / Обновление компонентов%ESC%[0m
echo %ESC%[1;37m[2]%ESC%[0m %ESC%[1mИнструменты%ESC%[0m
if "%KOBOLD_ENABLED%"=="1" (
    echo %ESC%[1;37m[3]%ESC%[0m %ESC%[1mНастройки%ESC%[0m %ESC%[2m^(Kobold^)%ESC%[0m
)

echo.
echo %ESC%[1;37m[5]%ESC%[0m %ESC%[36mHermes — Варианты запуска%ESC%[0m
echo.

REM Быстрый запуск Desktop — только если собран
if !DESKTOP_INSTALLED! equ 1 (
    echo %ESC%[1;6m[*]%ESC%[0m %ESC%[32mБыстрый запуск Hermes Desktop%ESC%[0m
    echo.
)

echo %ESC%[1;37m[0]%ESC%[0m %ESC%[1mВыход%ESC%[0m
echo.

set "choice=INVALID"
if !DESKTOP_INSTALLED! equ 1 (
    if "%KOBOLD_ENABLED%"=="1" (
        set /p "choice=%ESC%[33mВыберите действие (0-3, 5, Enter для быстрого запуска): %ESC%[0m"
    ) else (
        set /p "choice=%ESC%[33mВыберите действие (0-2, 5, Enter для быстрого запуска): %ESC%[0m"
    )
) else (
    if "%KOBOLD_ENABLED%"=="1" (
        set /p "choice=%ESC%[33mВыберите действие (0-3, 5): %ESC%[0m"
    ) else (
        set /p "choice=%ESC%[33mВыберите действие (0-2, 5): %ESC%[0m"
    )
)

set "choice=%choice: =%"
if "%choice%"=="INVALID" goto launch

if "%choice%"=="" goto launch
if "%choice%"=="*" goto launch
if "%choice%"=="1" goto setup
if "%choice%"=="2" goto dev_tools
if "%choice%"=="3" (
    if "%KOBOLD_ENABLED%"=="1" goto settings
    goto menu
)

if "%choice%"=="5" goto launch_options
if "%choice%"=="0" goto exit
goto menu

:setup
call "%SCRIPTS_DIR%\InstallOrUpdate.bat"
goto menu

:settings
call "%SCRIPTS_DIR%\Settings.bat"
goto menu

:dev_tools
call "%SCRIPTS_DIR%\Tools.bat"
goto menu

:launch_options
call "%SCRIPTS_DIR%\LaunchOptions.bat"
goto menu

:launch
if !DESKTOP_INSTALLED! equ 1 (
    cls
    echo.
    echo %ESC%[1;33m-%ESC%[0m %ESC%[1mЗапуск Hermes Desktop...%ESC%[0m
    echo.
    call "%SCRIPTS_DIR%\Start-Hermes-Desktop.bat" 1
    goto menu
) else (
    cls
    echo.
    echo %ESC%[1;31m[ОШИБКА] Desktop App не собран.%ESC%[0m
    echo %ESC%[33m Запустите установку через пункт меню [1]%ESC%[0m
    echo.
    pause
    goto menu
)

:exit
popd
exit /b 0