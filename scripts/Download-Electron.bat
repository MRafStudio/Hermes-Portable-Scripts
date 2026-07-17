@REM scripts\Download-Electron.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Параметры: 1 = AUTOCLOSE (не ждать нажатия клавиши)
REM ============================================================================
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Hermes Portable — Загрузка Electron

REM ============================================================================
REM   Пути
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "REPO_DIR=%ROOT_DIR%\data\hermes\hermes-agent"
set "DESKTOP_PACKAGE=%REPO_DIR%\apps\desktop\package.json"

REM ============================================================================
REM   Изоляция данных (как в остальных скриптах!)
REM   Иначе при автономном запуске кэш уйдёт в реальный профиль пользователя
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

echo.
echo  %ESC%[1;36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1mЗагрузка Electron для offline-кэша npm%ESC%[0m
echo  %ESC%[1;36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo.

REM ============================================================================
REM   Парсим версию Electron из apps/desktop/package.json
REM ============================================================================
if not exist "%DESKTOP_PACKAGE%" (
    echo   %ESC%[1;31m[ОШИБКА] Не найден %DESKTOP_PACKAGE%%ESC%[0m
    echo   %ESC%[1;33m  .   Используем fallback-версию 40.10.2%ESC%[0m
    set "ELECTRON_VERSION=40.10.2"
    goto :version_parsed
)

echo   %ESC%[2mПарсим версию Electron из apps\desktop\package.json...%ESC%[0m

set "ELECTRON_VERSION="
for /f "tokens=*" %%a in ('type "%DESKTOP_PACKAGE%" ^| findstr /C:"\"electron\":"') do (
    set "LINE=%%a"
    set "LINE=!LINE:*"electron":=!"
    set "LINE=!LINE: =!"
    set "LINE=!LINE:"=!"
    set "LINE=!LINE:,=!"
    set "LINE=!LINE:^=!"
    set "LINE=!LINE:~=!"
    set "ELECTRON_VERSION=!LINE!"
)

if not defined ELECTRON_VERSION (
    echo   %ESC%[1;33m  .   Не удалось распарсить версию. Используем fallback 40.10.2%ESC%[0m
    set "ELECTRON_VERSION=40.10.2"
) else (
    echo   %ESC%[1;32m  +   Найдена версия Electron: !ELECTRON_VERSION!%ESC%[0m
)

:version_parsed

REM ============================================================================
REM   Настройки скачивания
REM ============================================================================
set "ELECTRON_PLATFORM=win32-x64"
set "ELECTRON_ZIP=electron-v%ELECTRON_VERSION%-%ELECTRON_PLATFORM%.zip"
set "ELECTRON_URL=https://github.com/electron/electron/releases/download/v%ELECTRON_VERSION%/%ELECTRON_ZIP%"
set "ELECTRON_MIRROR_URL=https://npmmirror.com/mirrors/electron/%ELECTRON_VERSION%/%ELECTRON_ZIP%"

REM ============================================================================
REM   Пути кэша (изолированные)
REM ============================================================================
set "ELECTRON_CACHE=%DATA_DIR%\electron-cache"
set "ELECTRON_ZIP_PATH=%ELECTRON_CACHE%\%ELECTRON_ZIP%"

REM ============================================================================
REM   Проверяем, не скачан ли уже
REM ============================================================================
if exist "%ELECTRON_ZIP_PATH%" (
    echo   %ESC%[1;33m  .   Electron уже скачан:%ESC%[0m
    echo   %ESC%[2m       %ELECTRON_ZIP_PATH%%ESC%[0m
    goto :verify
)

REM ============================================================================
REM   Создаём каталог кэша
REM ============================================================================
if not exist "%ELECTRON_CACHE%" mkdir "%ELECTRON_CACHE%" 2>nul

REM ============================================================================
REM   Скачиваем через curl: GitHub → зеркало npmmirror
REM   Флаг -f: 404/500 считаются ошибкой, а не "успешной" страницей
REM ============================================================================
echo   %ESC%[1;33m  →   Скачивание Electron %ELECTRON_VERSION%...%ESC%[0m
echo   %ESC%[2m       %ELECTRON_URL%%ESC%[0m

curl -fSL -o "%ELECTRON_ZIP_PATH%" "%ELECTRON_URL%" --progress-bar

if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  .   GitHub недоступен. Пробуем зеркало npmmirror...%ESC%[0m
    echo   %ESC%[2m       %ELECTRON_MIRROR_URL%%ESC%[0m
    curl -fSL -o "%ELECTRON_ZIP_PATH%" "%ELECTRON_MIRROR_URL%" --progress-bar
)

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось скачать Electron ни с GitHub, ни с зеркала.%ESC%[0m
    echo   %ESC%[33m       Проверьте соединение ^(возможно, нужен VPN^).%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

REM ============================================================================
REM   Проверка размера: 404-страница не должна считаться успехом
REM ============================================================================
for %%A in ("%ELECTRON_ZIP_PATH%") do set "ZIP_SIZE=%%~zA"
if !ZIP_SIZE! lss 10000000 (
    echo   %ESC%[1;31m[ОШИБКА] Скачанный файл подозрительно мал ^(!ZIP_SIZE! байт^).%ESC%[0m
    echo   %ESC%[33m       Вероятно, это страница ошибки, а не архив.%ESC%[0m
    del "%ELECTRON_ZIP_PATH%" 2>nul
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

:verify
echo   %ESC%[1;32m  +   Electron на месте: %ELECTRON_ZIP_PATH%%ESC%[0m

REM ============================================================================
REM   Копируем в npm-кэш Electron (чтобы npm не перекачивал)
REM ============================================================================
set "NPM_ELECTRON_CACHE=%LOCALAPPDATA%\electron\Cache"
if not exist "%NPM_ELECTRON_CACHE%" mkdir "%NPM_ELECTRON_CACHE%" 2>nul

echo   %ESC%[1;33m  →   Копирование в npm-кэш:%ESC%[0m
echo   %ESC%[2m       %NPM_ELECTRON_CACHE%%ESC%[0m
copy /y "%ELECTRON_ZIP_PATH%" "%NPM_ELECTRON_CACHE%\%ELECTRON_ZIP%" >nul

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось скопировать архив в кэш.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

REM ============================================================================
REM   Создаём SHASUMS256.txt-<version> (npm проверяет его)
REM   Официальный формат строки: <sha256> *<filename>
REM ============================================================================
echo   %ESC%[1;33m  →   Создание SHASUMS256.txt-%ELECTRON_VERSION%...%ESC%[0m
certutil -hashfile "%ELECTRON_ZIP_PATH%" SHA256 > "%TEMP%\hash.txt" 2>nul

set "HASH_SET="
for /f "skip=1 tokens=*" %%a in ('type "%TEMP%\hash.txt"') do (
    set "HASH=%%a"
    set "HASH=!HASH: =!"
    if not defined HASH_SET (
        > "%NPM_ELECTRON_CACHE%\SHASUMS256.txt-%ELECTRON_VERSION%" echo !HASH! *%ELECTRON_ZIP%
        set "HASH_SET=1"
    )
)
del "%TEMP%\hash.txt" 2>nul

if not exist "%NPM_ELECTRON_CACHE%\SHASUMS256.txt-%ELECTRON_VERSION%" (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось создать SHASUMS256.txt-%ELECTRON_VERSION%%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

echo   %ESC%[1;32m  +   Готово. npm найдёт Electron в кэше.%ESC%[0m
echo.

REM ============================================================================
REM   ВЫХОД
REM ============================================================================
if "%AUTOCLOSE%"=="1" (
    exit /b 0
) else (
    pause
    exit /b 0
)