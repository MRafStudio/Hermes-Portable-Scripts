@REM scripts\InstallOrUpdate-Llama.bat — llama.cpp server: установка/обновление (Hermes Portable)
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Llama.cpp — Установка / Обновление

REM ============================================================================
REM   Пути
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DATA_DIR=%ROOT_DIR%\data"
set "LLAMA_DIR=%DATA_DIR%\llama"
set "LLM_DIR=%DATA_DIR%\llm"
set "MODELS_DIR=%LLM_DIR%\models"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "HOME=%DATA_DIR%\home"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%LLAMA_DIR%" mkdir "%LLAMA_DIR%" 2>nul
if not exist "%MODELS_DIR%" mkdir "%MODELS_DIR%" 2>nul

REM ============================================================================
REM   ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   curl
REM ============================================================================
set "CURL="
if exist "%SYSTEMROOT%\System32\curl.exe" set "CURL=%SYSTEMROOT%\System32\curl.exe"
if not defined CURL for /f "delims=" %%c in ('where curl 2^>nul') do if not defined CURL set "CURL=%%c"

REM ============================================================================
REM   Прямые ссылки релиза (b10375, CUDA 13.3) — НЕ через GitHub API!
REM   github.com напрямую режется (52) — качаем через прокси 10809.
REM   Прокси нестабилен — на случай обрывов retry-all-errors.
REM ============================================================================
set "PROXY=http://127.0.0.1:10809"
set "LLAMA_URL=https://github.com/ggml-org/llama.cpp/releases/download/b10375/llama-b10375-bin-win-cuda-13.3-x64.zip"
set "CUDART_URL=https://github.com/ggml-org/llama.cpp/releases/download/b10375/cudart-llama-bin-win-cuda-13.3-x64.zip"

REM ============================================================================
REM   Установка движка (уже установлен — пропускаем)
REM ============================================================================
if exist "%LLAMA_DIR%\llama-server.exe" (
    echo.
    echo %ESC%[1;32m+ %ESC%[0m llama.cpp: установлен %ESC%[2m^(%LLAMA_DIR%^)%ESC%[0m
    goto run_info
)

echo.
echo %ESC%[1;33m llama.cpp: скачиваю релиз ^(b10375, CUDA 13.3^)...%ESC%[0m
set "LLAMA_TMP=%TEMP%\llama_setup"
if exist "%LLAMA_TMP%" rmdir /s /q "%LLAMA_TMP%" 2>nul
mkdir "%LLAMA_TMP%" 2>nul

call :download "%LLAMA_URL%" "%LLAMA_TMP%\llama-bin.zip" "llama.cpp (bin)"
if errorlevel 1 goto fail
call :download "%CUDART_URL%" "%LLAMA_TMP%\llama-cudart.zip" "CUDA runtime"
if errorlevel 1 goto fail

REM --- распаковка: 7z (если есть) -> иначе PowerShell Expand-Archive ---
set "SEVENZIP="
if exist "%ProgramFiles%\7-Zip\7z.exe" set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
if not defined SEVENZIP if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" set "SEVENZIP=%ProgramFiles(x86)%\7-Zip\7z.exe"
echo   %ESC%[2m    Распаковка...%ESC%[0m
call :unzip "%LLAMA_TMP%\llama-bin.zip" "%LLAMA_TMP%"
if errorlevel 1 goto fail
call :unzip "%LLAMA_TMP%\llama-cudart.zip" "%LLAMA_TMP%"
if errorlevel 1 goto fail
del "%LLAMA_TMP%\llama-bin.zip" "%LLAMA_TMP%\llama-cudart.zip" 2>nul
REM архив плоский; на всякий случай сдвигаем, если появится вложенная папка
for /d %%D in ("%LLAMA_TMP%\llama-*-bin-*") do (
    move /y "%%D\*" "%LLAMA_TMP%\" >nul 2>&1
    rmdir /q "%%D" 2>nul
)
if not exist "%LLAMA_TMP%\llama-server.exe" (
    echo   %ESC%[1;31m[ОШИБКА] llama-server.exe не найден после распаковки%ESC%[0m
    goto fail
)
move /y "%LLAMA_TMP%\*" "%LLAMA_DIR%\" >nul 2>&1
rmdir /s /q "%LLAMA_TMP%" 2>nul
echo %ESC%[1;32m+ %ESC%[0m llama.cpp: установлен ^(b10375^)

REM ============================================================================
REM   Инфо о запуске
REM ============================================================================
:run_info
if not exist "%LLAMA_DIR%\start_llama.bat" (
    copy /y "%SCRIPTS_DIR%\start_llama.bat" "%LLAMA_DIR%\start_llama.bat" >nul 2>&1
)
echo.
echo %ESC%[1;33m  Запуск:   %ESC%[0m%LLAMA_DIR%\start_llama.bat
echo %ESC%[1;33m  Модель:   %ESC%[0mнужна в %MODELS_DIR% - скажи Hermes, какую качать
echo %ESC%[1;33m  Порт API: %ESC%[0m5505 - Start-Llama-IfNeeded поднимет автоматически
echo.
pause
exit /b 0

:fail
echo   %ESC%[1;31m[ОШИБКА] Установка llama.cpp прервана.%ESC%[0m
if exist "%LLAMA_TMP%" rmdir /s /q "%LLAMA_TMP%" 2>nul
pause
exit /b 1

REM ============================================================================
REM   :download URL FILE NAME — скачивание: напрямую -> прокси -> PowerShell
REM ============================================================================
:download
set "DL_URL=%~1"
set "DL_FILE=%~2"
set "DL_NAME=%~3"
if exist "%DL_FILE%" del "%DL_FILE%" 2>nul
echo   %ESC%[2m    Загрузка %DL_NAME% ...%ESC%[0m
REM сначала напрямую (90% скриптов ходят напрямую!)
"%CURL%" -L --fail --noproxy "*" -C - -# -o "%DL_FILE%" "%DL_URL%"
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m    Напрямую не вышло - пробуем через прокси %PROXY%...%ESC%[0m
    "%CURL%" -L --fail -x "%PROXY%" -C - --retry 8 --retry-delay 3 --retry-all-errors -# -o "%DL_FILE%" "%DL_URL%"
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m    Прокси не помог - переключение на PowerShell...%ESC%[0m
    powershell -NoProfile -NonInteractive -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; try { Invoke-WebRequest -Uri '%DL_URL%' -OutFile '%DL_FILE%' -UseBasicParsing -TimeoutSec 600 } catch { exit 1 }"
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;31m[ОШИБКА] Загрузка не удалась[0m
    echo   %ESC%[33mURL: %DL_URL%%ESC%[0m
    exit /b 1
)
echo   %ESC%[1;32m    OK: %DL_NAME%%ESC%[0m
exit /b 0

REM ============================================================================
REM   :unzip FILE DIR — 7z (если найден) -> иначе PowerShell Expand-Archive
REM ============================================================================
:unzip
if defined SEVENZIP (
    "%SEVENZIP%" x -y -o"%~2" "%~1" >nul 2>&1
    if not errorlevel 1 exit /b 0
)
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%~1' -DestinationPath '%~2' -Force"
if errorlevel 1 exit /b 1
exit /b 0
