@REM scripts\Settings.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "CONFIG_FILE=%SCRIPTS_DIR%\Config.ini"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "CONFIG_YAML=%HERMES_HOME%\config.yaml"
set "PATCH_PORT_PS1=%SCRIPTS_DIR%\patch\patch_config_port.ps1"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

:settings_menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                            %ESC%[0m %ESC%[1;37mПараметры KoboldCpp                           %ESC%[0m %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

set "CUR_KOBOLD_ENABLED=0"
set "CUR_KOBOLD_PORT=5001"

if exist "%CONFIG_FILE%" (
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_ENABLED=" "%CONFIG_FILE%"') do set "CUR_KOBOLD_ENABLED=%%b"
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_PORT=" "%CONFIG_FILE%"') do set "CUR_KOBOLD_PORT=%%b"
)

set "CUR_KOBOLD_ENABLED=%CUR_KOBOLD_ENABLED: =%"
set "CUR_KOBOLD_PORT=%CUR_KOBOLD_PORT: =%"

if "!CUR_KOBOLD_ENABLED!"=="" set "CUR_KOBOLD_ENABLED=0"
if "!CUR_KOBOLD_PORT!"=="" set "CUR_KOBOLD_PORT=5001"

echo   %ESC%[1;33mТекущие параметры:%ESC%[0m

if "!CUR_KOBOLD_ENABLED!"=="1" (
    echo     KoboldCpp:      %ESC%[1;32mВКЛЮЧЕН%ESC%[0m
) else (
    echo     KoboldCpp:      %ESC%[1;31mВЫКЛЮЧЕН%ESC%[0m
)

echo     Порт:           %ESC%[1;33m%CUR_KOBOLD_PORT%%ESC%[0m

echo.

echo   %ESC%[1;37m[1]%ESC%[0m KoboldCpp (вкл/выкл)
echo   %ESC%[1;37m[2]%ESC%[0m Изменить порт KoboldCpp
echo.
echo   %ESC%[1;37m[0]%ESC%[0m Назад в главное меню
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите параметр (0-2): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" exit /b 0
if "%choice%"=="1" goto set_kobold
if "%choice%"=="2" goto set_port
goto settings_menu

:set_kobold
cls
echo.
if "!CUR_KOBOLD_ENABLED!"=="1" (
    echo   %ESC%[1;33mKoboldCpp сейчас: ВКЛЮЧЕН%ESC%[0m
    echo   %ESC%[1;37m[1]%ESC%[0m Выключить
) else (
    echo   %ESC%[1;33mKoboldCpp сейчас: ВЫКЛЮЧЕН%ESC%[0m
    echo   %ESC%[1;37m[1]%ESC%[0m Включить
)
echo   %ESC%[1;37m[0]%ESC%[0m Отмена
echo.
set "kobold_choice="
set /p "kobold_choice=%ESC%[33mВыберите: %ESC%[0m"

if "%kobold_choice%"=="1" (
    if "!CUR_KOBOLD_ENABLED!"=="1" (
        set "NEW_KOBOLD=0"
    ) else (
        set "NEW_KOBOLD=1"
    )
    call "%SCRIPTS_DIR%\CreateConfig.bat" "!NEW_KOBOLD!" "" "" "!CUR_KOBOLD_PORT!"
    if "!NEW_KOBOLD!"=="1" (
        echo   %ESC%[1;32m  +   KoboldCpp: ВКЛЮЧЕН%ESC%[0m
    ) else (
        echo   %ESC%[1;32m  +   KoboldCpp: ВЫКЛЮЧЕН%ESC%[0m
    )
)
timeout /t 3 /nobreak >nul
goto settings_menu

:set_port
cls
echo.
echo   %ESC%[1;33mТекущий порт: %CUR_KOBOLD_PORT%%ESC%[0m
echo.
set /p "NEW_PORT=%ESC%[33mВведите новый порт (Enter для отмены): %ESC%[0m"
set "NEW_PORT=%NEW_PORT: =%"
if "!NEW_PORT!"=="" goto settings_menu

REM Проверка: только цифры
echo !NEW_PORT!|findstr /R "^[0-9][0-9]*$" >nul
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] Порт должен быть числом!%ESC%[0m
    timeout /t 3 /nobreak >nul
    goto settings_menu
)

REM Проверка диапазона
if !NEW_PORT! LSS 1024 (
    echo   %ESC%[1;31m[ОШИБКА] Порт должен быть >= 1024!%ESC%[0m
    timeout /t 3 /nobreak >nul
    goto settings_menu
)
if !NEW_PORT! GTR 65535 (
    echo   %ESC%[1;31m[ОШИБКА] Порт должен быть <= 65535!%ESC%[0m
    timeout /t 3 /nobreak >nul
    goto settings_menu
)

call "%SCRIPTS_DIR%\CreateConfig.bat" "!CUR_KOBOLD_ENABLED!" "" "" "!NEW_PORT!"
echo   %ESC%[1;32m  +   Порт обновлён в Config.ini: !NEW_PORT!%ESC%[0m

REM Правим порт в config.yaml (если конфиг и скрипт патча на месте)
if exist "%CONFIG_YAML%" (
    if exist "%PATCH_PORT_PS1%" (
        echo   %ESC%[1;33m  -   Обновление порта в config.yaml...%ESC%[0m
        powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PATCH_PORT_PS1%" -ConfigPath "%CONFIG_YAML%" -NewPort !NEW_PORT!
    ) else (
        echo   %ESC%[1;33m  ⚠  Скрипт patch_config_port.ps1 не найден. Порт в config.yaml не обновлён.%ESC%[0m
    )
)

REM Предупреждение о перезапуске
if "!CUR_KOBOLD_ENABLED!"=="1" (
    echo.
    echo   %ESC%[1;33m  ⚠   ВНИМАНИЕ: KoboldCpp включен!%ESC%[0m
    echo   %ESC%[1;33m       Для применения нового порта перезапустите:%ESC%[0m
    echo   %ESC%[1;37m       1. Остановите KoboldCpp (если запущен)%ESC%[0m
    echo   %ESC%[1;37m       2. Перезапустите Hermes%ESC%[0m
    echo.
)

timeout /t 5 /nobreak >nul
goto settings_menu