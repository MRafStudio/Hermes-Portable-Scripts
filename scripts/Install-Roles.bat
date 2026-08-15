@echo off
REM scripts\Install-Roles.bat — инжекция ролей (scripts\roles\*.md) в config.yaml
chcp 65001 >nul
setlocal
set "SCRIPTS_DIR=%~dp0"
for %%i in ("%SCRIPTS_DIR%..") do set "ROOT_DIR=%%~fi"
set "PY=%ROOT_DIR%\data\hermes\hermes-agent\venv\Scripts\python.exe"
if not exist "%PY%" (
    echo [ОШИБКА] python не найден: %PY%
    pause
    exit /b 1
)
"%PY%" "%SCRIPTS_DIR%\py\install_roles.py" --root "%ROOT_DIR%" %*
echo.
pause
exit /b 0
