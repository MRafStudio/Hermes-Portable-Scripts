@REM scripts\InstallOrUpdate-Plugins.bat — Расширения и плагины Hermes Portable
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Расширения и плагины

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DATA_DIR=%ROOT_DIR%\data"

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

:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                      Hermes%ESC%[0m — %ESC%[1;33mРасширения и плагины%ESC%[0m                 %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Статус MemOS (memos-local-plugin)
REM ============================================================================
set "MEMOS_INSTALLED=0"
set "MEMOS_VERSION=?"
if exist "%HERMES_HOME%\memos-plugin\package.json" (
    set "MEMOS_INSTALLED=1"
    for /f "usebackq tokens=2 delims=:," %%v in ("%HERMES_HOME%\memos-plugin\package.json") do (
        set "LINE=%%v"
        set "LINE=!LINE: =!"
        if "!LINE:~0,8!"=="\"version\"" set "MEMOS_VERSION=!LINE:~9,-1!"
    )
)
if !MEMOS_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m MemOS %ESC%[2m^(v!MEMOS_VERSION!^)%ESC%[0m %ESC%[2m— память агента: установлен%ESC%[0m
) else (
    echo   %ESC%[1;33m. %ESC%[0m MemOS %ESC%[2m— память агента: не установлен%ESC%[0m
)
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mMemOS — память агента%ESC%[0m
if !MEMOS_INSTALLED! equ 1 (
    echo       %ESC%[2mОбновить до актуальной версии из npm (настройки сохраняются)%ESC%[0m
) else (
    echo       %ESC%[2mУстановить: L1/L2/L3 память, гибридный поиск, viewer :18800%ESC%[0m
)
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo.

set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-1): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" goto exit
if "%choice%"=="1" goto install_memos
goto menu

REM ============================================================================
REM   [1] MemOS — установка / обновление
REM ============================================================================
:install_memos
cls
echo.
echo %ESC%[1;33m-%ESC%[0m %ESC%[1mMemOS — память агента: установка / обновление...%ESC%[0m
echo.
echo %ESC%[2m  Источник: npm (@memtensor/memos-local-plugin, latest).%ESC%[0m
echo %ESC%[2m  Рефлексия LLM: локальный KoboldCPP http://127.0.0.1:5001/v1.%ESC%[0m
echo %ESC%[2m  Телеметрия отключена, 100%% локально.%ESC%[0m
echo.
echo %ESC%[33m  Убедитесь, что Hermes (служба/сессии) остановлен, иначе файлы залочены.%ESC%[0m
echo.

set "confirm="
set /p "confirm=%ESC%[33mПродолжить (y/N)? %ESC%[0m"
if /i not "%confirm%"=="y" goto menu

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\patch\install-memos.ps1" -RootDir "%ROOT_DIR%"
if errorlevel 1 (
    echo.
    echo %ESC%[1;31m[ОШИБКА] Установка не завершена — смотрите сообщения выше.%ESC%[0m
) else (
    echo.
    echo %ESC%[1;32mГотово. Проверка: при следующей сессии Hermes viewer откроется на :18800.%ESC%[0m
)
echo.
pause
goto menu

:exit
exit /b 0
