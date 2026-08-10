@REM scripts\Kobold-Service.bat — установка/удаление службы KoboldCPP (Hermes Portable)
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title KoboldCPP — Служба Windows

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
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
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Параметры
REM ============================================================================
set "KCPP_DIR=%DATA_DIR%\kobold"
set "KCPP_EXE=%KCPP_DIR%\koboldcpp.exe"
set "MODELS_DIR=%KCPP_DIR%\models"
set "KCPP_PORT=5101"
set "SERVICE_NAME=KoboldCPP"

set "MODEL_BF16=Qwythos-9B-Claude-Mythos-5-1M-BF16.gguf"
set "MODEL_Q8=Qwythos-9B-Claude-Mythos-5-1M-Q8_0.gguf"
set "MMPROJ_FILE=mmproj-Qwythos-9B-Claude-Mythos-5-1M-F16.gguf"

REM --- nssm: из scripts\bin (Portable-сборка), при отсутствии — из data\hermes\bin ---
set "NSSM_EXE=%HERMES_HOME%\bin\nssm.exe"
if not exist "%NSSM_EXE%" if exist "%SCRIPTS_DIR%\bin\nssm.exe" copy /y "%SCRIPTS_DIR%\bin\nssm.exe" "%NSSM_EXE%" >nul 2>&1

REM ============================================================================
REM   Статус службы
REM ============================================================================
:status
set "SERVICE_INSTALLED=0"
sc query "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 set "SERVICE_INSTALLED=1"

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
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                   Hermes%ESC%[0m — %ESC%[1;33mСлужба KoboldCPP%ESC%[0m                     %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
if !SERVICE_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m Служба %ESC%[1m%SERVICE_NAME%%ESC%[0m — установлена
) else (
    echo   %ESC%[1;33m. %ESC%[0m Служба %ESC%[1m%SERVICE_NAME%%ESC%[0m — не установлена
)
if defined MODEL_FILE (
    echo   %ESC%[2m       Модель: %MODEL_FILE% ^(порт %KCPP_PORT%^)%ESC%[0m
) else (
    echo   %ESC%[1;33m. %ESC%[0m Модель не установлена — сначала установите KoboldCPP ^(меню [1]^)
)
echo.
if !SERVICE_INSTALLED! equ 1 (
    echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУдалить службу %SERVICE_NAME%%ESC%[0m
    echo       %ESC%[2mОстановка и удаление службы ^(файлы KoboldCPP сохраняются^)%ESC%[0m
) else (
    echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановить службу %SERVICE_NAME%%ESC%[0m
    echo       %ESC%[2mАвтозапуск KoboldCPP при старте Windows ^(порт %KCPP_PORT%^)%ESC%[0m
)
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в меню «Расширения и плагины»%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-1): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" goto exit
if "%choice%"=="1" (
    if !SERVICE_INSTALLED! equ 1 goto remove_service
    goto install_service
)
goto menu

REM ============================================================================
REM   Установка службы
REM ============================================================================
:install_service
cls
echo.
echo %ESC%[1;33m-%ESC%[0m %ESC%[1mУстановка службы %SERVICE_NAME%...%ESC%[0m
echo.

if not exist "%NSSM_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] nssm.exe не найден.%ESC%[0m
    echo   %ESC%[33mСначала установите Hermes ^(служба^) или положите nssm.exe в %SCRIPTS_DIR%\bin\%ESC%[0m
    pause
    goto menu
)
if not exist "%KCPP_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] KoboldCPP не установлен.%ESC%[0m
    echo   %ESC%[33mСначала установите его через меню «Расширения и плагины» → [1] KoboldCPP.%ESC%[0m
    pause
    goto menu
)
if not defined MODEL_FILE (
    echo   %ESC%[1;31m[ОШИБКА] Модель не установлена.%ESC%[0m
    pause
    goto menu
)

echo   %ESC%[2m  Исполняемый: %KCPP_EXE%%ESC%[0m
echo   %ESC%[2m  Модель:      %MODEL_FILE%%ESC%[0m
echo   %ESC%[2m  Проектор:    %MMPROJ_FILE%%ESC%[0m
echo   %ESC%[2m  Порт:        %KCPP_PORT%%ESC%[0m
echo.

"%NSSM_EXE%" install "%SERVICE_NAME%" "%KCPP_EXE%" --model "%MODELS_DIR%\%MODEL_FILE%" --mmproj "%MODELS_DIR%\%MMPROJ_FILE%" --gpulayers 999 --contextsize 65536 --defaultgenamt 4096 --batchsize 2048 --flashattention --host 0.0.0.0 --port %KCPP_PORT%
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] nssm install не удался.%ESC%[0m
    pause
    goto menu
)

"%NSSM_EXE%" set "%SERVICE_NAME%" AppDirectory "%KCPP_DIR%" >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppStdout "%TEMP%\kobold-service.out.log" >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppStderr "%TEMP%\kobold-service.err.log" >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppRotateFiles 1 >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppRotateBytes 10485760 >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" Start SERVICE_AUTO_START >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppExit Default Restart >nul 2>&1

"%NSSM_EXE%" start "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[1;33m  .   Служба установлена, но не запустилась — проверьте %TEMP%\kobold-service.err.log%ESC%[0m
) else (
    echo   %ESC%[1;32m+ %ESC%[0m Служба %SERVICE_NAME% установлена и запущена.
)
echo   %ESC%[2m  API: http://127.0.0.1:%KCPP_PORT%/v1%ESC%[0m
echo.
pause
goto status

REM ============================================================================
REM   Удаление службы
REM ============================================================================
:remove_service
cls
echo.
echo %ESC%[1;33m-%ESC%[0m %ESC%[1mУдаление службы %SERVICE_NAME%...%ESC%[0m
echo.
set "confirm="
set /p "confirm=%ESC%[33m  Удалить службу %SERVICE_NAME% (y/N)? %ESC%[0m"
if /i not "%confirm%"=="y" goto menu

"%NSSM_EXE%" stop "%SERVICE_NAME%" >nul 2>&1
"%NSSM_EXE%" remove "%SERVICE_NAME%" confirm >nul 2>&1
if errorlevel 1 (
    sc stop "%SERVICE_NAME%" >nul 2>&1
    sc delete "%SERVICE_NAME%" >nul 2>&1
)
sc query "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[1;32m+ %ESC%[0m Служба %SERVICE_NAME% удалена.
) else (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось удалить службу — попробуйте от администратора.%ESC%[0m
)
echo.
pause
goto status

:exit
exit /b 0
