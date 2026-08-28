@REM scripts\InstallOrUpdate-Plugins.bat — Расширения и плагины Hermes Portable
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Расширения и плагины

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DATA_DIR=%ROOT_DIR%\data"
set "PY=%HERMES_HOME%\hermes-agent\venv\Scripts\python.exe"

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
REM   Получение ESC (стандартный трюк, без PowerShell)
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM Куда возвращаться после пересчёта статусов: menu (главное) или llama_menu (подменю Llama)
set "RETURN_MENU=menu"

REM ============================================================================
REM   Параметры плагинов
REM ============================================================================
set "LLAMA_MANAGER_DIR=%DATA_DIR%\llama-manager"
set "LLAMA_MANAGER_EXE=%LLAMA_MANAGER_DIR%\LlamaCppWindowsManager.exe"
set "HEADROOM_DIR=%DATA_DIR%\HeadRoom"
set "HEADROOM_EXE=%HEADROOM_DIR%\.venv\Scripts\headroom.exe"

REM ============================================================================
REM   Статусы плагинов
REM ============================================================================
REM   CRLF-нормализация .bat (ОБЯЗАТЕЛЬНО для Windows! после git pull/write_file
REM   .bat могут получить LF - cmd ломается: 'VERSION' is not recognized!)
REM ============================================================================
if exist "%PY%" (
    "%PY%" "%SCRIPTS_DIR%\py\normalize_crlf.py" "%ROOT_DIR%"
    if !errorlevel! equ 0 (
        echo %ESC%[1;32m  +   CRLF: все .bat в порядке ^(Windows-формат^)!%ESC%[0m
    ) else (
        echo %ESC%[1;33m  .   CRLF: файлы с LF найдены - исправьте или повторите.%ESC%[0m
    )
)

:status
set "LLAMA_MANAGER_INSTALLED=0"
if exist "%LLAMA_MANAGER_EXE%" set "LLAMA_MANAGER_INSTALLED=1"

REM Версия менеджера — из метаданных exe (запускать GUI для --version нельзя!)
set "LLAMA_MANAGER_VER=?"
if exist "%LLAMA_MANAGER_EXE%" (
    for /f "delims=" %%v in ('powershell -NoProfile -NonInteractive -Command "(Get-Item -LiteralPath '%LLAMA_MANAGER_EXE%').VersionInfo.FileVersion" 2^>nul') do set "LLAMA_MANAGER_VER=%%v"
)

REM Статус HeadRoom
set "HEADROOM_INSTALLED=0"
set "HEADROOM_VER=?"
if exist "%HEADROOM_EXE%" (
    set "HEADROOM_INSTALLED=1"
    for /f "delims=" %%v in ('"%HEADROOM_EXE%" --version 2^>nul') do set "HEADROOM_VER=%%v"
)

set "MEMOS_INSTALLED=0"
set "MEMOS_VERSION=?"
if exist "%HERMES_HOME%\memos-plugin\package.json" (
    set "MEMOS_INSTALLED=1"
    for /f "usebackq tokens=2 delims=:, " %%v in (`findstr /c:"\"version\"" "%HERMES_HOME%\memos-plugin\package.json"`) do (
        set "MEMOS_VERSION=%%v"
        set "MEMOS_VERSION=!MEMOS_VERSION:"=!"
    )
)

REM Возврат: в главное меню расширений или в подменю Llama
goto %RETURN_MENU%

REM ============================================================================
REM   Меню
REM ============================================================================
:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                         Hermes%ESC%[0m — %ESC%[1;33mРасширения и плагины%ESC%[0m                     %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
if !LLAMA_MANAGER_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m LlamaCppWindowsManager %ESC%[2m^(v!LLAMA_MANAGER_VER!^)%ESC%[0m — локальный сервер LLM
) else (
    echo   %ESC%[1;33m. %ESC%[0m LlamaCppWindowsManager — не установлен
)
if !MEMOS_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m MemOS %ESC%[2m^(v!MEMOS_VERSION!^)%ESC%[0m — память агента: установлен
) else (
    echo   %ESC%[1;33m. %ESC%[0m MemOS — память агента: не установлен
)
if !HEADROOM_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m HeadRoom %ESC%[2m^(v!HEADROOM_VER!^)%ESC%[0m — прокси сжатия контекста
) else (
    echo   %ESC%[1;33m. %ESC%[0m HeadRoom — прокси сжатия контекста: не установлен
)
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mLlamaCppWindowsManager — локальный сервер LLM%ESC%[0m
echo       %ESC%[2mУстановка/обновление, модели, служба — через менеджер%ESC%[0m
echo.
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mMemOS — память агента%ESC%[0m
if !MEMOS_INSTALLED! equ 1 (
    echo       %ESC%[2mОбновить до актуальной версии из npm ^(настройки сохраняются^)%ESC%[0m
) else (
    echo       %ESC%[2mУстановить: L1/L2/L3 память, гибридный поиск, viewer :18800%ESC%[0m
)
echo.
echo   %ESC%[1;37m[3]%ESC%[0m %ESC%[1mHeadRoom — прокси сжатия контекста%ESC%[0m
echo       %ESC%[2mСжатие контекста до LLM: экономия токенов ^(служба :8787^)%ESC%[0m
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-3): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" goto exit
if "%choice%"=="1" goto llama_menu
if "%choice%"=="2" goto install_memos
if "%choice%"=="3" goto install_headroom
goto menu


REM ============================================================================
REM   [1] LlamaCppWindowsManager — установка / обновление
REM   Скачивание последнего релиза (zip) и распаковка в data\llama-manager
REM ============================================================================
:install_llama
set "RETURN_MENU=llama_menu"
call "%SCRIPTS_DIR%\Backup-Now.bat"

set "LLM_REPO=MRafStudio/llama-cpp-windows-manager"
set "LLM_ZIP=%TEMP%\LlamaCppWindowsManager-win-x64.zip"
set "LLM_ZIP_URL=https://github.com/%LLM_REPO%/releases/latest/download/LlamaCppWindowsManager-win-x64.zip"
set "LLM_UNPACK=%TEMP%\llwm-update"

REM Менеджер запущен — закрываем (иначе файлы заблокированы для замены)
tasklist /FI "IMAGENAME eq LlamaCppWindowsManager.exe" 2>nul | find /i "LlamaCppWindowsManager.exe" >nul
if not errorlevel 1 (
    echo   %ESC%[1;33m  LlamaCppWindowsManager запущен — закрываю...%ESC%[0m
    taskkill /IM LlamaCppWindowsManager.exe /F >nul 2>&1
)

if exist "%LLM_ZIP%" del /q "%LLM_ZIP%" 2>nul
if exist "%LLM_UNPACK%" rmdir /s /q "%LLM_UNPACK%" 2>nul
mkdir "%LLM_UNPACK%" 2>nul

call :download "%LLM_ZIP_URL%" "%LLM_ZIP%" "LlamaCppWindowsManager-win-x64.zip"
if errorlevel 1 goto install_fail

REM --- распаковка в temp, затем перенос в data\llama-manager ---
set "SEVENZIP="
if exist "%ProgramFiles%\7-Zip\7z.exe" set "SEVENZIP=%ProgramFiles%\7-Zip\7z.exe"
if not defined SEVENZIP if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" set "SEVENZIP=%ProgramFiles(x86)%\7-Zip\7z.exe"
echo   %ESC%[2m  Распаковка...%ESC%[0m
call :unzip "%LLM_ZIP%" "%LLM_UNPACK%"
if errorlevel 1 goto install_fail

if not exist "%LLM_UNPACK%\LlamaCppWindowsManager.exe" (
    echo   %ESC%[1;31m[ОШИБКА] LlamaCppWindowsManager.exe не найден после распаковки%ESC%[0m
    goto install_fail
)

if not exist "%LLAMA_MANAGER_DIR%" mkdir "%LLAMA_MANAGER_DIR%" 2>nul
xcopy /e /y /q "%LLM_UNPACK%\*" "%LLAMA_MANAGER_DIR%\" >nul 2>&1
rmdir /s /q "%LLM_UNPACK%" 2>nul
del /q "%LLM_ZIP%" 2>nul

echo %ESC%[1;32m+ %ESC%[0m LlamaCppWindowsManager: установлен в %LLAMA_MANAGER_DIR%
echo %ESC%[2m  Запуск: [3] «Запустить LlamaCppWindowsManager»%ESC%[0m
echo.
pause
goto status

:install_fail
echo   %ESC%[1;31m[ОШИБКА] Установка LlamaCppWindowsManager прервана.%ESC%[0m
if exist "%LLM_UNPACK%" rmdir /s /q "%LLM_UNPACK%" 2>nul
pause
goto status

REM ============================================================================
REM   :download URL FILE NAME — скачивание: напрямую -> прокси 10809 -> PowerShell
REM ============================================================================
:download
set "DL_URL=%~1"
set "DL_FILE=%~2"
set "DL_NAME=%~3"
if exist "%DL_FILE%" del "%DL_FILE%" 2>nul
set "CURL="
if exist "%SYSTEMROOT%\System32\curl.exe" set "CURL=%SYSTEMROOT%\System32\curl.exe"
if not defined CURL for /f "delims=" %%c in ('where curl 2^>nul') do if not defined CURL set "CURL=%%c"
echo   %ESC%[2m  Загрузка %DL_NAME% ...%ESC%[0m
REM сначала напрямую
"%CURL%" -L --fail --noproxy "*" -C - -o "%DL_FILE%" "%DL_URL%"
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m  Напрямую не вышло - пробуем через прокси 10809...%ESC%[0m
    "%CURL%" -L --fail -x "http://127.0.0.1:10809" -C - --retry 8 --retry-delay 3 --retry-all-errors -o "%DL_FILE%" "%DL_URL%"
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;33m  Прокси не помог - переключение на PowerShell...%ESC%[0m
    powershell -NoProfile -NonInteractive -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; try { Invoke-WebRequest -Uri '%DL_URL%' -OutFile '%DL_FILE%' -UseBasicParsing -TimeoutSec 600 } catch { exit 1 }"
)
if not exist "%DL_FILE%" (
    echo   %ESC%[1;31m[ОШИБКА] Загрузка не удалась: %DL_NAME%%ESC%[0m
    echo   %ESC%[33mURL: %DL_URL%%ESC%[0m
    exit /b 1
)
echo   %ESC%[1;32m  OK: %DL_NAME%%ESC%[0m
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

REM ============================================================================
REM   [2] Модели — загрузка и назначение дефолтной
REM ============================================================================
:install_models
set "RETURN_MENU=llama_menu"
call "%SCRIPTS_DIR%\Backup-Now.bat"
call "%SCRIPTS_DIR%\InstallOrUpdate-Models.bat"
goto status

REM ============================================================================
REM   [3] Запуск LlamaCppWindowsManager
REM   Установка сервера llama, моделей и службы — внутри менеджера
REM ============================================================================
:launch_manager
set "RETURN_MENU=llama_menu"
if not exist "%LLAMA_MANAGER_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] LlamaCppWindowsManager не установлен.%ESC%[0m
    echo   %ESC%[33mСначала установите его через [1] «Установка/обновление».%ESC%[0m
    pause
    goto llama_menu
)
start "" "%LLAMA_MANAGER_EXE%"
goto status

REM ============================================================================
REM   [4] MemOS — установка / обновление / проверка (отдельный скрипт)
REM ============================================================================
:install_memos
set "RETURN_MENU=menu"
call "%SCRIPTS_DIR%\Backup-Now.bat"
call "%SCRIPTS_DIR%\InstallOrUpdate-Memos.bat"
goto status

REM ============================================================================
REM   [3] HeadRoom — прокси сжатия контекста (отдельный скрипт)
REM ============================================================================
:install_headroom
set "RETURN_MENU=menu"
call "%SCRIPTS_DIR%\InstallOrUpdate-HeadRoom.bat"
goto status

REM ============================================================================
REM   Llama — подменю: установка/обновление, модели, служба
REM ============================================================================
:llama_menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                         Llama%ESC%[0m — %ESC%[1;33mлокальный сервер LLM%ESC%[0m                      %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mLlamaCppWindowsManager — установка/обновление%ESC%[0m
echo       %ESC%[2mСкачивание последнего релиза, распаковка в data\llama-manager%ESC%[0m
echo.
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mЗагрузка и назначение дефолтных моделей%ESC%[0m
echo       %ESC%[2mУстановленные модели, назначение дефолтной, переключение Hermes%ESC%[0m
echo.
echo   %ESC%[1;37m[3]%ESC%[0m %ESC%[1mЗапустить LlamaCppWindowsManager%ESC%[0m
echo       %ESC%[2mУстановка сервера llama, моделей и службы — через менеджер%ESC%[0m
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в меню расширений%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-3): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" goto menu
if "%choice%"=="1" goto install_llama
if "%choice%"=="2" goto install_models
if "%choice%"=="3" goto launch_manager
goto llama_menu

:exit
exit /b 0
