@REM scripts\Llama-Service.bat — установка/удаление службы Llama.cpp (Hermes Portable)
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Llama.cpp — Служба Windows

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "DATA_DIR=%ROOT_DIR%\data"
set "LLAMA_DIR=%DATA_DIR%\llama"
set "LLAMA_EXE=%LLAMA_DIR%\llama-server.exe"
set "MODELS_DIR=%DATA_DIR%\kobold\models"
set "SERVICE_NAME=LlamaCPP"
set "LLAMA_PORT=8080"

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

REM ============================================================================
REM   Получение ESC (стандартный трюк, без PowerShell)
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

set "NSSM_EXE=%ROOT_DIR%\scripts\nssm.exe"

REM ============================================================================
REM   Меню: установка / удаление службы
REM ============================================================================
:menu
cls
echo.
echo %ESC%[1;33m-= Llama.cpp — служба Windows =-%ESC%[0m
echo.
sc query "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 (
    echo %ESC%[1;32m+ %ESC%[0m Служба %SERVICE_NAME% — установлена
) else (
    echo %ESC%[1;33m. %ESC%[0m Служба %SERVICE_NAME% — не установлена
)
echo.
echo   [1] Установить службу %SERVICE_NAME%
echo   [2] Удалить службу %SERVICE_NAME%
echo   [0] Назад
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-2): %ESC%[0m"
if "%choice%"=="1" goto install_service
if "%choice%"=="2" goto uninstall_service
if "%choice%"=="0" goto menu_end
goto menu

REM ============================================================================
REM   Установка службы
REM ============================================================================
:install_service
if not exist "%LLAMA_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] Llama.cpp не установлен.%ESC%[0m
    echo   %ESC%[33mСначала установите его через меню «Расширения и плагины» → [1] Llama.cpp.%ESC%[0m
    pause
    goto menu
)
if not exist "%MODELS_DIR%\Qwen3.6-35B-A3B-UD-IQ4_NL.gguf" (
    echo   %ESC%[1;31m[ОШИБКА] Модель не установлена.%ESC%[0m
    pause
    goto menu
)

echo   %ESC%[2m  Исполняемый: %LLAMA_EXE%%ESC%[0m
echo   %ESC%[2m  Модель:      Qwen3.6-35B-A3B-UD-IQ4_NL.gguf%ESC%[0m
echo   %ESC%[2m  Проектор:    mmproj-35B-F16.gguf%ESC%[0m
echo   %ESC%[2m  Порт:        %LLAMA_PORT%%ESC%[0m
echo.

"%NSSM_EXE%" install "%SERVICE_NAME%" "%LLAMA_EXE%" -m "%MODELS_DIR%\Qwen3.6-35B-A3B-UD-IQ4_NL.gguf" --mmproj "%MODELS_DIR%\mmproj-35B-F16.gguf" --alias llama/Qwen3.6-35B-A3B-UD-IQ4_NL -c 262144 -ngl 999 --flash-attn 1 --port %LLAMA_PORT% --host 127.0.0.1
if errorlevel 1 (
    echo   %ESC%[1;31m[ОШИБКА] nssm install не удался.%ESC%[0m
    pause
    goto menu
)

"%NSSM_EXE%" set "%SERVICE_NAME%" AppDirectory "%LLAMA_DIR%" >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppStdout "%TEMP%\llama-service.out.log" >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppStderr "%TEMP%\llama-service.err.log" >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppRotateFiles 1 >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppRotateBytes 10485760 >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" Start SERVICE_AUTO_START >nul 2>&1
"%NSSM_EXE%" set "%SERVICE_NAME%" AppExit Default Restart >nul 2>&1

"%NSSM_EXE%" start "%SERVICE_NAME%" >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[1;33m  .   Служба установлена, но не запустилась — проверьте %TEMP%\llama-service.err.log%ESC%[0m
) else (
    echo   %ESC%[1;32m+ %ESC%[0m Служба %SERVICE_NAME% установлена и запущена.
)
echo   %ESC%[2m  API: http://127.0.0.1:%LLAMA_PORT%/v1%ESC%[0m
echo.
pause
goto menu

REM ============================================================================
REM   Удаление службы
REM ============================================================================
:uninstall_service
"%NSSM_EXE%" stop "%SERVICE_NAME%" >nul 2>&1
"%NSSM_EXE%" remove "%SERVICE_NAME%" confirm >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[1;33m  .   Служба не найдена или уже удалена.%ESC%[0m
) else (
    echo   %ESC%[1;32m+ %ESC%[0m Служба %SERVICE_NAME% удалена.
)
pause
goto menu

:menu_end
exit /b 0
