REM scripts\SmartPause.bat
@echo off
chcp 65001 >nul

REM ============================================================================
REM   SmartPause.bat — авто-продолжение с возможностью остановки
REM   Вызов: call SmartPause.bat [время_сек] [сообщение]
REM   Параметры:
REM     1 — время ожидания в секундах (1-10, по умолчанию 5)
REM     2 — сообщение (по умолчанию "Авто-продолжение через N сек...")
REM   Без параметров — дефолт: 5 сек, стандартное сообщение
REM ============================================================================

if not defined ESC (
    for /f %%a in ('powershell -NoProfile -Command "Write-Host ([char]27) -NoNewline"') do set "ESC=%%a"
)

set "SP_TIME=5"
set "SP_MSG="

set "SP_TEST=%~1"

REM Если параметр пустой — используем дефолт
if "%SP_TEST%"=="" (
    set "SP_MSG=Авто-продолжение через 5 сек..."
    goto sp_run
)

set "SP_NUMERIC=1"
for /f "delims=0123456789" %%a in ("%SP_TEST%") do set "SP_NUMERIC=0"

if "%SP_NUMERIC%"=="1" (
    set "SP_TIME=%SP_TEST%"
    set "SP_MSG=%~2"
) else (
    set "SP_MSG=%~1"
)

:sp_run
if %SP_TIME% lss 1 set "SP_TIME=1"
if %SP_TIME% gtr 10 set "SP_TIME=10"

if not defined SP_MSG (
    set "SP_MSG=Авто-продолжение через %SP_TIME% сек..."
)

echo.
echo   %ESC%[1;33m  →  %SP_MSG%%ESC%[0m
echo   %ESC%[2m       ^(нажмите любую клавишу для остановки^)%ESC%[0m

set "SP_TMP=%TEMP%\_sp_%RANDOM%.tmp"

set /a "SP_ITER=%SP_TIME% * 10"

(
    echo $k = $false
    echo for ^($i = 0; $i -lt %SP_ITER%; $i++^) {
    echo     if ^([Console]::KeyAvailable^) {
    echo         [Console]::ReadKey^($true^) ^| Out-Null
    echo         $k = $true
    echo         break
    echo     }
    echo     Start-Sleep -Milliseconds 100
    echo }
    echo $r = if ^($k^) { 'STOP' } else { 'CONT' }
    echo Out-File -FilePath '%SP_TMP%' -InputObject $r -Encoding ASCII
) > "%TEMP%\_sp_script.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\_sp_script.ps1"

set "SP_RESULT=CONT"
if exist "%SP_TMP%" (
    set /p "SP_RESULT=" < "%SP_TMP%"
    del "%SP_TMP%" 2>nul
    del "%TEMP%\_sp_script.ps1" 2>nul
)

if "%SP_RESULT%"=="STOP" (
    echo.
    echo   %ESC%[1;33m  Остановлено. Нажмите Enter для продолжения...%ESC%[0m
    pause >nul
)

exit /b 0