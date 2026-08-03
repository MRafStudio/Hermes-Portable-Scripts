@REM scripts\Find-Hermes-Service.bat
@REM Ищет службу Hermes*, принадлежащую ЭТОМУ инстансу (описание содержит ROOT_DIR).
@REM Использование: call "%~dp0Find-Hermes-Service.bat" "%ROOT_DIR%"
@REM Результат: переменная SERVICE_NAME (имя службы или пусто) в вызывающем скрипте.
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "ROOT_DIR=%~1"
set "FOUND="

for /f "tokens=1* delims=:" %%s in ('sc query state^= all 2^>nul ^| findstr /i "SERVICE_NAME:.*Hermes"') do (
    if not defined FOUND (
        REM %%t = всё после первого ":" (имя может содержать пробелы и ":" в пути!)
        set "SN=%%t"
        if defined SN set "SN=!SN:~1!"
        REM Ищем путь инстанса в описании (ключ вывода локализован: SERVICE_DESCRIPTION / ОПИСАНИЕ_СЛУЖБЫ — ищем по пути!)
        for /f "usebackq delims=" %%d in (`sc qdescription "!SN!" 2^>nul ^| findstr /c:"%ROOT_DIR%"`) do (
            set "FOUND=!SN!"
        )
    )
)

endlocal & set "SERVICE_NAME=%FOUND%"
