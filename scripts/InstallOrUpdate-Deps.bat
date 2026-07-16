@REM scripts\InstallOrUpdate-Deps.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Установка зависимостей

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "UV_DIR=%HERMES_HOME%\bin"
set "UV_EXE=%UV_DIR%\uv.exe"
set "NODE_DIR=%HERMES_HOME%\node"
set "NODE_EXE=%NODE_DIR%\node.exe"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"

set "PYTHON_DIR=%APPDATA%\uv\python\cpython-3.11.15-windows-x86_64-none"
set "PYTHON_EXE=%PYTHON_DIR%\python.exe"

set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "UV_CACHE_DIR=%DATA_DIR%\uv-cache"
set "PIP_CACHE_DIR=%DATA_DIR%\pip-cache"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%UV_CACHE_DIR%" mkdir "%UV_CACHE_DIR%" 2>nul
if not exist "%PIP_CACHE_DIR%" mkdir "%PIP_CACHE_DIR%" 2>nul
if not exist "%HERMES_HOME%" mkdir "%HERMES_HOME%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Проверка компонентов
REM ============================================================================
if not exist "%PYTHON_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] Python не установлен!%ESC%[0m
    goto error_exit
)

if not exist "%UV_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] UV не установлен!%ESC%[0m
    goto error_exit
)

if not exist "%REPO_DIR%\.git" (
    echo   %ESC%[1;31m[ОШИБКА] Репозиторий не клонирован!%ESC%[0m
    goto error_exit
)

REM cls
echo.
echo  %ESC%[1;35m################################################################################%ESC%[0m
echo  %ESC%[1;35m##                                                                            ##%ESC%[0m
echo  %ESC%[1;35m##%ESC%[0m                 %ESC%[1;37mHermes Portable%ESC%[0m   %ESC%[1;33m—%ESC%[0m   %ESC%[1;33mУстановка зависимостей%ESC%[0m               %ESC%[1;35m##%ESC%[0m
echo  %ESC%[1;35m##                                                                            ##%ESC%[0m
echo  %ESC%[1;35m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Добавляем в PATH
REM ============================================================================
set "PATH=%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%UV_DIR%;%NODE_DIR%;%PATH%"

REM ============================================================================
REM   ПРЕДУПРЕЖДЕНИЕ
REM ============================================================================
echo.
echo  %ESC%[1;33m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1;33m⚠  ВНИМАНИЕ: Fallback-установка Hermes%ESC%[0m
echo.
echo   %ESC%[1;37mВы находитесь в ветке fallback-установки.%ESC%[0m
echo   %ESC%[2m   Это связано с ограничениями Роскомнадзора или%ESC%[0m
echo   %ESC%[2m   политикой разработчиков в отношении РФ.%ESC%[0m
echo.
echo   %ESC%[1;36mРекомендация:%ESC%[0m %ESC%[1;37mвключите VPN и попробуйте установку заново.%ESC%[0m
echo   %ESC%[2m   Возможно, что при использовании VPN установка пройдёт без проблем%ESC%[0m
echo   %ESC%[2m   и без fallback на данный скрипт.%ESC%[0m
echo.
echo  %ESC%[1;33m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo.
echo   %ESC%[1;32m[Enter]%ESC%[0m %ESC%[1mПродолжить fallback-установку%ESC%[0m
echo   %ESC%[1;37m[0]%ESC%[0m     %ESC%[1mВыйти, включить VPN и попробовать заново%ESC%[0m
echo.
set "warn_choice="
set /p "warn_choice=%ESC%[33mВыберите действие: %ESC%[0m"

if not defined warn_choice goto :warn_continue
set "warn_choice=%warn_choice: =%"

if "%warn_choice%"=="0" (
    cls
    echo.
    echo  %ESC%[1;33m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
    echo   %ESC%[1;33mУстановка отменена.%ESC%[0m
    echo.
    echo   %ESC%[1;37mДействия:%ESC%[0m
    echo   %ESC%[2m   1. Включите VPN%ESC%[0m
    echo   %ESC%[2m   2. Запустите Start.bat заново%ESC%[0m
    echo   %ESC%[2m   3. Выберите установку компонентов%ESC%[0m
    echo.
    echo   %ESC%[2mПри VPN установка пройдёт в штатном режиме через git clone.%ESC%[0m
    echo  %ESC%[1;33m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
    echo.
    pause
    exit /b 0
)

:warn_continue
REM ============================================================================
REM   ШАГ 1: Создание venv через uv
REM ============================================================================
echo   %ESC%[1;33m[1/5]%ESC%[0m %ESC%[1mСоздание виртуального окружения...%ESC%[0m

cd /d "%REPO_DIR%"

if exist "venv" (
    echo   %ESC%[1;33m  .   venv существует. Пересоздание...%ESC%[0m
    rmdir /s /q "venv" 2>nul
)

REM Создаём с --clear (не спрашивает подтверждение)
"%UV_EXE%" venv --clear --python "%PYTHON_EXE%"

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось создать venv...%ESC%[0m
    cd /d "%ROOT_DIR%"
    goto error_exit
)

echo   %ESC%[1;32m  +   Виртуальное окружение создано.%ESC%[0m

REM ============================================================================
REM   ШАГ 2: Установка зависимостей через uv sync
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/5]%ESC%[0m %ESC%[1mУстановка зависимостей (uv sync --extra all --locked)...%ESC%[0m
echo   %ESC%[2m       Это может занять 5-15 минут...%ESC%[0m

set "UV_PROJECT_ENVIRONMENT=%REPO_DIR%\venv"
"%UV_EXE%" sync --extra all --locked

if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  +   Зависимости установлены ^(hash-verified^).%ESC%[0m
    goto deps_done
)

echo   %ESC%[1;33m  .   uv.lock sync failed, falling back to uv pip install...%ESC%[0m

REM ============================================================================
REM   Fallback: uv pip install
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/5]%ESC%[0m %ESC%[1mFallback: uv pip install -e ".[all]"...%ESC%[0m

"%UV_EXE%" pip install -e ".[all]"

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось установить зависимости!%ESC%[0m
    echo   %ESC%[33m       Попробуйте вручную:%ESC%[0m
    echo   %ESC%[33m       cd %REPO_DIR% ^&^& uv pip install -e ".[all]"%ESC%[0m
    cd /d "%ROOT_DIR%"
    goto error_exit
)

echo   %ESC%[1;32m  +   Зависимости установлены (PyPI resolve).%ESC%[0m

:deps_done

REM ============================================================================
REM   ШАГ 3: Проверка baseline imports
REM ============================================================================
echo.
echo   %ESC%[1;33m[3/5]%ESC%[0m %ESC%[1mПроверка установки...%ESC%[0m

"%REPO_DIR%\venv\Scripts\python.exe" -c "import dotenv, openai, rich, prompt_toolkit" >nul 2>nul
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Baseline imports failed!%ESC%[0m
    echo   %ESC%[33m       Попробуйте: uv sync --extra all --locked%ESC%[0m
    cd /d "%ROOT_DIR%"
    goto error_exit
)

echo   %ESC%[1;32m  +   Baseline imports OK.%ESC%[0m

REM ============================================================================
REM   ШАГ 4: Node.js зависимости (workspace root)
REM ============================================================================
echo.
echo   %ESC%[1;33m[4/5]%ESC%[0m %ESC%[1mУстановка Node.js зависимостей...%ESC%[0m

if not exist "%NODE_EXE%" (
    echo   %ESC%[1;33m  .   Node.js не найден. Пропускаем ^(browser tools будут недоступны^).%ESC%[0m
    goto node_done
)

cd /d "%REPO_DIR%"

if not exist "package.json" (
    echo   %ESC%[1;33m  .   package.json не найден. Пропускаем.%ESC%[0m
    goto node_done
)

echo   %ESC%[1;33m  -   npm install (workspace root)...%ESC%[0m
echo   %ESC%[2m       Это может занять 5-15 минут...%ESC%[0m

:retry_node_deps
call "%NODE_DIR%\npm.cmd" install

if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  +   Node.js зависимости установлены.%ESC%[0m
    goto node_done
)

REM ============================================================================
REM   ПРОВАЛ: npm install упал — пробуем fallback через Download-Electron.bat
REM ============================================================================
echo   %ESC%[1;33m  !   npm install failed. Пробуем скачать Electron вручную...%ESC%[0m

if exist "%SCRIPTS_DIR%\Download-Electron.bat" (
    call "%SCRIPTS_DIR%\Download-Electron.bat"
    
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   Electron скачан вручную. Повторяем npm install...%ESC%[0m
        goto :retry_node_deps
    ) else (
        echo   %ESC%[1;31m  [ОШИБКА] Не удалось скачать Electron вручную!%ESC%[0m
    )
) else (
    echo   %ESC%[1;33m  .   Download-Electron.bat не найден. Пропускаем fallback.%ESC%[0m
)

echo   %ESC%[1;31m  [ОШИБКА] npm install failed!%ESC%[0m
echo   %ESC%[33m       Проверьте лог выше.%ESC%[0m
goto node_done

:node_done

REM ============================================================================
REM   ШАГ 5: Playwright Chromium
REM ============================================================================
echo.
echo   %ESC%[1;33m[5/5]%ESC%[0m %ESC%[1mУстановка Playwright Chromium...%ESC%[0m

if not exist "%NODE_EXE%" (
    echo   %ESC%[1;33m  .   Node.js не найден. Пропускаем.%ESC%[0m
    goto playwright_done
)

cd /d "%REPO_DIR%"

echo   %ESC%[1;33m  -   npx playwright install chromium...%ESC%[0m
echo   %ESC%[2m       Это может занять 3-10 минут...%ESC%[0m

call "%NODE_DIR%\npx.cmd" --yes playwright install chromium

if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  .   Playwright Chromium install failed ^(не критично^).%ESC%[0m
    echo   %ESC%[33m       Вручную: npx playwright install chromium%ESC%[0m
) else (
    echo   %ESC%[1;32m  +   Playwright Chromium установлен.%ESC%[0m
)

:playwright_done
REM ============================================================================
REM   ШАГ 6: Desktop-зависимости (Electron)
REM ============================================================================
echo.
echo   %ESC%[1;33m[6/6]%ESC%[0m %ESC%[1mУстановка Desktop-зависимостей (Electron)...%ESC%[0m

if not exist "%NODE_EXE%" (
    echo   %ESC%[1;33m  .   Node.js не найден. Пропускаем.%ESC%[0m
    goto desktop_deps_done
)

cd /d "%REPO_DIR%\apps\desktop"

if not exist "package.json" (
    echo   %ESC%[1;33m  .   package.json не найден в apps\desktop. Пропускаем.%ESC%[0m
    goto desktop_deps_done
)

echo   %ESC%[1;33m  -   npm install (apps\desktop)...%ESC%[0m
echo   %ESC%[2m       Это может занять 5-10 минут...%ESC%[0m

REM Retry: 3 попытки с задержкой
set "NPM_RETRY=0"
:desktop_npm_retry
call "%NODE_DIR%\npm.cmd" install
if errorlevel 1 (
    set /a "NPM_RETRY+=1"
    if !NPM_RETRY! lss 3 (
        echo   %ESC%[1;33m  i   Повторная попытка npm install ^(!NPM_RETRY!/3^)...%ESC%[0m
        timeout /t 10 /nobreak >nul
        goto desktop_npm_retry
    )
    echo   %ESC%[1;31m  [ОШИБКА] npm install failed после 3 попыток!%ESC%[0m
    echo   %ESC%[33m       Проверьте соединение ^(возможно, нужен VPN^).%ESC%[0m
    goto desktop_deps_done
)

echo   %ESC%[1;32m  +   Desktop-зависимости установлены.%ESC%[0m

:desktop_deps_done
REM ============================================================================
REM   Патч MIME types для Windows (JS modules fail with text/plain)
REM ============================================================================
echo.
echo   %ESC%[1;33mПатч MIME types...%ESC%[0m

set "PATCH_SCRIPT=%SCRIPTS_DIR%\patch\patch_hermes_mime.ps1"

if not exist "%PATCH_SCRIPT%" (
    echo   %ESC%[1;33m  .   Скрипт патча не найден: %PATCH_SCRIPT%%ESC%[0m
    goto patch_done
)

if not exist "%REPO_DIR%\hermes_cli\web_server.py" (
    echo   %ESC%[1;33m  .   web_server.py не найден. Пропускаем.%ESC%[0m
    goto patch_done
)

REM --- Не глушим вывод
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%PATCH_SCRIPT%" -RepoDir "%REPO_DIR%"
set "PATCH_RESULT=!errorlevel!"

if !PATCH_RESULT! equ 0 (
    echo   %ESC%[1;32m  +   Патч MIME types применён.%ESC%[0m
) else if !PATCH_RESULT! equ 1 (
    echo   %ESC%[1;33m  .   Патч уже был применён ранее.%ESC%[0m
) else (
    echo   %ESC%[1;31m  [ОШИБКА] Патч не применён ^(код: !PATCH_RESULT!^)%ESC%[0m
    echo   %ESC%[33m       Проверьте вывод PowerShell выше.%ESC%[0m
)

:patch_done

REM Создаём подкаталоги HERMES_HOME
if not exist "%HERMES_HOME%\skills" mkdir "%HERMES_HOME%\skills" 2>nul
if not exist "%HERMES_HOME%\cron" mkdir "%HERMES_HOME%\cron" 2>nul
if not exist "%HERMES_HOME%\sessions" mkdir "%HERMES_HOME%\sessions" 2>nul
if not exist "%HERMES_HOME%\logs" mkdir "%HERMES_HOME%\logs" 2>nul
if not exist "%HERMES_HOME%\pairing" mkdir "%HERMES_HOME%\pairing" 2>nul
if not exist "%HERMES_HOME%\hooks" mkdir "%HERMES_HOME%\hooks" 2>nul
if not exist "%HERMES_HOME%\image_cache" mkdir "%HERMES_HOME%\image_cache" 2>nul
if not exist "%HERMES_HOME%\audio_cache" mkdir "%HERMES_HOME%\audio_cache" 2>nul
if not exist "%HERMES_HOME%\memories" mkdir "%HERMES_HOME%\memories" 2>nul

cd /d "%ROOT_DIR%"

echo.
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1;32mЗависимости установлены!%ESC%[0m
echo   %ESC%[2m  Venv: %REPO_DIR%\venv%ESC%[0m
echo   %ESC%[2m  HERMES_HOME: %HERMES_HOME%%ESC%[0m
echo  %ESC%[36m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
goto success_exit

REM ============================================================================
REM   ВЫХОДЫ
REM ============================================================================
:error_exit
echo.
echo   %ESC%[1;31m[ОШИБКА] Произошла ошибка! Нажмите любую клавишу...%ESC%[0m
pause >nul
exit /b 1

:success_exit
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0