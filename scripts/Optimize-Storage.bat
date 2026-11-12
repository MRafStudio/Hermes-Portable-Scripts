@REM scripts\Optimize-Storage.bat
@REM Обслуживание базы Hermes: hermes sessions optimize-storage.
@REM Перестраивает FTS-индекс в компактный layout v23 и делает VACUUM.
@REM Требование Hermes: state.db не должен быть занят (gateway/Desktop/cron),
@REM иначе команда отказывается — это НЕ ошибка установки, а пропуск шага.
@REM Вызов: call "%SCRIPTS_DIR%\Optimize-Storage.bat" [--force]
@REM Возврат: 0 — выполнено или штатно пропущено, 1 — реальная ошибка.
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"

REM ESC для цветного вывода (как в остальных скриптах набора)
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"
set "DATA_DIR=%ROOT_DIR%\data"
set "HERMES_HOME=%DATA_DIR%\hermes"
set "HERMES_EXE=%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe"
set "LOG=%DATA_DIR%\temp\optimize-storage.log"

set "FORCE="
if /i "%~1"=="--force" set "FORCE=--force"

echo   Обслуживание базы Hermes (optimize-storage)...

if not exist "%HERMES_EXE%" (
    echo   %ESC%[1;33m  .   hermes.exe не найден — шаг пропущен.%ESC%[0m
    exit /b 0
)

if not exist "%DATA_DIR%\temp" mkdir "%DATA_DIR%\temp" 2>nul

REM Окружение как у остальных скриптов: ничего не писать в системный профиль
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"

cd /d "%HERMES_HOME%"
"%HERMES_EXE%" sessions optimize-storage --yes %FORCE% >"%LOG%" 2>&1
set "RC=!errorlevel!"

if !RC! equ 0 (
    echo   %ESC%[1;32m  +   База Hermes оптимизирована.%ESC%[0m
    exit /b 0
)

REM Отказ из-за занятой базы — штатная ситуация: продолжаем установку
findstr /c:"another process is using" "%LOG%" >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;33m  .   state.db занят ^(gateway/Desktop/cron^) — оптимизация пропущена.%ESC%[0m
    echo   %ESC%[2m       Повторить: scripts\Optimize-Storage.bat при остановленных службах.%ESC%[0m
    exit /b 0
)

echo   %ESC%[1;31m  [ОШИБКА] optimize-storage завершился с кодом !RC!%ESC%[0m
echo   %ESC%[2m       Лог: %LOG%%ESC%[0m
exit /b 1
