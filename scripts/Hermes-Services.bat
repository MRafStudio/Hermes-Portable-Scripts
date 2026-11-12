@REM scripts\Hermes-Services.bat
@REM Обязательная остановка/запуск служб инстанса Hermes вокруг обновления.
@REM Вызов: call "%SCRIPTS_DIR%\Hermes-Services.bat" stop|start|status
@REM Возврат: 0 — действие выполнено и проверено, 1 — не удалось.
@REM Без остановки службы держат venv\Scripts\*.exe: uv падает с os error 32,
@REM а rmdir оставляет нерабочее окружение. UAC запрашивается автоматически.
@echo off
chcp 65001 >nul
setlocal

for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "ACTION=%~1"
if not defined ACTION set "ACTION=status"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ps1\hermes-services.ps1" -Action "%ACTION%" -RootDir "%ROOT_DIR%"
exit /b %errorlevel%
