@REM scripts\Start-Kobold-IfNeeded.bat — поднять KoboldCPP перед запуском Hermes (если установлен)
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Параметры KoboldCPP (как в InstallOrUpdate-Kobold.bat)
REM ============================================================================
set "KCPP_DIR=%DATA_DIR%\kobold"
set "KCPP_PORT=5101"
set "MODEL_BF16=Qwythos-9B-Claude-Mythos-5-1M-BF16.gguf"
set "MODEL_Q8=Qwythos-9B-Claude-Mythos-5-1M-Q8_0.gguf"
set "MMPROJ_FILE=mmproj-Qwythos-9B-Claude-Mythos-5-1M-F16.gguf"

set "CURL_CMD=curl"
if exist "%SYSTEMROOT%\System32\curl.exe" set "CURL_CMD=%SYSTEMROOT%\System32\curl.exe"

REM ============================================================================
REM   Проверка: kobold установлен и модели целые?
REM ============================================================================
if not exist "%KCPP_DIR%\koboldcpp.exe" goto not_installed
if not exist "%KCPP_DIR%\models\%MMPROJ_FILE%" goto not_installed
if not exist "%KCPP_DIR%\models\%MODEL_BF16%" if not exist "%KCPP_DIR%\models\%MODEL_Q8%" goto not_installed

REM ============================================================================
REM   Порт уже отвечает?
REM ============================================================================
"%CURL_CMD%" -s --noproxy "*" -m 2 "http://127.0.0.1:%KCPP_PORT%/v1/models" >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m+ %ESC%[0m KoboldCPP: уже работает %ESC%[2m^(:%KCPP_PORT%^)%ESC%[0m
    exit /b 0
)

REM ============================================================================
REM   Запуск и ожидание ответа (до 60 секунд)
REM ============================================================================
echo   %ESC%[1;33m. %ESC%[0m KoboldCPP: запускаю %ESC%[2m^(:%KCPP_PORT%^)%ESC%[0m...
start /min "KoboldCPP %KCPP_PORT%" cmd /c ""%KCPP_DIR%\start_kobold.bat""

set "READY=0"
for /l %%i in (1,1,60) do (
    "%CURL_CMD%" -s --noproxy "*" -m 2 "http://127.0.0.1:%KCPP_PORT%/v1/models" >nul 2>&1
    if !errorlevel! equ 0 (
        set "READY=1"
        goto kobold_up
    )
    timeout /t 1 /nobreak >nul
)
echo   %ESC%[1;31m[ОШИБКА] KoboldCPP не ответил за 60 сек.%ESC%[0m
echo   %ESC%[33m    Запустите вручную: %KCPP_DIR%\start_kobold.bat%ESC%[0m
exit /b 0

:kobold_up
echo   %ESC%[1;32m+ %ESC%[0m KoboldCPP: запущен, API отвечает %ESC%[2m^(:%KCPP_PORT%^)%ESC%[0m
exit /b 0

:not_installed
exit /b 0
