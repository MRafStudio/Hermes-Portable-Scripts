@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
REM scripts\Backup-Now.bat — бэкап перед обновлением (вызывается перед InstallOrUpdate-*.bat)
REM  1) hermes backup --quick -> state-snapshots\<ts>\ (config.yaml, .env, cron, БД)
REM  2) data\backup\<дата>\ -> копии config.yaml + запускаемые скрипты
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "DATA_DIR=%ROOT_DIR%\data"
set "HERMES_HOME=%DATA_DIR%\hermes"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"

echo   Бэкап перед обновлением...

REM 1) Нативный снапшот кастома
if exist "%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe" (
    "%HERMES_HOME%\hermes-agent\venv\Scripts\hermes.exe" backup --quick >nul 2>&1
    echo     hermes backup --quick ^(state-snapshots^)
)

REM 2) Наш бэкап: data\backup\<дата>\
for /f "delims=" %%d in ('powershell -NoProfile -Command "Get-Date -Format yyyy.MM.dd-HH-mm"') do set "BK=%%d"
set "BKDIR=%DATA_DIR%\backup\%BK%"
if not exist "%BKDIR%" mkdir "%BKDIR%" 2>nul
if exist "%HERMES_HOME%\config.yaml" copy /y "%HERMES_HOME%\config.yaml" "%BKDIR%\hermes-config.yaml" >nul 2>&1
if exist "%HERMES_HOME%\memos-plugin\config.yaml" copy /y "%HERMES_HOME%\memos-plugin\config.yaml" "%BKDIR%\memos-plugin-config.yaml" >nul 2>&1
if exist "%SCRIPTS_DIR%\InstallOrUpdate-Models.bat" copy /y "%SCRIPTS_DIR%\InstallOrUpdate-Models.bat" "%BKDIR%" >nul 2>&1
if exist "%SCRIPTS_DIR%\py\llama_models.py" copy /y "%SCRIPTS_DIR%\py\llama_models.py" "%BKDIR%" >nul 2>&1
echo     %BKDIR%

REM ============================================================================
REM   РОТАЦИЯ. hermes backup --quick копирует state.db целиком, а он бывает
REM   много-гигабайтным: без ротации снапшоты накапливаются десятками ГБ
REM   (у нас накопилось 38 ГБ). Держим только N последних.
REM   N можно передать параметром: Backup-Now.bat 3
REM ============================================================================
set "KEEP=2"
if not "%~1"=="" set "KEEP=%~1"

if exist "%HERMES_HOME%\state-snapshots" (
    powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%HERMES_HOME%\state-snapshots' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -Skip %KEEP% | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue"
)
if exist "%DATA_DIR%\backup" (
    powershell -NoProfile -Command "Get-ChildItem -LiteralPath '%DATA_DIR%\backup' -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -Skip %KEEP% | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue"
)
echo     хранение: последние !KEEP! снапшот(а)

REM state.db велик — снапшоты дорогие; подсказываем, чем уменьшить базу
if exist "%HERMES_HOME%\state.db" (
    for %%S in ("%HERMES_HOME%\state.db") do if %%~zS GTR 2147483648 (
        echo     ! state.db больше 2 ГБ: уменьшить — hermes sessions optimize-storage
    )
)

exit /b 0
