@REM scripts\Ensure-Dashboard-Token.bat — токен сервера (HERMES_DASHBOARD_SESSION_TOKEN)
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "TOKEN_FILE=%HERMES_HOME%\dashboard.token"

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

set "DASH_TOKEN="

if exist "%TOKEN_FILE%" (
    REM Токен уже сгенерирован ранее — используем его
    set /p "DASH_TOKEN=" < "%TOKEN_FILE%"
    echo   %ESC%[1;33m. %ESC%[0mИспользую сохранённый токен сервера.
) else (
    REM Токена нет — предлагаем сгенерировать или ввести свой
    echo   %ESC%[1;33m- %ESC%[0mТокен сервера для удалённого доступа ^(HERMES_DASHBOARD_SESSION_TOKEN^) не задан.
    set "GEN_CHOICE="
    set /p "GEN_CHOICE=%ESC%[33m  Сгенерировать случайный [Enter] или ввести свой [S]: %ESC%[0m"
    if /i "!GEN_CHOICE!"=="S" (
        set "DASH_TOKEN="
        set /p "DASH_TOKEN=%ESC%[33m  Введите токен: %ESC%[0m"
        if "!DASH_TOKEN!"=="" (
            echo   %ESC%[1;31m[ОШИБКА] Токен пуст — генерирую случайный.%ESC%[0m
            set "GEN_CHOICE="
        ) else (
            set "GEN_CHOICE=OK"
        )
    )
    if not "!GEN_CHOICE!"=="OK" (
        for /f "usebackq delims=" %%t in (`powershell -NoProfile -Command "[guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')"`) do set "DASH_TOKEN=%%t"
        echo   %ESC%[1;32m+ %ESC%[0mСгенерирован случайный токен.
    )
    > "%TOKEN_FILE%" echo !DASH_TOKEN!
    echo   %ESC%[1;32m+ %ESC%[0mТокен сохранён: %TOKEN_FILE%
)

echo   %ESC%[1;32m+ %ESC%[0mТокен сервера: %ESC%[1m!DASH_TOKEN!%ESC%[0m
echo   %ESC%[2m      Передайте его клиенту для удалённого подключения %ESC%[0m %ESC%[2m^(Desktop ^-^> Connection ^-^> Token^)%ESC%[0m
exit /b 0
