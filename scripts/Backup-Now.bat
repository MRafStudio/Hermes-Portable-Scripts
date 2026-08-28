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
exit /b 0
