@REM scripts\InstallOrUpdate-Desktop.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Параметры
REM   %1 = AUTOCLOSE (0/1) — авто-закрытие после завершения
REM   %2 = SETUP (0/1) — если 1, добавляем -IncludeDesktop к install.ps1
REM ============================================================================
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Установка Hermes Portable

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "NODE_DIR=%HERMES_HOME%\node"

REM ============================================================================
REM   Изоляция данных (ничего в систему!)
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "PYTHONUSERBASE=%DATA_DIR%\python-userbase"
set "PYTHONPATH="
set "PYTHONHOME="
set "PYTHONSTARTUP="
set "PYTHONIOENCODING=utf-8"
set "PIP_CACHE_DIR=%TEMP%\pip-cache"
set "HF_HOME=%DATA_DIR%\huggingface"
set "HF_HUB_DISABLE_SYMLINKS=1"
set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"

REM ============================================================================
REM   Создание директорий
REM ============================================================================
if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%HOME%\Desktop" mkdir "%HOME%\Desktop" 2>nul
if not exist "%PYTHONUSERBASE%" mkdir "%PYTHONUSERBASE%" 2>nul
if not exist "%HF_HOME%" mkdir "%HF_HOME%" 2>nul
if not exist "%PIP_CACHE_DIR%" mkdir "%PIP_CACHE_DIR%" 2>nul
if not exist "%HERMES_HOME%" mkdir "%HERMES_HOME%" 2>nul

REM ============================================================================
REM   ПОЛНАЯ ИЗОЛЯЦИЯ PATH — сразу, до любых операций!
REM ============================================================================
set "PATH=%NODE_DIR%;%HERMES_HOME%\bin;%ProgramFiles%\Git\cmd;%windir%\system32;%windir%;%windir%\System32\Wbem;%windir%\System32\WindowsPowerShell\v1.0"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Проверка глобального Git (ОБЯЗАТЕЛЬНО!)
REM ============================================================================
set "GIT_FOUND=0"
git --version >nul 2>nul
if !errorlevel! equ 0 (
    for /f "tokens=*" %%a in ('git --version 2^>nul') do set "GIT_VER=%%a"
    set "GIT_FOUND=1"
)

if !GIT_FOUND! equ 0 (
    cls
    echo.
    echo %ESC%[1;31m################################################################################%ESC%[0m
    echo %ESC%[1;31m##                                                                            ##%ESC%[0m
    echo %ESC%[1;31m##%ESC%[0m                            %ESC%[1;37mGit не найден в системе%ESC%[0m                         %ESC%[1;31m##%ESC%[0m
    echo %ESC%[1;31m##                                                                            ##%ESC%[0m
    echo %ESC%[1;31m################################################################################%ESC%[0m
    echo.
    echo %ESC%[1;31m[ОШИБКА] Git не установлен или не добавлен в PATH.%ESC%[0m
    echo.
    echo %ESC%[1;33mДля работы со скриптами требуется глобальный Git.%ESC%[0m
    echo.
    echo %ESC%[1;37mСкачайте и установите Git for Windows:%ESC%[0m
    echo %ESC%[1;36mhttps://git-scm.com/download/win%ESC%[0m
    echo.
    echo %ESC%[2mПосле установки перезапустите Start.bat%ESC%[0m
    echo.
    pause
    exit /b 1
)

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m              %ESC%[1;37mHermes Portable%ESC%[0m   —   %ESC%[1;33mУстановка через install.ps1%ESC%[0m             %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 1: Подготовка репозитория (stash → reset → pull)
REM ============================================================================
echo.
echo   %ESC%[1;33m[1/6]%ESC%[0m %ESC%[1mПодготовка репозитория...%ESC%[0m

if exist "%HERMES_HOME%\hermes-agent\.git" (
    cd /d "%HERMES_HOME%\hermes-agent"
    
    REM Сохраняем ВСЁ (включая untracked) в stash
    echo   %ESC%[2m       Сохранение локальных изменений...%ESC%[0m
    git stash push --include-untracked -m "hermes-portable-autostash" >nul 2>&1
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   Локальные изменения сохранены в stash.%ESC%[0m
    ) else (
        echo   %ESC%[2m       Нет локальных изменений для сохранения.%ESC%[0m
    )
    
    REM Сбрасываем к origin/main (чистое состояние)
    echo   %ESC%[2m       Сброс к origin/main...%ESC%[0m
    git fetch origin main >nul 2>&1
    git reset --hard origin/main >nul 2>&1
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   Репозиторий сброшен к origin/main.%ESC%[0m
    ) else (
        echo   %ESC%[1;31m  [ОШИБКА] Не удалось сбросить репозиторий.%ESC%[0m
		echo.
        echo   %ESC%[1;33m  В главном меню выберите %ESC%[2m[3] Инструменты.%ESC%[0m
        echo   %ESC%[1;33m  А затем %ESC%[2m[2] Очистить репозиторий%ESC%[0m
		echo.
        cd /d "%ROOT_DIR%"
        if "%AUTOCLOSE%"=="0" pause
        exit /b 1
    )
    
    cd /d "%ROOT_DIR%"
) else (
    echo   %ESC%[2m       Репозиторий не найден — будет клонирован install.ps1.%ESC%[0m
)

:run_install_ps1
REM ============================================================================
REM   ШАГ 2: Запуск install.ps1
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/6]%ESC%[0m %ESC%[1mЗапуск install.ps1...%ESC%[0m

set "INSTALL_PS1=%SCRIPTS_DIR%\patch\hermes_install_portable.ps1"

if not exist "%INSTALL_PS1%" (
    echo   %ESC%[1;31m[ОШИБКА] %INSTALL_PS1% не найден!%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

if "%SETUP%"=="1" (
    echo   %ESC%[1;33m  →   Режим: со сборкой Desktop%ESC%[0m
    powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_PS1%" -HermesHome "%HERMES_HOME%" -InstallDir "%HERMES_HOME%\hermes-agent" -IncludeDesktop
) else (
    echo   %ESC%[1;33m  →   Режим: без сборки Desktop ^(только repo + deps^)%ESC%[0m
    powershell -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_PS1%" -HermesHome "%HERMES_HOME%" -InstallDir "%HERMES_HOME%\hermes-agent"
)

if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] install.ps1 завершился с ошибкой.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    set "NEEDS_REPO=1"
	goto :check_repo_done
)

echo   %ESC%[1;32m  +   install.ps1 завершён.%ESC%[0m

REM ============================================================================
REM   ШАГ 3: ПРОВЕРКА РЕПОЗИТОРИЯ И ЗАВИСИМОСТЕЙ
REM ============================================================================
echo.
echo   %ESC%[1;33m[3/6]%ESC%[0m %ESC%[1mПроверка состояния репозитория и зависимостей...%ESC%[0m

set "NEEDS_REPO=0"
set "NEEDS_DEPS=0"

REM 1. Проверяем, существует ли каталог репозитория
if not exist "%HERMES_HOME%\hermes-agent" (
    echo   %ESC%[1;31m  [ОШИБКА] Репозиторий не найден!%ESC%[0m
    set "NEEDS_REPO=1"
    goto :check_repo_done
)

REM 2. Проверяем .git
if not exist "%HERMES_HOME%\hermes-agent\.git" (
    echo   %ESC%[1;31m  [ОШИБКА] .git не найден!%ESC%[0m
    set "NEEDS_REPO=1"
    goto :check_repo_done
)

REM 3. Проверяем коммиты (HEAD)
cd /d "%HERMES_HOME%\hermes-agent"
git rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 (
    echo   %ESC%[1;33m  !   Репозиторий без коммитов ^(ZIP-загрузка^).%ESC%[0m
    echo   %ESC%[1;33m  →   Используем GITHUB_SHA для сборки...%ESC%[0m
    set "GITHUB_SHA=0000000000000000000000000000000000000000"
    cd /d "%ROOT_DIR%"
) else (
    echo   %ESC%[1;32m  +   Репозиторий валиден ^(есть коммиты^).%ESC%[0m
    cd /d "%ROOT_DIR%"
)

:check_repo_done
if !NEEDS_REPO! equ 1 (
    echo   %ESC%[1;33m  →   Запускаем InstallOrUpdate-Repo.bat...%ESC%[0m
    call "%SCRIPTS_DIR%\InstallOrUpdate-Repo.bat" 1
    if errorlevel 1 (
        echo   %ESC%[1;31m  [ОШИБКА] Не удалось клонировать репозиторий.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        exit /b 1
    )
    echo   %ESC%[1;32m  +   Репозиторий клонирован. Перезапускаем install.ps1...%ESC%[0m
    goto :step2_install_ps1
)

REM 4. Проверяем Python venv и hermes.exe
if not exist "%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe" (
    echo   %ESC%[1;33m  !   Hermes CLI не найден ^(venv не создан или deps не установлены^).%ESC%[0m
    set "NEEDS_DEPS=1"
)

REM 5. Проверяем browser tools (Playwright)
REM Playwright кладёт бинарники в %LOCALAPPDATA%\ms-playwright\
set "PLAYWRIGHT_OK=0"
if exist "%LOCALAPPDATA%\ms-playwright\chromium-*" set "PLAYWRIGHT_OK=1"
if exist "%LOCALAPPDATA%\ms-playwright\chromium" set "PLAYWRIGHT_OK=1"
if exist "%HERMES_HOME%\hermes-agent\node_modules\playwright\package.json" set "PLAYWRIGHT_OK=1"
if !PLAYWRIGHT_OK! equ 0 (
    echo   %ESC%[1;33m  i   Browser tools ^(Playwright^) не установлены.%ESC%[0m
    set "NEEDS_DEPS=1"
)

REM 6. Проверяем Desktop-зависимости (Electron)
REM Electron может быть в node_modules или в кэше
set "ELECTRON_OK=0"
if exist "%HERMES_HOME%\hermes-agent\apps\desktop\node_modules\electron\package.json" set "ELECTRON_OK=1"
if exist "%LOCALAPPDATA%\electron\Cache" set "ELECTRON_OK=1"
if exist "%HERMES_HOME%\hermes-agent\apps\desktop\node_modules\electron\dist\electron.exe" set "ELECTRON_OK=1"
if !ELECTRON_OK! equ 0 (
    echo   %ESC%[1;33m  i   Desktop-зависимости ^(Electron^) не установлены.%ESC%[0m
    set "NEEDS_DEPS=1"
)

REM 7. Если чего-то не хватает — запускаем InstallOrUpdate-Deps.bat
if !NEEDS_DEPS! equ 1 (
    echo.
    echo   %ESC%[1;33m  →   Запускаем InstallOrUpdate-Deps.bat ^(довершение установки^)...%ESC%[0m
    call "%SCRIPTS_DIR%\InstallOrUpdate-Deps.bat" 1
    if errorlevel 1 (
        echo   %ESC%[1;31m  [ОШИБКА] Не удалось установить зависимости.%ESC%[0m
        if "%AUTOCLOSE%"=="0" pause
        exit /b 1
    )
    echo   %ESC%[1;32m  +   Зависимости установлены.%ESC%[0m
) else (
    echo   %ESC%[1;32m  +   Все зависимости на месте.%ESC%[0m
)

goto :step2_ru

:step2_install_ps1
REM Возвращаемся на ШАГ 2 (перезапуск install.ps1)
echo.
echo   %ESC%[1;33m[2/6 ПОВТОР]%ESC%[0m %ESC%[1mПерезапуск install.ps1...%ESC%[0m
goto :run_install_ps1

:step2_ru
REM ============================================================================
REM   ШАГ 4: Применение RU локализации
REM ============================================================================
echo.
echo   %ESC%[1;33m[4/6]%ESC%[0m %ESC%[1mПрименение RU локализации...%ESC%[0m

call "%SCRIPTS_DIR%\InstallOrUpdate-RU.bat" 1

if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Не удалось применить RU локализацию.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

echo   %ESC%[1;32m  +   RU локализация применена.%ESC%[0m

REM ============================================================================
REM   ШАГ 5: Пересборка Desktop с RU локализацией
REM ============================================================================
echo.
echo   %ESC%[1;33m[5/6]%ESC%[0m %ESC%[1mПересборка Desktop с RU локализацией...%ESC%[0m
echo   %ESC%[2m       Это может занять 1-3 минуты...%ESC%[0m

cd /d "%HERMES_HOME%\hermes-agent"

REM Убедимся, что npm доступен
set "PATH=%HERMES_HOME%\node;%PATH%"

REM Установка npm-зависимостей в корне репо (workspace)
echo   %ESC%[1;33m  .   Установка npm-зависимостей...%ESC%[0m
call "%HERMES_HOME%\node\npm.cmd" install 2>&1
if errorlevel 1 (
    echo   %ESC%[1;31m  [ОШИБКА] Не удалось установить npm-зависимости.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)
echo   %ESC%[1;32m  +   npm-зависимости установлены.%ESC%[0m

REM Добавляем node_modules/.bin в PATH
set "PATH=%HERMES_HOME%\hermes-agent\node_modules\.bin;%PATH%"

cd /d "%HERMES_HOME%\hermes-agent\apps\desktop"

REM Очистка кэша electron-builder для чистой пересборки
if exist "release" rmdir /s /q "release" 2>nul

REM Запускаем сборку
call "%HERMES_HOME%\node\npm.cmd" run pack 2>&1

if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Пересборка Desktop не удалась.%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

echo   %ESC%[1;32m  +   Desktop пересобран с RU локализацией.%ESC%[0m

REM ============================================================================
REM   ШАГ 6: Проверка результата
REM ============================================================================
echo.
echo   %ESC%[1;33m[6/6]%ESC%[0m %ESC%[1mПроверка результата...%ESC%[0m

set "EXE_FOUND=0"
set "EXE_PATH="

for %%P in (
    "%HERMES_HOME%\hermes-agent\apps\desktop\release\win-unpacked\Hermes.exe"
    "%HERMES_HOME%\hermes-agent\apps\desktop\release\win-ia32-unpacked\Hermes.exe"
    "%HERMES_HOME%\hermes-agent\apps\desktop\release\win-arm64-unpacked\Hermes.exe"
    "%HERMES_HOME%\hermes-agent\apps\desktop\release\win-x64-unpacked\Hermes.exe"
) do (
    if exist "%%P" (
        set "EXE_FOUND=1"
        set "EXE_PATH=%%P"
        goto :exe_found
    )
)

:exe_found
if !EXE_FOUND! equ 0 (
    echo   %ESC%[1;31m  -   Hermes.exe не найден после сборки!%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

echo   %ESC%[1;32m  +   Hermes.exe найден:%ESC%[0m
echo   %ESC%[2m       !EXE_PATH!%ESC%[0m

REM ============================================================================
REM   Завершение
REM ============================================================================
echo.
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1;32mУстановка завершена ^(с Desktop + RU^)!%ESC%[0m
echo   %ESC%[2m  Репозиторий: %HERMES_HOME%\hermes-agent\%ESC%[0m
echo   %ESC%[2m  Desktop:     !EXE_PATH!%ESC%[0m
echo   %ESC%[2m  Язык:        Русский доступен в Settings → Appearance%ESC%[0m
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m

if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0