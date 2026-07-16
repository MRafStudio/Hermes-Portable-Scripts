REM scripts\Settings.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "CONFIG_FILE=%SCRIPTS_DIR%\Config.ini"

REM ESC (без PS_WRAPPER!)
for /f %%a in ('powershell -NoProfile -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"

:settings_menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                            %ESC%[0m %ESC%[1;37mПараметры KoboldCpp                           %ESC%[0m %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

set "CUR_KOBOLD_ENABLED=0"

if exist "%CONFIG_FILE%" (
    for /f "tokens=1,2 delims==" %%a in ('findstr /B /C:"KOBOLD_ENABLED=" "%CONFIG_FILE%"') do set "CUR_KOBOLD_ENABLED=%%b"
)

set "CUR_KOBOLD_ENABLED=%CUR_KOBOLD_ENABLED: =%"

echo   %ESC%[1;33mТекущие параметры:%ESC%[0m

if "!CUR_KOBOLD_ENABLED!"=="" (
    echo     KoboldCpp:      %ESC%[2m^(не указано^)%ESC%[0m
) else if "!CUR_KOBOLD_ENABLED!"=="1" (
    echo     KoboldCpp:      %ESC%[1;32mВКЛЮЧЕН%ESC%[0m
) else (
    echo     KoboldCpp:      %ESC%[1;31mВЫКЛЮЧЕН%ESC%[0m
)

echo.

echo   %ESC%[1;37m[1]%ESC%[0m KoboldCpp (вкл/выкл)
echo.
echo   %ESC%[1;37m[0]%ESC%[0m Назад в главное меню
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите параметр (0-1): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" exit /b 0
if "%choice%"=="1" goto set_kobold
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
    call "%SCRIPTS_DIR%\CreateConfig.bat" "!NEW_KOBOLD!"
    echo   %ESC%[1;32m  +   KoboldCpp: !NEW_KOBOLD!%ESC%[0m
)
timeout /t 3 /nobreak >nul
goto settings_menu