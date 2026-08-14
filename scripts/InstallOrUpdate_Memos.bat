@REM scripts\InstallOrUpdate_Memos.bat — MemOS: установка / обновление / проверка
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title MemOS — память агента

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "DATA_DIR=%ROOT_DIR%\data"
set "PY=%HERMES_HOME%\hermes-agent\venv\Scripts\python.exe"
set "MEMOS_HOME=%HERMES_HOME%\memos-plugin"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
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

REM ============================================================================
REM   Получение ESC (стандартный трюк, без PowerShell)
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Статус MemOS
REM ============================================================================
:status
set "MEMOS_INSTALLED=0"
set "MEMOS_VERSION=?"
if exist "%HERMES_HOME%\memos-plugin\package.json" (
    set "MEMOS_INSTALLED=1"
    for /f "usebackq tokens=2 delims=:, " %%v in (`findstr /c:"\"version\"" "%HERMES_HOME%\memos-plugin\package.json"`) do (
        set "MEMOS_VERSION=%%v"
        set "MEMOS_VERSION=!MEMOS_VERSION:"=!"
    )
)

REM ============================================================================
REM   Меню
REM ============================================================================
:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                         MemOS%ESC%[0m — %ESC%[1;33mпамять агента%ESC%[0m                       %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
if !MEMOS_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m MemOS %ESC%[2m^(v!MEMOS_VERSION!^)%ESC%[0m — память агента: установлен
) else (
    echo   %ESC%[1;33m. %ESC%[0m MemOS — память агента: не установлен
)
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mУстановить/Обновить MemOS%ESC%[0m
if !MEMOS_INSTALLED! equ 1 (
    echo       %ESC%[2mОбновление кода из npm: БД, настройки и модели сохраняются%ESC%[0m
) else (
    echo       %ESC%[2mПолная установка: L1/L2/L3 память, гибридный поиск, viewer :18800%ESC%[0m
)
echo.
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mПроверка и настройка%ESC%[0m
echo       %ESC%[2mСамопроверка, подъём viewer, кристаллизация DeepSeek (по желанию)%ESC%[0m
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-2): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" exit /b 0
if "%choice%"=="1" goto install_memos
if "%choice%"=="2" goto fix_memos
goto menu

REM ============================================================================
REM   [1] Установка / обновление MemOS
REM ============================================================================
:install_memos
cls
echo.
if !MEMOS_INSTALLED! equ 1 (
    echo %ESC%[1;33m-%ESC%[0m %ESC%[1mMemOS — обновление до актуальной версии из npm...%ESC%[0m
) else (
    echo %ESC%[1;33m-%ESC%[0m %ESC%[1mMemOS — полная установка...%ESC%[0m
)
echo.
echo %ESC%[2m  Источник: npm (@memtensor/memos-local-plugin, latest).%ESC%[0m
echo %ESC%[2m  Рефлексия LLM: кристаллизация через DeepSeek API (по желанию).%ESC%[0m
echo %ESC%[2m  Телеметрия отключена, 100%% локально.%ESC%[0m
echo.
echo %ESC%[33m  Убедитесь, что Hermes (служба/сессии) остановлен, иначе файлы залочены.%ESC%[0m
echo.
set "confirm="
set /p "confirm=%ESC%[33mПродолжить (y/N)? %ESC%[0m"
if /i not "%confirm%"=="y" goto menu

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps1\install-memos.ps1" -RootDir "%ROOT_DIR%"
if errorlevel 1 (
    echo.
    echo %ESC%[1;31m[ОШИБКА] Установка/обновление MemOS прервано — смотрите сообщения выше.%ESC%[0m
    echo.
    pause
    goto status
)

echo.
echo %ESC%[1;36mПроверка установки MemOS: memos-fix.ps1 (самопроверка + доустановка недостающего)...%ESC%[0m
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps1\memos-fix.ps1" -RootDir "%ROOT_DIR%"
if errorlevel 1 (
    echo.
    echo %ESC%[1;31m[ОШИБКА] Проблемы после установки MemOS — смотрите сообщения выше.%ESC%[0m
) else (
    echo.
    echo %ESC%[1;32mГотово. MemOS установлена, viewer работает на :18800.%ESC%[0m
)
echo.
pause
goto status

REM ============================================================================
REM   [2] Проверка и настройка MemOS
REM ============================================================================
:fix_memos
cls
echo.
echo %ESC%[1;36mПроверка установки MemOS: memos-fix.ps1 (самопроверка + доустановка недостающего)...%ESC%[0m
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\ps1\memos-fix.ps1" -RootDir "%ROOT_DIR%"
if errorlevel 1 (
    echo.
    echo %ESC%[1;31m[ОШИБКА] Проблемы с MemOS — смотрите сообщения выше.%ESC%[0m
) else (
    echo.
    echo %ESC%[1;32mMemOS в порядке.%ESC%[0m
)
echo.
pause
goto status
