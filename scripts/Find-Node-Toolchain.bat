@REM scripts\Find-Node-Toolchain.bat
@REM Единая точка выбора Node.js (>=26) и pnpm (12.x) для hermes-agent.
@REM Вызов: call "%SCRIPTS_DIR%\Find-Node-Toolchain.bat" ["<HERMES_HOME>\tools"]
@REM Возвращает в вызывающий скрипт: HAS_NODE, NODE_CMD, NODE_DIR, NODE_VER, NODE_MAJOR,
@REM NODE_TOO_OLD, IS_GLOBAL_NODE, NPM_CMD, NPX_CMD,
@REM HAS_PNPM, PNPM_CMD, PNPM_DIR, PNPM_VER, PNPM_EXPECTED, PNPM_VER_MISMATCH.
@REM ВАЖНО: npm install в корне hermes-agent невозможен — репозиторий на pnpm
@REM (pnpm-workspace.yaml, engines.npm = "npm is refused here", пин в pm/lock.json).
@REM npm-arborist падает на pnpm-store: "Cannot read properties of null (reading 'matches')".
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "TOOLS_DIR=%~1"
if not defined TOOLS_DIR set "TOOLS_DIR=%HERMES_HOME%\tools"

REM --- pnpm, который ждёт hermes-agent (совпадает с pm/lock.json) ---
set "PNPM_EXPECTED=12.15.0"
set "NODE_MIN_MAJOR=26"

REM ============================================================================
REM   pnpm: ВЕРСИЯ важнее происхождения (пин pm/lock.json ломает сборку)
REM   1) pnpm нужной версии из PATH (.exe ИЛИ .cmd) -> 2) tools\pnpm-<нужной> ->
REM   3) любой tools\pnpm-* -> 4) pnpm в каталоге Node (npm -g) -> 5) любой из PATH
REM   Если ничего не нашли - ставим pnpm нужной версии (см. :ensure_pnpm).
REM ============================================================================
set "PNPM_CMD="
set "PNPM_DIR="
set "PNPM_VER="
set "HAS_PNPM=0"
set "PNPM_VER_MISMATCH=0"
set "PNPM_ANY="
set "PNPM_ANY_VER="

REM --- 1) pnpm нужной версии, доступный по имени (ловим и pnpm.exe, и pnpm.cmd) ---
for /f "delims=" %%p in ('where pnpm 2^>nul') do (
    if not defined PNPM_CMD (
        set "PV="
        for /f "delims=" %%v in ('"%%p" --version 2^>nul') do set "PV=%%v"
        if "!PV!"=="!PNPM_EXPECTED!" (
            set "PNPM_CMD=%%p"
            set "PNPM_VER=!PV!"
        ) else (
            if not defined PNPM_ANY (
                set "PNPM_ANY=%%p"
                set "PNPM_ANY_VER=!PV!"
            )
        )
    )
)

REM --- 2) стандартное место портативного pnpm нужной версии ---
if not defined PNPM_CMD (
    if exist "%TOOLS_DIR%\pnpm-!PNPM_EXPECTED!-win32-x64\pnpm.exe" set "PNPM_CMD=%TOOLS_DIR%\pnpm-!PNPM_EXPECTED!-win32-x64\pnpm.exe"
)

REM --- 3) любой портативный tools\pnpm-* (exe или cmd) ---
if not defined PNPM_CMD (
    for /d %%d in ("%TOOLS_DIR%\pnpm-*") do (
        if not defined PNPM_CMD if exist "%%~fd\pnpm.exe" set "PNPM_CMD=%%~fd\pnpm.exe"
        if not defined PNPM_CMD if exist "%%~fd\pnpm.cmd" set "PNPM_CMD=%%~fd\pnpm.cmd"
    )
)

REM --- 4) pnpm, поставленный глобально внутрь портативного Node (npm i -g pnpm) ---
if not defined PNPM_CMD (
    if defined NODE_DIR (
        if exist "!NODE_DIR!\pnpm.cmd" set "PNPM_CMD=!NODE_DIR!\pnpm.cmd"
    )
)

REM --- 5) последний вариант - любой pnpm из PATH (с пометкой о расхождении версии) ---
if not defined PNPM_CMD if defined PNPM_ANY (
    set "PNPM_CMD=!PNPM_ANY!"
    set "PNPM_VER=!PNPM_ANY_VER!"
    set "PNPM_VER_MISMATCH=1"
)

if defined PNPM_CMD (
    for %%f in ("!PNPM_CMD!") do set "PNPM_DIR=%%~dpf"
    if defined PNPM_DIR set "PNPM_DIR=!PNPM_DIR:~0,-1!"
    if not defined PNPM_VER (
        for /f "delims=" %%v in ('"!PNPM_CMD!" --version 2^>nul') do set "PNPM_VER=%%v"
    )
)
if defined PNPM_VER (
    set "HAS_PNPM=1"
    if not "!PNPM_VER!"=="!PNPM_EXPECTED!" set "PNPM_VER_MISMATCH=1"
)

REM --- не нашли - попробуем поставить сами ПОСЛЕ определения Node (см. ниже) ---

REM ============================================================================
REM   Node.js: ГЛОБАЛЬНЫЙ (если >= NODE_MIN_MAJOR) -> портативный tools\node-* ->
REM   локальный <HERMES_HOME>\node -> глобальный устаревший (с флагом NODE_TOO_OLD).
REM   Глобальный в приоритете: если он подходящей версии, портативный не навязываем.
REM ============================================================================
set "NODE_CMD="
set "NODE_DIR="
set "NODE_VER="
set "NODE_MAJOR=0"
set "NODE_TOO_OLD=0"
set "IS_GLOBAL_NODE=0"
set "CAND="
set "BEST_MAJOR=0"
set "BEST_MINOR=0"

REM --- ищем глобальный Node (Program Files + реестр HKLM/HKCU) и его версию ---
set "GNODE="
if exist "%ProgramFiles%\nodejs\node.exe" set "GNODE=%ProgramFiles%\nodejs\node.exe"
if not defined GNODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKLM\SOFTWARE\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" if exist "%%c\node.exe" set "GNODE=%%c\node.exe"
    )
)
if not defined GNODE (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKCU\SOFTWARE\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" if exist "%%c\node.exe" set "GNODE=%%c\node.exe"
    )
)
set "GVER="
set "GMAJOR=0"
if defined GNODE (
    for /f "delims=" %%v in ('"!GNODE!" --version 2^>nul') do set "GVER=%%v"
)
if defined GVER (
    set "GNUM=!GVER:v=!"
    for /f "tokens=1 delims=." %%a in ("!GNUM!") do set "GMAJOR=%%a"
)

REM --- 1) глобальный подходящей версии: берём его ---
if defined GNODE (
    if !GMAJOR! GEQ !NODE_MIN_MAJOR! (
        set "CAND=!GNODE!"
        set "IS_GLOBAL_NODE=1"
    )
)

REM --- 2) портативный tools\node-* (версия выбирается численно, а не по алфавиту:
REM         строкой 26.12.1 < 26.7.0, хотя 26.12.1 новее) ---
if not defined CAND (
    for /d %%d in ("%TOOLS_DIR%\node-*") do (
        if exist "%%~fd\node.exe" (
            set "CUR="
            for /f "delims=" %%v in ('"%%~fd\node.exe" --version 2^>nul') do set "CUR=%%v"
            if defined CUR (
                set "TAKE=0"
                set "NUM=!CUR:v=!"
                set "CM=0"
                set "CN=0"
                for /f "tokens=1,2 delims=." %%x in ("!NUM!") do (
                    set "CM=%%x"
                    set "CN=%%y"
                )
                if !CM! gtr !BEST_MAJOR! set "TAKE=1"
                if !CM! equ !BEST_MAJOR! if !CN! gtr !BEST_MINOR! set "TAKE=1"
                if "!TAKE!"=="1" (
                    set "BEST_MAJOR=!CM!"
                    set "BEST_MINOR=!CN!"
                    set "CAND=%%~fd\node.exe"
                )
            )
        )
    )
)

REM --- 3) локальный <HERMES_HOME>\node ---
if not defined CAND if exist "%HERMES_HOME%\node\node.exe" set "CAND=%HERMES_HOME%\node\node.exe"

REM --- 4) глобальный любой (даже устаревший) - с флагом NODE_TOO_OLD ---
if not defined CAND (
    if defined GNODE (
        set "CAND=!GNODE!"
        set "IS_GLOBAL_NODE=1"
    )
)

if defined CAND (
    for /f "delims=" %%v in ('"!CAND!" --version 2^>nul') do set "NODE_VER=%%v"
)
if defined NODE_VER (
    set "NODE_NUM=!NODE_VER:v=!"
    for /f "tokens=1 delims=." %%a in ("!NODE_NUM!") do set "NODE_MAJOR=%%a"
)

REM Точка устраивает всегда, если найдена; устаревшая — тоже берётся (HAS_NODE=1),
REM но с флагом NODE_TOO_OLD=1, чтобы вызывающий скрипт предупредил до установки.
if defined CAND (
    set "NODE_CMD=!CAND!"
    for %%f in ("!CAND!") do set "NODE_DIR=%%~dpf"
    if defined NODE_DIR set "NODE_DIR=!NODE_DIR:~0,-1!"
    set "HAS_NODE=1"
    if !NODE_MAJOR! lss !NODE_MIN_MAJOR! set "NODE_TOO_OLD=1"
)

REM --- pnpm так и не найден: пробуем поставить сами ---
if "!HAS_PNPM!"=="0" call :ensure_pnpm

set "NPM_CMD="
set "NPX_CMD="
if defined NODE_DIR (
    if exist "!NODE_DIR!\npm.cmd" set "NPM_CMD=!NODE_DIR!\npm.cmd"
    if exist "!NODE_DIR!\npx.cmd" set "NPX_CMD=!NODE_DIR!\npx.cmd"
)
if defined NODE_DIR set "PATH=!NODE_DIR!;!PATH!"
if defined PNPM_DIR set "PATH=!PNPM_DIR!;!PATH!"

endlocal & (
    set "HAS_NODE=%HAS_NODE%"
    set "NODE_CMD=%NODE_CMD%"
    set "NODE_DIR=%NODE_DIR%"
    set "NODE_VER=%NODE_VER%"
    set "NODE_MAJOR=%NODE_MAJOR%"
    set "NODE_TOO_OLD=%NODE_TOO_OLD%"
    set "IS_GLOBAL_NODE=%IS_GLOBAL_NODE%"
    set "NPM_CMD=%NPM_CMD%"
    set "NPX_CMD=%NPX_CMD%"
    set "HAS_PNPM=%HAS_PNPM%"
    set "PNPM_CMD=%PNPM_CMD%"
    set "PNPM_DIR=%PNPM_DIR%"
    set "PNPM_VER=%PNPM_VER%"
    set "PNPM_EXPECTED=%PNPM_EXPECTED%"
    set "PNPM_VER_MISMATCH=%PNPM_VER_MISMATCH%"
    set "PATH=%PATH%"
)

exit /b 0

REM ============================================================================
REM   Установка pnpm нужной версии, если его нет ни в PATH, ни в tools
REM   Источник 1: готовый архив GitHub pnpm-win32-x64.zip (не зависит от npm/реестра)
REM   Источник 2: npm install -g внутрь портативного Node (если архив недоступен)
REM ============================================================================
:ensure_pnpm
set "PNPM_TARGET=%TOOLS_DIR%\pnpm-!PNPM_EXPECTED!-win32-x64"
if exist "!PNPM_TARGET!\pnpm.exe" goto ensure_pnpm_found

echo   %ESC%[1;33m  .   pnpm !PNPM_EXPECTED! не найден - ставлю автоматически...%ESC%[0m
set "PNPM_ZIP=%TEMP%\pnpm-win32-x64.zip"
set "PNPM_URL=https://github.com/pnpm/pnpm/releases/download/v!PNPM_EXPECTED!/pnpm-win32-x64.zip"
if exist "!PNPM_ZIP!" del "!PNPM_ZIP!" >nul 2>&1
curl -L --max-time 180 -o "!PNPM_ZIP!" "!PNPM_URL!" >nul 2>&1
set "CURL_RC=!errorlevel!"
if not exist "!PNPM_ZIP!" (
    echo   %ESC%[1;33m  .   curl не скачал архив ^(код !CURL_RC!^), пробую PowerShell...%ESC%[0m
    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '!PNPM_URL!' -OutFile '!PNPM_ZIP!'" >nul 2>&1
)
if not exist "!PNPM_ZIP!" (
    echo   %ESC%[1;31m  x   архив pnpm не получен: !PNPM_URL!%ESC%[0m
    echo   %ESC%[2m       Проверьте доступ к github.com ^(VPN/прокси/файрвол^).%ESC%[0m
)
if exist "!PNPM_ZIP!" (
    if not exist "!PNPM_TARGET!" mkdir "!PNPM_TARGET!" >nul 2>&1
    powershell -NoProfile -Command "Expand-Archive -Path '!PNPM_ZIP!' -DestinationPath '!PNPM_TARGET!' -Force" >nul 2>&1
    del "!PNPM_ZIP!" >nul 2>&1
)

:ensure_pnpm_found
if exist "!PNPM_TARGET!\pnpm.exe" (
    set "PNPM_CMD=!PNPM_TARGET!\pnpm.exe"
) else (
    if defined NODE_DIR (
        if exist "!NODE_DIR!\npm.cmd" (
            echo   %ESC%[1;33m  .   архив недоступен - пробую npm install -g pnpm@!PNPM_EXPECTED!...%ESC%[0m
            call "!NODE_DIR!\npm.cmd" install -g "pnpm@!PNPM_EXPECTED!" >nul 2>&1
            if exist "!NODE_DIR!\pnpm.cmd" set "PNPM_CMD=!NODE_DIR!\pnpm.cmd"
        )
    )
)
if defined PNPM_CMD (
    set "PNPM_VER="
    for /f "delims=" %%v in ('"!PNPM_CMD!" --version 2^>nul') do set "PNPM_VER=%%v"
    if defined PNPM_VER (
        set "HAS_PNPM=1"
        for %%f in ("!PNPM_CMD!") do set "PNPM_DIR=%%~dpf"
        if defined PNPM_DIR set "PNPM_DIR=!PNPM_DIR:~0,-1!"
        echo   %ESC%[1;32m  +   pnpm !PNPM_VER! готов: !PNPM_CMD!%ESC%[0m
    )
)
if "!HAS_PNPM!"=="0" echo   %ESC%[1;31m  [ОШИБКА] pnpm поставить не удалось - нужен доступ к github.com или npm-реестру.%ESC%[0m
exit /b 0
