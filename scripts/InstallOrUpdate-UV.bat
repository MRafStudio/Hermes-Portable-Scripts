@REM scripts\InstallOrUpdate-UV.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Hermes Portable — Установка UV

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "UV_DIR=%HERMES_HOME%\bin"
set "UV_EXE=%UV_DIR%\uv.exe"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%HERMES_HOME%" mkdir "%HERMES_HOME%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                     %ESC%[1;37mHermes Portable%ESC%[0m   %ESC%[1;33m—%ESC%[0m   %ESC%[1;33mУстановка UV%ESC%[0m                     %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   ШАГ 1: Проверка существующей установки UV
REM ============================================================================
echo   %ESC%[1;33m[1/3]%ESC%[0m %ESC%[1mПроверка UV...%ESC%[0m

if exist "%UV_EXE%" (
    "%UV_EXE%" --version >nul 2>nul
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   UV уже установлен.%ESC%[0m
        set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
        for /f "delims=" %%v in ('"%UV_EXE%" --version 2^>nul') do echo %%v
        goto uv_done
    ) else (
        echo   %ESC%[1;33m  .   UV найден, но не работает. Переустановка...%ESC%[0m
        if exist "%UV_DIR%" rmdir /s /q "%UV_DIR%" 2>nul
    )
) else (
    echo   %ESC%[1;33m  →   UV не найден. Установка через pip...%ESC%[0m
)

REM ============================================================================
REM   ШАГ 2: Поиск Python
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/3]%ESC%[0m %ESC%[1mПоиск Python...%ESC%[0m

REM --- Сначала проверяем PYTHON_EXE от вызывающего скрипта ---
if defined PYTHON_EXE if exist "%PYTHON_EXE%" (
    echo   %ESC%[2m       Используется PYTHON_EXE от вызывающего скрипта%ESC%[0m
    goto :python_found
)

set "PYTHON_EXE="

REM --- 2a: Глобальный Python из PATH ---
for %%p in (python.exe python3.exe python311.exe python312.exe python313.exe) do (
    for /f "delims=" %%a in ('where %%p 2^>nul') do (
        set "PYTHON_EXE=%%a"
        goto :python_found
    )
)

REM --- 2b: Глобальный Python из ProgramFiles ---
for %%d in (
    "%ProgramFiles%\Python313"
    "%ProgramFiles%\Python312"
    "%ProgramFiles%\Python311"
    "%ProgramFiles(x86)%\Python313"
    "%ProgramFiles(x86)%\Python312"
    "%ProgramFiles(x86)%\Python311"
) do (
    if exist "%%d\python.exe" (
        set "PYTHON_EXE=%%d\python.exe"
        goto :python_found
    )
)

REM --- 2c: Портабельный Python из корня проекта ---
if exist "%ROOT_DIR%\python-3.11.9\python.exe" (
    set "PYTHON_EXE=%ROOT_DIR%\python-3.11.9\python.exe"
    goto :python_found
)

REM --- 2d: Портабельный Python из data\appdata (управляемый) ---
set "MANAGED_PYTHON=%APPDATA%\uv\python\cpython-3.11.15-windows-x86_64-none\python.exe"
if exist "%MANAGED_PYTHON%" (
    set "PYTHON_EXE=%MANAGED_PYTHON%"
    goto :python_found
)

:python_found
if not exist "%PYTHON_EXE%" (
    echo   %ESC%[1;33m  .   Python не найден. Запускаем InstallOrUpdate-Python.bat...%ESC%[0m
    call "%SCRIPTS_DIR%\InstallOrUpdate-Python.bat" 1
    if errorlevel 1 (
        echo   %ESC%[1;31m[ОШИБКА] Python не установлен%ESC%[0m
        goto error_exit
    )
    if not exist "%PYTHON_EXE%" (
        echo   %ESC%[1;31m[ОШИБКА] Python ne ustanovlen ^(InstallOrUpdate-Python.bat ne sozdal python.exe^)%ESC%[0m
        goto error_exit
    )
    echo   %ESC%[1;32m  +   Python установлен: %PYTHON_EXE%%ESC%[0m
)

echo   %ESC%[1;32m  +   Python найден: %PYTHON_EXE%%ESC%[0m
set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
for /f "delims=" %%v in ('"%PYTHON_EXE%" --version 2^>nul') do echo %%v

REM ============================================================================
REM   ШАГ 3: Установка UV через pip
REM ============================================================================
echo.
echo   %ESC%[1;33m[3/3]%ESC%[0m %ESC%[1mУстановка UV через pip...%ESC%[0m
echo   %ESC%[2m       Целевая папка: %UV_DIR%%ESC%[0m
echo   %ESC%[2m       ~27 МБ, подождите...%ESC%[0m

if not exist "%UV_DIR%" mkdir "%UV_DIR%" 2>nul

"%PYTHON_EXE%" -m pip install uv==0.11.28 --target "%UV_DIR%" --no-deps --upgrade

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] pip install uv не удался!%ESC%[0m
    echo   %ESC%[33m       Проверьте интернет-соединение.%ESC%[0m
    goto error_exit
)

REM --- Ищем uv.exe в target-папке ---
set "UV_EXE_FOUND="
if exist "%UV_DIR%\bin\uv.exe" set "UV_EXE_FOUND=%UV_DIR%\bin\uv.exe"
if exist "%UV_DIR%\Scripts\uv.exe" set "UV_EXE_FOUND=%UV_DIR%\Scripts\uv.exe"
if not defined UV_EXE_FOUND if exist "%UV_EXE%" set "UV_EXE_FOUND=%UV_EXE%"

if not defined UV_EXE_FOUND (
    echo   %ESC%[1;31m[ОШИБКА] uv.exe не найден после установки!%ESC%[0m
    echo   %ESC%[33m       Проверено: %UV_DIR%\bin\ и %UV_DIR%\Scripts\%ESC%[0m
    goto error_exit
)

echo   %ESC%[1;32m  +   UV установлен.%ESC%[0m
set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
for /f "delims=" %%v in ('"%UV_EXE_FOUND%" --version 2^>nul') do echo %%v

REM --- Копируем uv.exe в корень UV_DIR если он в подпапке ---
if /I not "!UV_EXE_FOUND!"=="%UV_EXE%" (
    copy /Y "!UV_EXE_FOUND!" "%UV_EXE%" >nul 2>nul
    if exist "%UV_EXE%" echo   %ESC%[2m       Скопирован в %UV_EXE%%ESC%[0m
)

:uv_done
echo.
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mUV готов!%ESC%[0m
echo   %ESC%[2m  Путь: %UV_EXE%%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
goto success_exit

REM ============================================================================
REM   ВЫХОДЫ
REM ============================================================================
:error_exit
echo.
echo   %ESC%[1;31m[ОШИБКА] Произошла ошибка! Нажмите любую клавишу...%ESC%[0m
pause >nul
exit /b 1

:success_exit
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0
