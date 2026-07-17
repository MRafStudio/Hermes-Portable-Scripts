@REM scripts\InstallOrUpdate-Repo.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Клонирование репозитория

REM ============================================================================
REM   Определение путей
REM   Node.js здесь не используется — только git
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%HOME%\Desktop" mkdir "%HOME%\Desktop" 2>nul
if not exist "%HERMES_HOME%" mkdir "%HERMES_HOME%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Проверка глобального Git (ОБЯЗАТЕЛЬНО!)
REM   Сначала — как есть, затем fallback на стандартный путь установки
REM ============================================================================
git --version >nul 2>nul
if !errorlevel! neq 0 (
    if exist "%ProgramFiles%\Git\cmd\git.exe" (
        set "PATH=%ProgramFiles%\Git\cmd;!PATH!"
        git --version >nul 2>nul
    )
)

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Git не найден в системе.%ESC%[0m
    echo   %ESC%[33m       Скачайте и установите Git for Windows:%ESC%[0m
    echo   %ESC%[33m       https://git-scm.com/download/win%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m              %ESC%[1;37mHermes Portable%ESC%[0m   %ESC%[1;33m—%ESC%[0m   %ESC%[1;33mКлонирование репозитория%ESC%[0m                %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Развилка: репозиторий есть и ВАЛИДНЫЙ или нет
REM ============================================================================
set "REPO_VALID=0"
if exist "%REPO_DIR%\.git" (
    cd /d "%REPO_DIR%" 2>nul
    if !errorlevel! equ 0 (
        git rev-parse --is-inside-work-tree >nul 2>nul
        if !errorlevel! equ 0 (
            git rev-parse --verify HEAD >nul 2>nul
            if !errorlevel! equ 0 (
                set "REPO_VALID=1"
            )
        )
    )
    cd /d "%ROOT_DIR%" 2>nul
)

if "%REPO_VALID%"=="1" goto update_repo
goto clone_repo

REM ============================================================================
REM   БЫСТРОЕ ОБНОВЛЕНИЕ: fetch + reset --hard + clean -fd
REM   Трафик — только новые коммиты. RU-патчи сбрасываются (наложатся позже).
REM   venv и node_modules НЕ трогаем (clean без -x бережёт .gitignore).
REM ============================================================================
:update_repo
echo   %ESC%[1;33m  .   Репозиторий найден. Быстрое обновление до origin/main...%ESC%[0m
echo   %ESC%[2m       RU-патчи будут сброшены — наложатся позже другими скриптами.%ESC%[0m
echo.

cd /d "%REPO_DIR%"

REM --- ШАГ 1: Получаем обновления (только дельта) ---
echo   %ESC%[1;33m[1/3]%ESC%[0m %ESC%[1mПолучение обновлений из origin...%ESC%[0m
git fetch origin main
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  ⚠    fetch не удался. Переходим к полному клонированию...%ESC%[0m
    cd /d "%ROOT_DIR%"
    goto clone_repo
)
echo   %ESC%[1;32m  +   Обновления получены ^(только изменения^).%ESC%[0m

REM --- ШАГ 2: Полный сброс к origin/main + чистка мусора ---
echo.
echo   %ESC%[1;33m[2/3]%ESC%[0m %ESC%[1mСброс к чистому origin/main...%ESC%[0m
git reset --hard origin/main
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  ⚠    reset не удался. Переходим к полному клонированию...%ESC%[0m
    cd /d "%ROOT_DIR%"
    goto clone_repo
)

git clean -fd >nul 2>&1
echo   %ESC%[1;32m  +   Репозиторий приведён к чистому origin/main.%ESC%[0m

REM --- ШАГ 3: Проверка результата ---
echo.
echo   %ESC%[1;33m[3/3]%ESC%[0m %ESC%[1mПроверка результата...%ESC%[0m

for /f "tokens=*" %%a in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%a"
echo   %ESC%[1;32m  +   Текущая ветка: !CURRENT_BRANCH!%ESC%[0m

echo.
echo  %ESC%[1;36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mРепозиторий обновлён до origin/main.%ESC%[0m
echo   %ESC%[2m       Трафик: только новые коммиты.%ESC%[0m
echo   %ESC%[2m       RU-патчи наложатся следующими шагами.%ESC%[0m
echo  %ESC%[1;36m--------------------------------------------------------------------------------%ESC%[0m

goto success_exit

REM ============================================================================
REM   ПОЛНОЕ КЛОНИРОВАНИЕ (с нуля или как fallback при сломанном git)
REM ============================================================================
:clone_repo
echo.
echo   %ESC%[1;33m  .   Полное клонирование с GitHub...%ESC%[0m
echo.

REM --- ШАГ 1: Полная очистка старого репозитория ---
echo   %ESC%[1;33m[1/3]%ESC%[0m %ESC%[1mОчистка каталога репозитория...%ESC%[0m

if exist "%REPO_DIR%" rmdir /s /q "%REPO_DIR%"
mkdir "%REPO_DIR%" 2>nul

echo   %ESC%[1;32m  +   Каталог подготовлен.%ESC%[0m

REM --- ШАГ 2: Клонирование ---
echo.
echo   %ESC%[1;33m[2/3]%ESC%[0m %ESC%[1mКлонирование NousResearch/hermes-agent...%ESC%[0m
echo   %ESC%[2m       Ветка: main%ESC%[0m
echo   %ESC%[2m       ~70 МБ ^(исходный код^)%ESC%[0m

git clone --depth 1 --branch main https://github.com/NousResearch/hermes-agent.git "%REPO_DIR%"
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось клонировать репозиторий.%ESC%[0m
    echo   %ESC%[33m       Проверьте соединение ^(возможно, нужен VPN^).%ESC%[0m
    goto error_exit
)

echo   %ESC%[1;32m  +   Репозиторий клонирован.%ESC%[0m

REM --- ШАГ 3: Проверка результата ---
echo.
echo   %ESC%[1;33m[3/3]%ESC%[0m %ESC%[1mПроверка результата...%ESC%[0m

cd /d "%REPO_DIR%"

for /f "tokens=*" %%a in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%a"
echo   %ESC%[1;32m  +   Текущая ветка: !CURRENT_BRANCH!%ESC%[0m
echo   %ESC%[2m       origin:  https://github.com/NousResearch/hermes-agent.git%ESC%[0m

echo.
echo  %ESC%[1;36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mРепозиторий готов.%ESC%[0m
echo   %ESC%[2m       Чистое состояние с GitHub — RU-патчи наложатся следующими шагами.%ESC%[0m
echo  %ESC%[1;36m--------------------------------------------------------------------------------%ESC%[0m

goto success_exit

REM ============================================================================
REM   ВЫХОДЫ
REM ============================================================================
:error_exit
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 1

:success_exit
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0