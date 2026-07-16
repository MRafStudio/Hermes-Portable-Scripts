@REM scripts\Download-Electron.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Параметры: 1 = AUTOCLOSE (не ждать нажатия клавиши)
REM ============================================================================
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

REM ============================================================================
REM   Пути
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "REPO_DIR=%ROOT_DIR%\data\hermes\hermes-agent"
set "DESKTOP_PACKAGE=%REPO_DIR%\apps\desktop\package.json"

REM ============================================================================
REM   Парсим версию Electron из apps/desktop/package.json
REM ============================================================================
if not exist "%DESKTOP_PACKAGE%" (
    echo [ERROR] Не найден %DESKTOP_PACKAGE%
    echo [INFO] Используем fallback-версию 40.10.2
    set "ELECTRON_VERSION=40.10.2"
    goto :version_parsed
)

echo [INFO] Парсим версию Electron из %DESKTOP_PACKAGE%...

set "ELECTRON_VERSION="
for /f "tokens=*" %%a in ('type "%DESKTOP_PACKAGE%" ^| findstr /C:"\"electron\":"') do (
    set "LINE=%%a"
    set "LINE=!LINE:*"electron":=!"
    set "LINE=!LINE: =!"
    set "LINE=!LINE:"=!"
    set "LINE=!LINE:,=!"
    set "ELECTRON_VERSION=!LINE!"
)

if not defined ELECTRON_VERSION (
    echo [WARN] Не удалось распарсить версию. Используем fallback 40.10.2
    set "ELECTRON_VERSION=40.10.2"
) else (
    echo [OK] Найдена версия Electron: !ELECTRON_VERSION!
)

:version_parsed

REM ============================================================================
REM   Настройки скачивания
REM ============================================================================
set "ELECTRON_PLATFORM=win32-x64"
set "ELECTRON_ZIP=electron-v%ELECTRON_VERSION%-%ELECTRON_PLATFORM%.zip"
set "ELECTRON_URL=https://github.com/electron/electron/releases/download/v%ELECTRON_VERSION%/%ELECTRON_ZIP%"

REM ============================================================================
REM   Пути кэша
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "ELECTRON_CACHE=%DATA_DIR%\electron-cache"
set "ELECTRON_ZIP_PATH=%ELECTRON_CACHE%\%ELECTRON_ZIP%"

REM ============================================================================
REM   Проверяем, не скачан ли уже
REM ============================================================================
if exist "%ELECTRON_ZIP_PATH%" (
    echo [INFO] Electron уже скачан: %ELECTRON_ZIP_PATH%
    goto :verify
)

REM ============================================================================
REM   Создаём каталог кэша
REM ============================================================================
if not exist "%ELECTRON_CACHE%" mkdir "%ELECTRON_CACHE%" 2>nul

REM ============================================================================
REM   Скачиваем через curl
REM ============================================================================
echo [INFO] Скачивание Electron %ELECTRON_VERSION%...
echo [INFO] URL: %ELECTRON_URL%

curl -L -o "%ELECTRON_ZIP_PATH%" "%ELECTRON_URL%" --progress-bar

if !errorlevel! neq 0 (
    echo [ERROR] Не удалось скачать Electron!
    echo [INFO] Попробуйте зеркало:
    echo        https://npmmirror.com/mirrors/electron/%ELECTRON_VERSION%/%ELECTRON_ZIP%
	pause
    exit /b 1
)

:verify
echo [OK] Electron скачан: %ELECTRON_ZIP_PATH%
echo [INFO] Размер:
dir "%ELECTRON_ZIP_PATH%" | findstr /C:"%ELECTRON_ZIP%"

REM ============================================================================
REM   Копируем в npm-кэш Electron (чтобы npm не перекачивал)
REM ============================================================================
set "NPM_ELECTRON_CACHE=%LOCALAPPDATA%\electron\Cache"
if not exist "%NPM_ELECTRON_CACHE%" mkdir "%NPM_ELECTRON_CACHE%" 2>nul

echo [INFO] Копирование в npm-кэш: %NPM_ELECTRON_CACHE%
copy /y "%ELECTRON_ZIP_PATH%" "%NPM_ELECTRON_CACHE%\%ELECTRON_ZIP%" >nul

REM ============================================================================
REM   Создаём SHASUMS256.txt (npm проверяет его)
REM ============================================================================
echo [INFO] Создание SHASUMS256.txt...
certutil -hashfile "%ELECTRON_ZIP_PATH%" SHA256 > "%TEMP%\hash.txt" 2>nul
for /f "skip=1 tokens=*" %%a in ('type "%TEMP%\hash.txt"') do (
    set "HASH=%%a"
    set "HASH=!HASH: =!"
    if not defined HASH_SET (
        echo !HASH!  %ELECTRON_ZIP% > "%NPM_ELECTRON_CACHE%\SHASUMS256.txt-%ELECTRON_VERSION%"
        set "HASH_SET=1"
    )
)
del "%TEMP%\hash.txt" 2>nul

echo [OK] Готово! npm теперь найдёт Electron в кэше.

REM ============================================================================
REM   ВЫХОД
REM ============================================================================
if "%AUTOCLOSE%"=="1" (
    exit /b 0
) else (
    pause
    exit /b 0
)