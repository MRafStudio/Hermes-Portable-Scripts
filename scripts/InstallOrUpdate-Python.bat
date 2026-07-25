@REM scripts\InstallOrUpdate-Python.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Hermes Portable — Установка Python 3.11.9

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"

REM ============================================================================
REM   Путь к портабельному Python (в корне проекта)
REM   install.ps1 позже обновит до 3.11.15 через uv
REM ============================================================================
set "PYTHON_DIR=%ROOT_DIR%\python-3.11.9"
set "PYTHON_EXE=%PYTHON_DIR%\python.exe"

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

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m             %ESC%[1;37mPython 3.11.9 Portable%ESC%[0m   —   %ESC%[1;33mУстановка / Обновление%ESC%[0m            %ESC%[1;36m##%ESC%[0m
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
    echo   %ESC%[1;31m[ОШИБКА] Обнаружена 32-разрядная (x86) Windows.%ESC%[0m
    goto error_exit
)
echo   %ESC%[1;32m  +   Система 64-разрядная (x64).%ESC%[0m

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
REM   [2/3] Загрузка Python 3.11.9
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/3]%ESC%[0m %ESC%[1mЗагрузка Python 3.11.9...%ESC%[0m
echo   %ESC%[2m       ~32 МБ, подождите...%ESC%[0m

if exist "%TEMP%\python-3.11.9-amd64.zip" del "%TEMP%\python-3.11.9-amd64.zip" 2>nul

REM --- Загрузка через curl с изоляцией ---
curl -L -o "%TEMP%\python-3.11.9-amd64.zip" "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.zip"
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось загрузить Python.%ESC%[0m
    goto error_exit
)
echo   %ESC%[1;32m  +   Загрузка завершена.%ESC%[0m

REM ============================================================================
REM   [2/3] Распаковка
REM ============================================================================
echo.
echo   %ESC%[1;33m[2/3]%ESC%[0m %ESC%[1mРаспаковка...%ESC%[0m

if exist "%PYTHON_DIR%" rmdir /s /q "%PYTHON_DIR%"
mkdir "%PYTHON_DIR%"

REM --- Приоритет: 7-Zip → PowerShell ---
echo   %ESC%[2m       Попытка распаковки через 7-Zip...%ESC%[0m

set "SEVENZIP="
where 7z >nul 2>nul
if !errorlevel! equ 0 (
    for /f "tokens=*" %%a in ('where 7z 2^>nul') do set "SEVENZIP=%%a"
)
if not defined SEVENZIP if exist "C:\Program Files\7-Zip\7z.exe" set "SEVENZIP=C:\Program Files\7-Zip\7z.exe"
if not defined SEVENZIP if exist "C:\Program Files (x86)\7-Zip\7z.exe" set "SEVENZIP=C:\Program Files (x86)\7-Zip\7z.exe"

if defined SEVENZIP (
    echo   %ESC%[2m       Найден 7-Zip: %SEVENZIP%%ESC%[0m
    "%SEVENZIP%" x "%TEMP%\python-3.11.9-amd64.zip" -o"%PYTHON_DIR%" -y >nul 2>&1
    if !errorlevel! equ 0 (
        echo   %ESC%[1;32m  +   Распаковка через 7-Zip завершена.%ESC%[0m
        goto unpack_done
    )
    echo   %ESC%[1;33m  .   7-Zip не справился. PowerShell fallback...%ESC%[0m
)

echo   %ESC%[2m       Распаковка через PowerShell...%ESC%[0m
powershell -NoProfile -Command "Expand-Archive -Path '%TEMP%\python-3.11.9-amd64.zip' -DestinationPath '%PYTHON_DIR%' -Force"
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ОШИБКА] Не удалось распаковать архив%ESC%[0m
    rmdir /s /q "%PYTHON_DIR%" 2>nul
    del "%TEMP%\python-3.11.9-amd64.zip" 2>nul
    goto error_exit
)
echo   %ESC%[1;32m  +   Распаковка через PowerShell завершена.%ESC%[0m

:unpack_done
del "%TEMP%\python-3.11.9-amd64.zip" 2>nul

echo   %ESC%[1;32m  +   Python распакован.%ESC%[0m
set /p "=%ESC%[2m       Версия: %ESC%[0m" <nul
"%PYTHON_EXE%" --version 2>nul

REM ============================================================================
REM   [3/3] Установка pip (ensurepip → get-pip.py fallback)
REM ============================================================================
echo.
echo   %ESC%[1;33m[3/3]%ESC%[0m %ESC%[1mУстановка pip...%ESC%[0m

"%PYTHON_EXE%" -m ensurepip --upgrade --default-pip >nul 2>&1
if !errorlevel! equ 0 (
    echo   %ESC%[1;32m  +   pip установлен через ensurepip.%ESC%[0m
    goto pip_done
)

echo   %ESC%[1;33m  .   ensurepip не сработал, пробуем get-pip.py...%ESC%[0m
echo   %ESC%[2m       ~2 МБ, подождите...%ESC%[0m

curl -L -o "%TEMP%\get-pip.py" "https://bootstrap.pypa.io/get-pip.py"
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m  [ОШИБКА] Не удалось загрузить get-pip.py.%ESC%[0m
    goto pip_done
)

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
echo   %ESC%[1;32mPython 3.11.9 успешно установлен!%ESC%[0m
echo   %ESC%[2m  Путь: %PYTHON_DIR%%ESC%[0m
echo   %ESC%[2m  Изоляция: %DATA_DIR%%ESC%[0m
echo  %ESC%[36m--------------------------------------------------------------------------------%ESC%[0m

if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0
