@REM scripts\InstallOrUpdate.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Установка / Обновление

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"

REM ============================================================================
REM   HERMES_HOME и пути
REM ============================================================================
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
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

:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                 %ESC%[1;37mHermes Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление%ESC%[0m               %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Проверка статуса компонентов
REM ============================================================================

REM Desktop app
set "DESKTOP_INSTALLED=0"
set "DESKTOP_EXE_PATH="
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

REM KoboldCpp
set "KCPP_STATUS=Установить"
set "KCPP_COLOR=%ESC%[1;33m"
set "KCPP_INSTALLED=0"
if exist "%ROOT_DIR%\kobold\koboldcpp.exe" (
    set "KCPP_STATUS=Обновить"
    set "KCPP_COLOR=%ESC%[1;32m"
    set "KCPP_INSTALLED=1"
)

REM ============================================================================
REM   Вывод меню
REM ============================================================================

if !DESKTOP_INSTALLED! equ 0 (
    if !KCPP_INSTALLED! equ 0 (
        echo   %ESC%[1;33mНичего не установлено. Выберите действие:%ESC%[0m
        echo.
        echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1;33mУстановить Hermes Desktop%ESC%[0m
        echo.
        echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1;33mУстановить KoboldCpp%ESC%[0m
        echo.
        echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
        echo.
        set "choice="
        set /p "choice=%ESC%[33mВыберите действие: %ESC%[0m"

        set "choice=!choice: =!"
        if "!choice!"=="" goto menu
        if "!choice!"=="1" goto install_desktop
        if "!choice!"=="2" goto install_kobold
        if "!choice!"=="0" goto exit
        goto menu
    )
)

echo   %ESC%[1;33mУстановленные компоненты:%ESC%[0m
if !DESKTOP_INSTALLED! equ 1 (
    echo     %ESC%[1;32m+%ESC%[0m Desktop App %ESC%[2m^(Hermes.exe^)%ESC%[0m
) else (
    echo     %ESC%[1;33m.%ESC%[0m Desktop App %ESC%[2m^(не собран^)%ESC%[0m
)
if !KCPP_INSTALLED! equ 1 echo     %ESC%[1;32m+%ESC%[0m KoboldCpp
echo.
echo   %ESC%[1;33mВыберите действие:%ESC%[0m
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановить / Обновить Hermes Desktop%ESC%[0m
echo   %ESC%[1;37m[2]%ESC%[0m !KCPP_COLOR!!KCPP_STATUS! KoboldCpp%ESC%[0m %ESC%[2m^(LLM сервер^)%ESC%[0m

echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие: %ESC%[0m"

set "choice=!choice: =!"
if "!choice!"=="" goto menu
if "!choice!"=="1" goto install_desktop
if "!choice!"=="2" goto install_kobold
if "!choice!"=="0" goto exit
goto menu

:install_desktop
cls
echo.
echo   %ESC%[1;33m-%ESC%[0m %ESC%[1mЗапуск установки Hermes Desktop...%ESC%[0m
echo.
call "%SCRIPTS_DIR%\InstallOrUpdate-Desktop.bat" 0
goto menu

:install_kobold
REM Проверка GPU на минимальный контекст Hermes (65536)
call "%SCRIPTS_DIR%\DetectGPU.bat"

REM --- Страховки: если DetectGPU не определил переменные ---
if not defined GPU_TYPE set "GPU_TYPE=UNKNOWN"
if not defined GPU_VRAM_NUM set "GPU_VRAM_NUM=0"

set "KCPP_MIN_CTX=65536"
set "GPU_CAN_RUN=0"

if "!GPU_TYPE!"=="NVIDIA" (
    if !GPU_VRAM_NUM! GEQ 11000 set "GPU_CAN_RUN=1"
) else if "!GPU_TYPE!"=="AMD" (
    if !GPU_VRAM_NUM! GEQ 11000 set "GPU_CAN_RUN=1"
) else if "!GPU_TYPE!"=="INTEL" (
    REM Intel использует системную RAM — проверяем общую RAM
    REM PowerShell + CIM: локале-независимо (systeminfo на RU Windows
    REM выводит "Полный объем физической памяти" и findstr промахивается)
    set "TOTAL_RAM="
    for /f %%a in ('powershell -NoProfile -Command "[math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1MB)"') do set "TOTAL_RAM=%%a"
    if not defined TOTAL_RAM set "TOTAL_RAM=0"
    if !TOTAL_RAM! GEQ 32000 set "GPU_CAN_RUN=1"
)

if "!GPU_CAN_RUN!"=="0" (
    echo.
    echo   %ESC%[1;31m[ВНИМАНИЕ] Ваша видеокарта не поддерживает минимальный контекст для Hermes%ESC%[0m
    echo   %ESC%[33m         Требуется: 65536 токенов ^(минимум для Hermes^)%ESC%[0m
    echo   %ESC%[33m         GPU: !GPU_NAME! ^(!GPU_VRAM_MB! MB VRAM^)%ESC%[0m
    if "!GPU_TYPE!"=="INTEL" (
        echo   %ESC%[33m         Intel GPU требует минимум 32GB системной RAM.%ESC%[0m
    ) else (
        echo   %ESC%[33m         Требуется GPU с 11GB+ VRAM ^(NVIDIA/AMD^).%ESC%[0m
    )
    echo   %ESC%[33m         KoboldCpp установится, но Hermes будет работать некорректно.%ESC%[0m
    echo.
    set "FORCE_INSTALL="
    set /p "FORCE_INSTALL=%ESC%[1;33m  ?   Продолжить установку в любом случае? [Y/N]: %ESC%[0m"
    if /I "!FORCE_INSTALL!"=="Y" (
        echo   %ESC%[1;33m  -   Продолжаем на свой страх и риск...%ESC%[0m
    ) else (
        echo   %ESC%[1;33m  .   Установка отменена.%ESC%[0m
        timeout /t 3 /nobreak >nul
        goto menu
    )
)

cls
echo.
echo   %ESC%[1;33m-%ESC%[0m %ESC%[1mЗапуск !KCPP_STATUS! KoboldCpp...%ESC%[0m
echo.
call "%SCRIPTS_DIR%\InstallOrUpdate-Kobold.bat" 0
goto menu

:exit
exit /b 0