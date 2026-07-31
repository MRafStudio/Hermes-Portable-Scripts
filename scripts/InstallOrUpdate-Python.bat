@REM scripts\InstallOrUpdate-Python.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Hermes Portable — Установка Python 3.11.15

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"

REM ============================================================================
REM   Путь к управляемому Python (куда uv ожидает)
REM   Именно сюда install.ps1 и uv ставят Python по умолчанию
REM   Приоритет: свежая 3.11.15, затем любая 3.11
REM ============================================================================
set "PYTHON_DIR="
set "PYTHON_EXE="
for /d %%d in ("%APPDATA%\uv\python\cpython-3.11.15*") do (
    if not defined PYTHON_EXE (
        if exist "%%d\python.exe" (
            set "PYTHON_DIR=%%d"
            set "PYTHON_EXE=%%d\python.exe"
        )
    )
)
if not defined PYTHON_EXE (
    for /d %%d in ("%APPDATA%\uv\python\cpython-3.11*") do (
        if not defined PYTHON_EXE (
            if exist "%%d\python.exe" (
                set "PYTHON_DIR=%%d"
                set "PYTHON_EXE=%%d\python.exe"
            )
        )
    )
)

REM ============================================================================
REM   Изоляция данных (ничего в систему!)
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"
set "PIP_CACHE_DIR=%DATA_DIR%\pip-cache"
set "PYTHONUSERBASE=%DATA_DIR%\python-user"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%APPDATA%" mkdir "%APPDATA%" 2>nul
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%HOME%\Desktop" mkdir "%HOME%\Desktop" 2>nul
if not exist "%PIP_CACHE_DIR%" mkdir "%PIP_CACHE_DIR%" 2>nul
if not exist "%PYTHONUSERBASE%" mkdir "%PYTHONUSERBASE%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

echo.
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m             %ESC%[1;37mPython 3.11.15 Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление%ESC%[0m            %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   [0/3] Проверка разрядности
REM ============================================================================
echo   %ESC%[1;33m[0/3]%ESC%[0m %ESC%[1mПроверка разрядности Windows...%ESC%[0m

set "ARCH_OK=0"
if "%PROCESSOR_ARCHITECTURE%"=="AMD64" set "ARCH_OK=1"
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" set "ARCH_OK=1"

if !ARCH_OK! equ 0 (
    echo   %ESC%[1;31m[ОШИБКА] Обнаружена 32-разрядная ^(x86^) Windows.%ESC%[0m
    goto error_exit
)
echo   %ESC%[1;32m  +   Система 64-разрядная ^(x64^).%ESC%[0m

REM ============================================================================
REM   Проверка существующего Python
REM ============================================================================
echo.
echo   %ESC%[1;33m[1/3]%ESC%[0m %ESC%[1mПроверка Python...%ESC%[0m

set "PYTHON_OK=0"

if exist "%PYTHON_EXE%" (
    "%PYTHON_EXE%" --version >nul 2>nul
    if !errorlevel! equ 0 (
        "%PYTHON_EXE%" -m pip --version >nul 2>nul
        if !errorlevel! equ 0 (
            set "PYTHON_OK=1"
        ) else (
            echo   %ESC%[1;33m  .   Python найден, но pip не работает. Переустановка...%ESC%[0m
        )
    ) else (
        echo   %ESC%[1;33m  .   Python найден, но не работает. Переустановка...%ESC%[0m
    )
)

if "!PYTHON_OK!"=="1" (
    echo   %ESC%[1;32m  +   Python уже установлен.%ESC%[0m
    set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
    "%PYTHON_EXE%" --version 2>nul
    echo.
    goto success_exit
)

if exist "%PYTHON_DIR%" (
    echo   %ESC%[1;33m  .   Удаление повреждённой установки...%ESC%[0m
    rmdir /s /q "%PYTHON_DIR%"
)

REM ============================================================================
REM   [2/3] Установка Python через uv
REM   (uv-сборки! python.org НЕ имеет 3.11.15 — только до 3.11.9)
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/3]%ESC%[0m %ESC%[1mУстановка Python 3.11.15 через uv...%ESC%[0m
echo   %ESC%[2m       ~30 МБ, подождите...%ESC%[0m

REM Определяем uv: HERMES_HOME\bin → scripts\bin
set "UV_EXE=%HERMES_HOME%\bin\uv.exe"
if not exist "%UV_EXE%" set "UV_EXE=%SCRIPTS_DIR%\bin\uv.exe"
if not exist "%UV_EXE%" (
    echo   %ESC%[1;31m[ОШИБКА] uv.exe не найден%ESC%[0m
    goto error_exit
)

REM Ставим в ИЗОЛИРОВАННЫЙ каталог (uv на Windows берёт AppData через WinAPI!)
set "UV_PYTHON_INSTALL_DIR=%APPDATA%\uv\python"

"%UV_EXE%" python install 3.11.15
if !errorlevel! neq 0 (
    echo   %ESC%[1;33m  .   3.11.15 недоступна, пробуем 3.11...%ESC%[0m
    "%UV_EXE%" python install 3.11
)
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось установить Python через uv%ESC%[0m
    goto error_exit
)

REM Обновляем PYTHON_DIR/PYTHON_EXE после установки (приоритет 3.11.15)
set "PYTHON_DIR="
set "PYTHON_EXE="
for /d %%d in ("%APPDATA%\uv\python\cpython-3.11.15*") do (
    if not defined PYTHON_EXE (
        if exist "%%d\python.exe" (
            set "PYTHON_DIR=%%d"
            set "PYTHON_EXE=%%d\python.exe"
        )
    )
)
if not defined PYTHON_EXE (
    for /d %%d in ("%APPDATA%\uv\python\cpython-3.11*") do (
        if not defined PYTHON_EXE (
            if exist "%%d\python.exe" (
                set "PYTHON_DIR=%%d"
                set "PYTHON_EXE=%%d\python.exe"
            )
        )
    )
)
if not defined PYTHON_EXE (
    echo   %ESC%[1;31m[ОШИБКА] Python не найден после установки.%ESC%[0m
    goto error_exit
)

echo   %ESC%[1;32m  +   Python установлен: %PYTHON_EXE%%ESC%[0m
set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
"%PYTHON_EXE%" --version 2>nul

REM ============================================================================
REM   [3/3] Установка pip (ensurepip → get-pip.py fallback)
REM ============================================================================
echo.
echo   %ESC%[1;33m[3/3]%ESC%[0m %ESC%[1mУстановка pip...%ESC%[0m

"%PYTHON_EXE%" -m ensurepip --upgrade --default-pip
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  +   pip установлен через ensurepip.%ESC%[0m
    goto pip_done
)

echo   %ESC%[1;33m  .   ensurepip не сработал, пробуем get-pip.py...%ESC%[0m
echo   %ESC%[2m       ~2 МБ, подождите...%ESC%[0m

REM --- Загрузка get-pip.py (curl / PowerShell fallback) ---
where curl >nul 2>nul
if !errorlevel! equ 0 (
    curl -L -o "%TEMP%\get-pip.py" "https://bootstrap.pypa.io/get-pip.py"
    if errorlevel 1 goto :dl_failed_pip
) else (
    powershell -NoProfile -Command "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%TEMP%\get-pip.py'"
    if errorlevel 1 goto :dl_failed_pip
)
goto :dl_ok_pip
:dl_failed_pip
echo   %ESC%[1;31m  [ОШИБКА] Не удалось загрузить get-pip.py.%ESC%[0m
goto pip_done
:dl_ok_pip

"%PYTHON_EXE%" "%TEMP%\get-pip.py" --no-warn-script-location
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  +   pip установлен через get-pip.py.%ESC%[0m
) else (
    echo   %ESC%[1;31m  [ОШИБКА] get-pip.py не сработал.%ESC%[0m
)
del "%TEMP%\get-pip.py" 2>nul

:pip_done
"%PYTHON_EXE%" -m pip --version >nul 2>nul
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] pip не удалось установить%ESC%[0m
    echo   %ESC%[33m       Python установлен, но без pip.%ESC%[0m
    echo   %ESC%[33m       Вручную: %PYTHON_EXE% -m ensurepip --upgrade%ESC%[0m
    goto error_exit
)

echo   %ESC%[1;32m  +   pip готов.%ESC%[0m
set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
for /f "delims=" %%v in ('"%PYTHON_EXE%" -m pip --version 2^>nul') do echo %%v

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
echo.
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mPython 3.11.15 успешно установлен!%ESC%[0m
echo   %ESC%[2m  Путь: %PYTHON_DIR%%ESC%[0m
echo   %ESC%[2m  Изоляция: %DATA_DIR%%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m

if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0
