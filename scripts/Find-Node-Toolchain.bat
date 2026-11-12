@REM scripts\Find-Node-Toolchain.bat
@REM Единая точка выбора Node.js (>=26) и pnpm (12.x) для hermes-agent.
@REM Вызов: call "%SCRIPTS_DIR%\Find-Node-Toolchain.bat" ["<HERMES_HOME>\tools"]
@REM Возвращает в вызывающий скрипт: HAS_NODE, NODE_CMD, NODE_DIR, NODE_VER, NODE_MAJOR,
@REM NODE_TOO_OLD, IS_GLOBAL_NODE, NPM_CMD, NPX_CMD,
@REM HAS_PNPM, PNPM_CMD, PNPM_VER, PNPM_EXPECTED.
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
REM   pnpm: портативный из tools -> pnpm.exe в PATH
REM ============================================================================
set "PNPM_CMD="
set "PNPM_DIR="
set "PNPM_VER="
set "HAS_PNPM=0"

if exist "%TOOLS_DIR%\pnpm-!PNPM_EXPECTED!-win32-x64\pnpm.exe" set "PNPM_CMD=%TOOLS_DIR%\pnpm-!PNPM_EXPECTED!-win32-x64\pnpm.exe"
if not defined PNPM_CMD (
    for /d %%d in ("%TOOLS_DIR%\pnpm-*") do (
        if exist "%%~fd\pnpm.exe" set "PNPM_CMD=%%~fd\pnpm.exe"
    )
)
if not defined PNPM_CMD (
    for /f "delims=" %%p in ('where pnpm.exe 2^>nul') do (
        if not defined PNPM_CMD set "PNPM_CMD=%%p"
    )
)
if defined PNPM_CMD (
    for %%f in ("!PNPM_CMD!") do set "PNPM_DIR=%%~dpf"
    if defined PNPM_DIR set "PNPM_DIR=!PNPM_DIR:~0,-1!"
    for /f "delims=" %%v in ('"!PNPM_CMD!" --version 2^>nul') do set "PNPM_VER=%%v"
)
if defined PNPM_VER set "HAS_PNPM=1"

REM ============================================================================
REM   Node.js: портативный из tools -> локальный -> глобальный
REM   Портативный в приоритете: его версия закреплена самим Hermes (tools\node-*),
REM   а глобальный Node на машине может отставать от engines.node >=26.
REM ============================================================================
set "NODE_CMD="
set "NODE_DIR="
set "NODE_VER="
set "NODE_MAJOR=0"
set "NODE_TOO_OLD=0"
set "IS_GLOBAL_NODE=0"
set "GLOBAL_NODE="
set "CAND="

set "BEST_MAJOR=0"
set "BEST_MINOR=0"

REM Версия в tools выбирается численно, а не по алфавиту: строкой 26.12.1 < 26.7.0,
REM хотя 26.12.1 новее. Без этого выбрался бы устаревший Node.
set "TAKE=0"
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
if not defined CAND if exist "%HERMES_HOME%\node\node.exe" set "CAND=%HERMES_HOME%\node\node.exe"
if not defined CAND (
    if exist "%ProgramFiles%\nodejs\node.exe" (
        set "CAND=%ProgramFiles%\nodejs\node.exe"
        set "IS_GLOBAL_NODE=1"
    )
)
if not defined CAND (
    for /f "skip=2 tokens=1,2*" %%a in ('reg query "HKLM\SOFTWARE\Node.js" /v InstallPath 2^>nul') do (
        if "%%a"=="InstallPath" if exist "%%c\node.exe" (
            set "CAND=%%c\node.exe"
            set "IS_GLOBAL_NODE=1"
        )
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
    set "PATH=%PATH%"
)
