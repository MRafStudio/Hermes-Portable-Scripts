@echo off
REM Диагностика for /f llama_latest_asset (в контексте установщика!)
setlocal enabledelayedexpansion
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"
for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "PY=%REPO_DIR%\venv\Scripts\python.exe"

echo PY=[%PY%]
if exist "%PY%" (echo PY exists: YES) else (echo PY exists: NO)
echo SCRIPT=[%SCRIPTS_DIR%\py\llama_latest_asset.py]
if exist "%SCRIPTS_DIR%\py\llama_latest_asset.py" (echo SCRIPT exists: YES) else (echo SCRIPT exists: NO)

echo --- прямой вызов python (видно ошибку!):
"%PY%" "%SCRIPTS_DIR%\py\llama_latest_asset.py"
echo py_exit=%errorlevel%

echo --- for /f (как в установщике!):
set "LLAMA_ASSET="
for /f "delims=" %%a in ('""%PY%" "%SCRIPTS_DIR%\py\llama_latest_asset.py""') do set "LLAMA_ASSET=%%a"
echo ASSET=[%LLAMA_ASSET%]
echo done
