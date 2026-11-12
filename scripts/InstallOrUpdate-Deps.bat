@REM scripts\InstallOrUpdate-Deps.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"
REM %2 = MODE: 0 = полный (Desktop), 1 = web-сервер (без Electron)
set "MODE=0"
if "%2"=="1" set "MODE=1"

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
REM   Сохраняем РЕАЛЬНЫЕ пути ДО изоляции
REM   (нужны для поиска глобального Node.js)
REM ============================================================================
set "REAL_LOCALAPPDATA=%LOCALAPPDATA%"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"

set "PYTHON_DIR="
set "PYTHON_EXE="
REM Требуемая версия Python — из .python-version репозитория (НЕ хардкод):
REM hermes-agent живёт на 3.14 (requires-python = ">=3.11,<3.15"),
REM жёсткая 3.11 ломала детект venv и валила установку.
set "PYVER="
if exist "%REPO_DIR%\.python-version" for /f "usebackq delims=" %%v in ("%REPO_DIR%\.python-version") do set "PYVER=%%v"
if not defined PYVER set "PYVER=3.11"

for /d %%d in ("%APPDATA%\uv\python\cpython-!PYVER!*") do (
    if not defined PYTHON_EXE (
        if exist "%%d\python.exe" (
            set "PYTHON_DIR=%%d"
            set "PYTHON_EXE=%%d\python.exe"
        )
    )
)
REM Фолбэк: любая доступная 3.x, если точная версия не скачана
if not defined PYTHON_EXE (
    for /d %%d in ("%APPDATA%\uv\python\cpython-3.*") do (
        if not defined PYTHON_EXE (
            if exist "%%d\python.exe" (
                set "PYTHON_DIR=%%d"
                set "PYTHON_EXE=%%d\python.exe"
            )
        )
    )
)

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

REM --- Python ---
set "PYTHON_ALT_FOUND=0"
if not exist "%PYTHON_EXE%" (
    echo   %ESC%[1;33m  .   Управляемый Python не найден. Поиск альтернатив...%ESC%[0m

    for %%p in (python.exe python3.exe) do if !PYTHON_ALT_FOUND! equ 0 (
        for /f "delims=" %%a in ('where %%p 2^>nul') do if !PYTHON_ALT_FOUND! equ 0 (
            set "PYTHON_EXE=%%a"
            set "PYTHON_ALT_FOUND=1"
        )
    )
    for %%d in (
        "%ProgramFiles%\Python313" "%ProgramFiles%\Python312"
        "%ProgramFiles%\Python311"
        "%ProgramFiles(x86)%\Python313" "%ProgramFiles(x86)%\Python312"
        "%ProgramFiles(x86)%\Python311"
    ) do if !PYTHON_ALT_FOUND! equ 0 (
        if exist "%%d\python.exe" (
            set "PYTHON_EXE=%%d\python.exe"
            set "PYTHON_ALT_FOUND=1"
        )
    )
    if !PYTHON_ALT_FOUND! equ 0 if exist "%ROOT_DIR%\python-3.11.9\python.exe" (
        set "PYTHON_EXE=%ROOT_DIR%\python-3.11.9\python.exe"
        set "PYTHON_DIR=%ROOT_DIR%\python-3.11.9"
        set "PYTHON_ALT_FOUND=1"
    )
)

if not exist "%PYTHON_EXE%" (
    echo   %ESC%[1;33m  .   Python не найден. Запускаем InstallOrUpdate-Python.bat...%ESC%[0m
    call "%SCRIPTS_DIR%\InstallOrUpdate-Python.bat" 1
    if errorlevel 1 (
        echo   %ESC%[1;31m[ОШИБКА] Python не установлен%ESC%[0m
        goto error_exit
    )
    if not exist "%PYTHON_EXE%" (
        echo   %ESC%[1;31m[ОШИБКА] Python не установлен ^(InstallOrUpdate-Python.bat не создал python.exe^)%ESC%[0m
        goto error_exit
    )
    echo   %ESC%[1;32m  +   Python установлен: %PYTHON_EXE%%ESC%[0m
)

REM --- UV ---
if not exist "%UV_EXE%" (
    echo   %ESC%[1;33m  .   UV не найден. Запускаем InstallOrUpdate-UV.bat...%ESC%[0m
    call "%SCRIPTS_DIR%\InstallOrUpdate-UV.bat" 1
    if errorlevel 1 (
        echo   %ESC%[1;31m[ОШИБКА] UV не установлен%ESC%[0m
        goto error_exit
    )
    if not exist "%UV_EXE%" (
        echo   %ESC%[1;31m[ОШИБКА] UV не установлен ^(InstallOrUpdate-UV.bat не создал uv.exe^)%ESC%[0m
        goto error_exit
    )
)

if not exist "%REPO_DIR%\.git" (
    echo   %ESC%[1;31m[ОШИБКА] Репозиторий не клонирован!%ESC%[0m
    goto error_exit
)

REM --- Python 3.11: если не найден — uv сам установит (uv python install) ---
if not defined PYTHON_EXE (
    echo   %ESC%[1;33m  .   Python 3.11 не найден — устанавливаем через uv...%ESC%[0m
    "%UV_EXE%" python install 3.11
    if errorlevel 1 (
        echo   %ESC%[1;31m  [ОШИБКА] uv python install 3.11 не удалось.%ESC%[0m
        goto error_exit
    )
    for /d %%d in ("%APPDATA%\uv\python\cpython-3.11*") do (
        if not defined PYTHON_EXE (
            if exist "%%d\python.exe" (
                set "PYTHON_DIR=%%d"
                set "PYTHON_EXE=%%d\python.exe"
            )
        )
    )
    if not defined PYTHON_EXE (
        echo   %ESC%[1;31m  [ОШИБКА] Python 3.11 не найден после установки uv.%ESC%[0m
        goto error_exit
    )
    echo   %ESC%[1;32m  +   Python установлен: !PYTHON_EXE!%ESC%[0m
)

REM ============================================================================
REM   Определение Node.js (глобальный -> локальный) — ДО любых npm-операций!
REM   Глобальный в приоритете (как в InstallOrUpdate-Desktop.bat).
REM   Нет ни глобального, ни локального — Node-шаги будут пропущены (HAS_NODE=0).
REM ============================================================================
set "NODE_CMD="
set "NPM_CMD="
set "NPX_CMD="
set "IS_GLOBAL_NODE=0"
set "HAS_NODE=0"
set "GLOBAL_NODE="

REM --- 1. Глобальный Node.js: стандартные пути (ПРИОРИТЕТ) ---
if exist "%ProgramFiles%\nodejs\node.exe" set "GLOBAL_NODE=%ProgramFiles%\nodejs"
if not defined GLOBAL_NODE if exist "%ProgramFiles(x86)%\nodejs\node.exe" set "GLOBAL_NODE=%ProgramFiles(x86)%\nodejs"
if not defined GLOBAL_NODE if exist "%REAL_LOCALAPPDATA%\Programs\nodejs\node.exe" set "GLOBAL_NODE=%REAL_LOCALAPPDATA%\Programs\nodejs"

REM --- 2. Глобальный Node.js: реестр (HKLM + WOW6432Node + HKCU) ---
if not defined GLOBAL_NODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKLM\SOFTWARE\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" (
            if exist "%%c\node.exe" set "GLOBAL_NODE=%%c"
        )
    )
)
if not defined GLOBAL_NODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKLM\SOFTWARE\WOW6432Node\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" (
            if exist "%%c\node.exe" set "GLOBAL_NODE=%%c"
        )
    )
)
if not defined GLOBAL_NODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKCU\SOFTWARE\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" (
            if exist "%%c\node.exe" set "GLOBAL_NODE=%%c"
        )
    )
)

if defined GLOBAL_NODE (
    set "NODE_CMD=!GLOBAL_NODE!\node.exe"
    set "NPM_CMD=!GLOBAL_NODE!\npm.cmd"
    set "NPX_CMD=!GLOBAL_NODE!\npx.cmd"
    set "IS_GLOBAL_NODE=1"
    set "HAS_NODE=1"
    REM npm 12 из реального профиля имеет приоритет (свежий hermes-agent требует npm >=12; глобальный npm 11.16 несовместим)
    set "REAL_NPM_DIR="
    REM Портативный профиль (%APPDATA% -> data\appdata) содержит рабочий npm 12.x - он приоритетнее
    if exist "%APPDATA%\npm\npm.cmd" set "REAL_NPM_DIR=%APPDATA%\npm"
    if not defined REAL_NPM_DIR if exist "%SystemDrive%\Users\%USERNAME%\AppData\Roaming\npm\npm.cmd" set "REAL_NPM_DIR=%SystemDrive%\Users\%USERNAME%\AppData\Roaming\npm"
    if not defined REAL_NPM_DIR (
        for /d %%d in ("%SystemDrive%\Users\%USERNAME%.*") do (
            if not defined REAL_NPM_DIR (
                if exist "%%d\AppData\Roaming\npm\npm.cmd" set "REAL_NPM_DIR=%%d\AppData\Roaming\npm"
            )
        )
    )
    if defined REAL_NPM_DIR (
        set "NPM_CMD=!REAL_NPM_DIR!\npm.cmd"
        set "NPX_CMD=!REAL_NPM_DIR!\npx.cmd"
        set "PATH=!REAL_NPM_DIR!;!PATH!"
    )
    goto :node_ready
)

REM --- 3. Локальный Node.js (fallback, если глобального нет) ---
if exist "%NODE_EXE%" (
    set "NODE_CMD=%NODE_EXE%"
    set "NPM_CMD=%NODE_DIR%\npm.cmd"
    set "NPX_CMD=%NODE_DIR%\npx.cmd"
    set "HAS_NODE=1"
    goto :node_ready
)

REM --- 4. Node.js нет вообще — устанавливаем локальный ---
echo.
echo   %ESC%[1;33m  →   Node.js не найден. Запускаем InstallOrUpdate-NodeJS.bat...%ESC%[0m
call "%SCRIPTS_DIR%\InstallOrUpdate-NodeJS.bat" 1

if errorlevel 1 (
    echo   %ESC%[1;33m  [i]    Установка Node.js не удалась. Node-шаги будут пропущены.%ESC%[0m
    goto :node_ready
)

REM --- Перепроверяем локальный Node.js после установки ---
if exist "%NODE_EXE%" (
    set "NODE_CMD=%NODE_EXE%"
    set "NPM_CMD=%NODE_DIR%\npm.cmd"
    set "NPX_CMD=%NODE_DIR%\npx.cmd"
    set "HAS_NODE=1"
) else (
    echo   %ESC%[1;33m  [i]    Node.js не появился после установки. Node-шаги будут пропущены.%ESC%[0m
)

:node_ready

REM ============================================================================
REM   Финальный выбор Node.js/pnpm — общий резолвер.
REM   Обязан стоять ПОСЛЕ метки: ветки выше делают goto :node_ready и иначе
REM   перепрыгивают его. hermes-agent требует Node >=26 и pnpm 12.x
REM   (pm/lock.json); портативный Node из tools\ приоритетнее глобального.
REM ============================================================================
call "%SCRIPTS_DIR%\Find-Node-Toolchain.bat"
if "!HAS_NODE!"=="1" set "NODE_EXE=!NODE_CMD!"
if "!NODE_TOO_OLD!"=="1" (
    echo   %ESC%[1;33m  !   Node.js !NODE_VER! ниже требуемой ^(hermes-agent: engines.node ^>=26^).%ESC%[0m
    echo   %ESC%[2m       Ожидался портативный: %HERMES_HOME%\tools\node-26*-win32-x64%ESC%[0m
)

REM cls
echo.
echo  %ESC%[1;35m################################################################################%ESC%[0m
echo  %ESC%[1;35m##                                                                            ##%ESC%[0m
echo  %ESC%[1;35m##%ESC%[0m                 %ESC%[1;37mHermes Portable%ESC%[0m   %ESC%[1;33m—%ESC%[0m   %ESC%[1;33mУстановка зависимостей%ESC%[0m               %ESC%[1;35m##%ESC%[0m
echo  %ESC%[1;35m##                                                                            ##%ESC%[0m
echo  %ESC%[1;35m################################################################################%ESC%[0m
echo.

REM --- Какой Node.js выбран (определён выше) ---
if "!IS_GLOBAL_NODE!"=="1" (
    echo   %ESC%[1;33m  .   Node.js: глобальный%ESC%[0m
    echo   %ESC%[2m       !GLOBAL_NODE!\%ESC%[0m
) else (
    if "!HAS_NODE!"=="1" (
        echo   %ESC%[1;33m  .   Node.js: локальный%ESC%[0m
        echo   %ESC%[2m       %NODE_DIR%\%ESC%[0m
    ) else (
        echo   %ESC%[1;33m  .   Node.js: не найден — Node-шаги будут пропущены%ESC%[0m
    )
)

REM ============================================================================
REM   Добавляем в PATH (Node — под выбранный вариант)
REM ============================================================================
if "!IS_GLOBAL_NODE!"=="1" (
    set "PATH=!GLOBAL_NODE!;%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%UV_DIR%;%PATH%"
) else (
    set "PATH=%NODE_DIR%;%PYTHON_DIR%;%PYTHON_DIR%\Scripts;%UV_DIR%;%PATH%"
)

REM ============================================================================
REM   ПРЕДУПРЕЖДЕНИЕ
REM ============================================================================
echo.
echo  %ESC%[1;33m────────────────────────────────────────────────────────────────────────────────%ESC%[0m
echo   %ESC%[1;33m[i]  ВНИМАНИЕ: Fallback-установка Hermes%ESC%[0m
echo.
echo   %ESC%[1;37mВы находитесь в ветке fallback-установки.%ESC%[0m
echo   %ESC%[2m   Сейчас будет выполнена доустановка недостающих пакетов.%ESC%[0m
echo   %ESC%[2m   Это нормальная часть установки портативного Hermes.%ESC%[0m
echo.
echo   %ESC%[1;32m[Enter]%ESC%[0m %ESC%[1mПродолжить установку%ESC%[0m
echo.
pause
echo.

REM ============================================================================
REM   ОБЯЗАТЕЛЬНО: остановить службы Hermes ПЕРЕД обновлением.
REM   Службы держат venv\Scripts\*.exe: uv падает с os error 32, а rmdir
REM   оставляет нерабочее окружение. Продолжаем только после реального STOPPED.
REM ============================================================================
call "%SCRIPTS_DIR%\Hermes-Services.bat" stop
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Службы Hermes не остановлены — обновление прервано.%ESC%[0m
    echo   %ESC%[33m       Остановите их вручную ^(scripts\Stop-Hermes-Service.bat^) и повторите.%ESC%[0m
    cd /d "%ROOT_DIR%"
    goto error_exit
)
echo.

REM ============================================================================
REM   ШАГ 1: Создание venv через uv
REM ============================================================================
echo   %ESC%[1;33m[1/6]%ESC%[0m %ESC%[1mСоздание виртуального окружения...%ESC%[0m

cd /d "%REPO_DIR%"

set "VENV_OK=0"

REM venv валиден только если это настоящее окружение: есть pyvenv.cfg и
REM sys.prefix указывает именно на него. Без этой сверки повреждённый каталог
REM (остался один Scripts) считался рабочим, а uv sync ставил пакеты
REM в базовый интерпретатор — venv оставался пустым и hermes.exe падал.
if exist "venv\Scripts\python.exe" if exist "venv\pyvenv.cfg" (
    REM starlette/uvicorn проверяются намеренно: hermes_cli есть и в исходниках
    REM репозитория (CWD), поэтому один он давал ложный плюс.
    "venv\Scripts\python.exe" -c "import sys, os, hermes_cli, starlette, uvicorn; root=os.path.realpath(r'%REPO_DIR%\venv'); assert os.path.realpath(sys.prefix).lower()==root.lower(), sys.prefix; req=open('.python-version').read().strip(); assert sys.version.split()[0].startswith(req), sys.version" >nul 2>&1
    if !errorlevel! equ 0 (
        set "VENV_OK=1"
        echo   %ESC%[1;32m  +   venv валиден ^(Python !PYVER! + hermes_cli^) — пересоздание не нужно.%ESC%[0m
    ) else (
        echo   %ESC%[1;33m  .   venv невалиден ^(версия/пакеты/префикс^). Пересоздание...%ESC%[0m
    )
) else (
    echo   %ESC%[1;33m  .   venv отсутствует или повреждён ^(нет pyvenv.cfg^). Создание...%ESC%[0m
)

if "!VENV_OK!"=="0" (
    REM НЕ удаляем venv на месте: при работающих службах rmdir сносит Lib и падает
    REM на Scripts, оставляя нерабочее окружение. Откладываем каталог целиком.
    if exist "venv" (
        if exist "venv.old" rmdir /s /q "venv.old" 2>nul
        move "venv" "venv.old" >nul 2>&1
        if exist "venv" (
            echo   %ESC%[1;31m[ОШИБКА] venv занят процессом — отложить не удалось.%ESC%[0m
            echo   %ESC%[33m       Остановите службы Hermes и повторите:%ESC%[0m
            echo   %ESC%[1;37m       net stop "HermesGateway ^(D:_NEURO_Hermes^)"%ESC%[0m
            echo   %ESC%[1;37m       net stop "HermesMessengerGateway ^(D:_NEURO_Hermes^)"%ESC%[0m
            echo   %ESC%[2m       После установки службы поднимутся при следующем запуске Hermes.%ESC%[0m
            cd /d "%ROOT_DIR%"
            goto error_exit
        )
    )

    REM Создаём venv с ЯВНЫМ путём (uv по умолчанию создаёт .venv — нам это НЕ нужно!)
    "%UV_EXE%" venv --clear --python "%PYTHON_EXE%" "%REPO_DIR%\venv"

    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m[ОШИБКА] Не удалось создать venv...%ESC%[0m
        echo   %ESC%[33m       Если это os error 32 ^(файл занят^) — остановите службы Hermes:%ESC%[0m
        echo   %ESC%[1;37m       net stop "HermesGateway ^(D:_NEURO_Hermes^)"%ESC%[0m
        echo   %ESC%[1;37m       net stop "HermesMessengerGateway ^(D:_NEURO_Hermes^)"%ESC%[0m
        cd /d "%ROOT_DIR%"
        goto error_exit
    )

    echo   %ESC%[1;32m  +   Виртуальное окружение создано.%ESC%[0m
) else (
    echo   %ESC%[2m       Шаг создания пропущен — используется существующий venv.%ESC%[0m
)

REM Отложенное старое окружение больше не нужно
if exist "venv.old" rmdir /s /q "venv.old" 2>nul

REM ============================================================================
REM   ШАГ 2: Установка зависимостей через uv sync
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/6]%ESC%[0m %ESC%[1mУстановка зависимостей (uv sync --extra all --locked)...%ESC%[0m
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
echo   %ESC%[1;33m[2/6]%ESC%[0m %ESC%[1mFallback: uv pip install -e ".[all]"...%ESC%[0m

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
echo   %ESC%[1;33m[3/6]%ESC%[0m %ESC%[1mПроверка установки...%ESC%[0m

"%REPO_DIR%\venv\Scripts\python.exe" -c "import dotenv, openai, rich, prompt_toolkit"
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Baseline imports failed!%ESC%[0m
    echo   %ESC%[33m       Попробуйте: uv sync --extra all --locked%ESC%[0m
    cd /d "%ROOT_DIR%"
    goto error_exit
)

echo   %ESC%[1;32m  +   Baseline imports OK.%ESC%[0m

REM ============================================================================
REM   ШАГ 4: Node.js-зависимости (workspace root)
REM ============================================================================
echo.
echo   %ESC%[1;33m[4/6]%ESC%[0m %ESC%[1mУстановка Node.js-зависимостей...%ESC%[0m

if "!HAS_NODE!"=="0" (
    echo   %ESC%[1;33m  .   Node.js не найден — пропускаем npm install.%ESC%[0m
    echo   %ESC%[2m       Запустите InstallOrUpdate-NodeJS.bat и повторите.%ESC%[0m
    goto node_done
)

echo   %ESC%[1;33m  .   Используем Node.js:%ESC%[0m
echo   %ESC%[2m       !NODE_CMD!%ESC%[0m

REM npm install здесь принципиально невозможен: hermes-agent на pnpm, а npm-arborist
REM падает на его store ("Cannot read properties of null (reading 'matches')").
if "!HAS_PNPM!"=="0" (
    echo   %ESC%[1;31m  [ОШИБКА] pnpm не найден ^(нужен !PNPM_EXPECTED!^).%ESC%[0m
    echo   %ESC%[2m       Ожидался: %HERMES_HOME%\tools\pnpm-!PNPM_EXPECTED!-win32-x64\pnpm.exe%ESC%[0m
    echo   %ESC%[33m       Обновите Hermes через bootstrap или поставьте pnpm !PNPM_EXPECTED! вручную.%ESC%[0m
    goto node_done
)
if not "!PNPM_VER!"=="!PNPM_EXPECTED!" (
    echo   %ESC%[1;33m  !   pnpm !PNPM_VER! вместо !PNPM_EXPECTED! — установка может быть отклонена.%ESC%[0m
)

echo   %ESC%[1;33m  -   pnpm install --frozen-lockfile (workspace root)...%ESC%[0m
echo   %ESC%[2m       Это может занять 5-15 минут...%ESC%[0m

echo   %ESC%[2m       !PNPM_CMD! !PNPM_VER!%ESC%[0m
call "!PNPM_CMD!" install --frozen-lockfile
set "PNPM_RC=!errorlevel!"

if !PNPM_RC! equ 0 (
    echo   %ESC%[1;32m  +   Node.js зависимости установлены ^(pnpm^).%ESC%[0m
    goto node_done
)

echo   %ESC%[1;31m  [ОШИБКА] pnpm install failed ^(код !PNPM_RC!^)!%ESC%[0m
echo   %ESC%[33m       Проверьте вывод выше: сеть/прокси, либо версия pnpm != !PNPM_EXPECTED!.%ESC%[0m
goto node_done

:node_done

REM ============================================================================
REM   ШАГ 5: Playwright Chromium
REM ============================================================================
echo.
echo   %ESC%[1;33m[5/6]%ESC%[0m %ESC%[1mУстановка Playwright...%ESC%[0m

REM --- Установка пакета playwright через uv в venv ---
echo   %ESC%[1;33m  -   uv pip install playwright...%ESC%[0m
"%UV_EXE%" pip install --python "%REPO_DIR%\venv\Scripts\python.exe" playwright
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  +   Пакет playwright установлен.%ESC%[0m
) else (
    echo   %ESC%[1;33m  .   Пакет playwright не установлен — browser tools не будут работать.%ESC%[0m
    goto playwright_done
)

REM --- Установка pytest (канонический тест репозитория: scripts\tests) ---
echo   %ESC%[1;33m  -   uv pip install pytest...%ESC%[0m
"%UV_EXE%" pip install --python "%REPO_DIR%\venv\Scripts\python.exe" pytest
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  +   Пакет pytest установлен — канонический тест доступен.%ESC%[0m
) else (
    echo   %ESC%[1;33m  .   Пакет pytest не установлен — тест запускается простым python.%ESC%[0m
)

REM --- Установка браузера Chromium через python -m playwright ---
cd /d "%REPO_DIR%"

if "!HAS_NODE!"=="0" (
    echo   %ESC%[1;33m  .   Node.js не найден. Пропускаем.%ESC%[0m
    goto playwright_done
)

echo   %ESC%[1;33m  -   python -m playwright install chromium...%ESC%[0m
echo   %ESC%[2m       Это может занять 3-10 минут...%ESC%[0m

"%REPO_DIR%\venv\Scripts\python.exe" -m playwright install chromium

if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  .   Playwright Chromium install failed ^(не критично^).%ESC%[0m
    echo   %ESC%[33m       Вручную: "%REPO_DIR%\venv\Scripts\python.exe" -m playwright install chromium%ESC%[0m
) else (
    echo   %ESC%[1;32m  +   Playwright Chromium установлен.%ESC%[0m
)

REM ============================================================================
REM   ШАГ 5b: Установка дополнительных инструментов (ripgrep, ffmpeg)
REM ============================================================================
echo.
echo   %ESC%[1;33m[5b/6]%ESC%[0m %ESC%[1mУстановка дополнительных инструментов...%ESC%[0m

REM --- ripgrep (быстрый поиск в файлах, критично для Hermes) ---
echo   %ESC%[1;33m  -   ripgrep ^(rg^)...%ESC%[0m
if not exist "%HERMES_HOME%\bin\rg.exe" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps1\install_rg.ps1" -HermesHome "%HERMES_HOME%"
)
if exist "%HERMES_HOME%\bin\rg.exe" (
    echo   %ESC%[1;32m  +   ripgrep установлен.%ESC%[0m
) else (
    echo   %ESC%[1;33m  .   ripgrep не установлен ^(будет использован findstr^).%ESC%[0m
)

REM --- ffmpeg-набор (ffmpeg/ffprobe/ffplay: TTS, аудио, медиа) ---
echo   %ESC%[1;33m  -   ffmpeg-набор ^(ffmpeg/ffprobe/ffplay^)...%ESC%[0m
if not exist "%HERMES_HOME%\bin\ffmpeg.exe" goto :install_ffmpeg_toolkit
if exist "%HERMES_HOME%\bin\ffprobe.exe" goto :ffmpeg_toolkit_ok
:install_ffmpeg_toolkit
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps1\install_ffmpeg.ps1" -HermesHome "%HERMES_HOME%"
:ffmpeg_toolkit_ok
if exist "%HERMES_HOME%\bin\ffmpeg.exe" (
    if exist "%HERMES_HOME%\bin\ffprobe.exe" (
        echo   %ESC%[1;32m  +   ffmpeg-набор установлен.%ESC%[0m
    ) else (
        echo   %ESC%[1;33m  .   ffmpeg не установлен ^(TTS будет ограничен^).%ESC%[0m
    )
) else (
    echo   %ESC%[1;33m  .   ffmpeg не установлен ^(TTS будет ограничен^).%ESC%[0m
)

:playwright_done
REM ============================================================================
REM   ШАГ 6: Desktop-зависимости (Electron) — пропускаем в web-режиме
REM ============================================================================
echo.
if "!MODE!"=="1" (
    echo   %ESC%[1;33m[6/6]%ESC%[0m %ESC%[1mDesktop-зависимости ^(Electron^)%ESC%[0m — пропущено ^(web-режим сервера^)
    goto desktop_deps_done
)
echo   %ESC%[1;33m[6/6]%ESC%[0m %ESC%[1mУстановка Desktop-зависимостей (Electron)...%ESC%[0m

if "!HAS_NODE!"=="0" (
    echo   %ESC%[1;33m  .   Node.js не найден. Пропускаем.%ESC%[0m
    goto desktop_deps_done
)

cd /d "%REPO_DIR%\apps\desktop"

if not exist "package.json" (
    echo   %ESC%[1;33m  .   package.json не найден в apps\desktop. Пропускаем.%ESC%[0m
    goto desktop_deps_done
)

echo   %ESC%[1;33m  -   pnpm install --frozen-lockfile (apps\desktop)...%ESC%[0m
echo   %ESC%[2m       Это может занять 5-10 минут...%ESC%[0m

if "!HAS_PNPM!"=="0" (
    echo   %ESC%[1;31m  [ОШИБКА] pnpm не найден — Desktop-зависимости не установлены.%ESC%[0m
    goto desktop_deps_done
)

REM Retry: 3 попытки с задержкой (Electron-бинарник качается по сети)
set "PNPM_RETRY=0"
:desktop_pnpm_retry
call "!PNPM_CMD!" install --frozen-lockfile
if errorlevel 1 (
    set /a "PNPM_RETRY+=1"
    if !PNPM_RETRY! lss 3 (
        echo   %ESC%[1;33m  [i]    Повторная попытка pnpm install ^(!PNPM_RETRY!/3^)...%ESC%[0m
        timeout /t 10 /nobreak >nul
        goto desktop_pnpm_retry
    )
    echo   %ESC%[1;31m  [ОШИБКА] pnpm install failed после 3 попыток!%ESC%[0m
    echo   %ESC%[33m       Если виноват Electron — запустите scripts\Download-Electron.bat и повторите.%ESC%[0m
    echo   %ESC%[33m       Иначе проверьте соединение ^(возможно, нужен VPN^).%ESC%[0m
    goto desktop_deps_done
)

echo   %ESC%[1;32m  +   Desktop-зависимости установлены ^(pnpm^).%ESC%[0m

:desktop_deps_done
REM ============================================================================
REM   Патч MIME types ОТКЛЮЧЁН: свежий web_server.py уже содержит MIME-типы
REM   (".mjs": "application/javascript" и др. — добавлено upstream).
REM   Файл patch_hermes_mime.ps1 оставлен на случай отката.
REM ============================================================================
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

REM --- Создаём config.yaml штатной командой hermes config set, если нет ---
if not exist "%HERMES_HOME%\config.yaml" (
    if exist "%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe" (
        echo   %ESC%[1;33m  .   config.yaml нет — создаём через hermes config set...%ESC%[0m
        "%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe" config set display.skin mono
        "%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe" config set display.language ru
        echo   %ESC%[1;32m  +   config.yaml создан штатной командой.%ESC%[0m
    ) else (
        echo   %ESC%[1;33m  .   hermes.exe не найден, создаю минимальный...%ESC%[0m
        echo display:> "%HERMES_HOME%\config.yaml"
        echo.  language: ru>> "%HERMES_HOME%\config.yaml"
        echo   %ESC%[1;32m  +   config.yaml создан.%ESC%[0m
    )
)

REM ============================================================================
REM   ШАГ 7: Окружение (вместо install.ps1): .env, SOUL.md, skills, bootstrap
REM ============================================================================
echo.
echo   %ESC%[1;33m[7/6]%ESC%[0m %ESC%[1mНастройка окружения...%ESC%[0m

REM --- .env из шаблона (если нет) ---
if not exist "%HERMES_HOME%\.env" (
    if exist "%REPO_DIR%\.env.example" (
        copy /Y "%REPO_DIR%\.env.example" "%HERMES_HOME%\.env" >nul
        echo   %ESC%[1;32m  +   .env создан из шаблона.%ESC%[0m
    )
)

REM --- SOUL.md (если нет) ---
if not exist "%HERMES_HOME%\SOUL.md" (
    if exist "%SCRIPTS_DIR%\profiles\default_soul.md" (
        copy /Y "%SCRIPTS_DIR%\profiles\default_soul.md" "%HERMES_HOME%\SOUL.md" >nul
        echo   %ESC%[1;32m  +   SOUL.md создан.%ESC%[0m
    )
)

REM --- Skills sync (как install.ps1: python tools\skills_sync.py) ---
if exist "%REPO_DIR%\venv\Scripts\python.exe" (
    if exist "%REPO_DIR%\tools\skills_sync.py" (
        echo   %ESC%[1;33m  .   Синхронизация встроенных skills...%ESC%[0m
        set "PYTHONIOENCODING=utf-8"
        "%REPO_DIR%\venv\Scripts\python.exe" "%REPO_DIR%\tools\skills_sync.py" 2>nul
        echo   %ESC%[1;32m  +   Skills синхронизированы.%ESC%[0m
    )
)

REM --- Bootstrap marker (как install.ps1: .hermes-bootstrap-complete) ---
if not exist "%REPO_DIR%\.hermes-bootstrap-complete" (
    type nul > "%REPO_DIR%\.hermes-bootstrap-complete" 2>nul
    echo   %ESC%[1;32m  +   Bootstrap marker создан.%ESC%[0m
)

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
REM Службы останавливались ради обновления — возвращаем их, чтобы Hermes не остался лежать
call "%SCRIPTS_DIR%\Hermes-Services.bat" start >nul 2>&1
echo.
echo   %ESC%[1;31m[ОШИБКА] Произошла ошибка! Нажмите любую клавишу...%ESC%[0m
pause >nul
exit /b 1

:success_exit
REM Возвращаем службы, которые работали до обновления
call "%SCRIPTS_DIR%\Hermes-Services.bat" start
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  !   Службы не запустились автоматически — запустите scripts\Start-Hermes-Service.bat%ESC%[0m
)
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0