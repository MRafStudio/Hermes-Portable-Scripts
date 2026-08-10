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

REM ============================================================================
REM   Параметры плагинов
REM ============================================================================
set "KCPP_DIR=%DATA_DIR%\kobold"
set "KCPP_EXE=%KCPP_DIR%\koboldcpp.exe"
set "MODELS_DIR=%KCPP_DIR%\models"
set "MODEL_BF16=Qwythos-9B-Claude-Mythos-5-1M-BF16.gguf"
set "MODEL_Q8=Qwythos-9B-Claude-Mythos-5-1M-Q8_0.gguf"
set "MMPROJ_FILE=mmproj-Qwythos-9B-Claude-Mythos-5-1M-F16.gguf"
set "SERVICE_NAME=KoboldCPP"

REM ============================================================================
REM   Статусы плагинов
REM ============================================================================
:status
set "KCPP_INSTALLED=0"
if exist "%KCPP_EXE%" set "KCPP_INSTALLED=1"

set "KCPP_MODEL="
if exist "%MODELS_DIR%\%MODEL_BF16%" set "KCPP_MODEL=BF16"
if exist "%MODELS_DIR%\%MODEL_Q8%" set "KCPP_MODEL=Q8_0"

set "SERVICE_INSTALLED=0"
sc query "%SERVICE_NAME%" >nul 2>&1
if not errorlevel 1 set "SERVICE_INSTALLED=1"

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
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                      Hermes%ESC%[0m — %ESC%[1;33mРасширения и плагины%ESC%[0m                 %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.
if !KCPP_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m KoboldCPP — установлен %ESC%[2m^(модель %KCPP_MODEL%^)%ESC%[0m
) else (
    echo   %ESC%[1;33m. %ESC%[0m KoboldCPP — не установлен
)
if !SERVICE_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m Служба KoboldCPP — установлена
) else (
    echo   %ESC%[1;33m. %ESC%[0m Служба KoboldCPP — не установлена
)
if !MEMOS_INSTALLED! equ 1 (
    echo   %ESC%[1;32m+ %ESC%[0m MemOS %ESC%[2m^(v!MEMOS_VERSION!^)%ESC%[0m — память агента: установлен
) else (
    echo   %ESC%[1;33m. %ESC%[0m MemOS — память агента: не установлен
)
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mKoboldCPP — установка/обновление%ESC%[0m
echo       %ESC%[2mЛокальная LLM ^(Qwythos BF16/Q8_0^): скачивание, настройка Hermes, порт 5101%ESC%[0m
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mСлужба KoboldCPP%ESC%[0m
if !SERVICE_INSTALLED! equ 1 (
    echo       %ESC%[2mУдалить службу ^(файлы сохраняются^)%ESC%[0m
) else (
    echo       %ESC%[2mАвтозапуск KoboldCPP при старте Windows%ESC%[0m
)
echo   %ESC%[1;37m[3]%ESC%[0m %ESC%[1mMemOS — память агента%ESC%[0m
if !MEMOS_INSTALLED! equ 1 (
    echo       %ESC%[2mОбновить до актуальной версии из npm ^(настройки сохраняются^)%ESC%[0m
) else (
    echo       %ESC%[2mУстановить: L1/L2/L3 память, гибридный поиск, viewer :18800%ESC%[0m
)
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-3): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" goto exit
if "%choice%"=="1" goto install_kobold
if "%choice%"=="2" goto kobold_service
if "%choice%"=="3" goto install_memos
goto menu

REM ============================================================================
REM   [1] KoboldCPP — установка / обновление
REM ============================================================================
:install_kobold
call "%SCRIPTS_DIR%\InstallOrUpdate-Kobold.bat"
goto status

REM ============================================================================
REM   [2] Служба KoboldCPP — установка / удаление
REM ============================================================================
:kobold_service
call "%SCRIPTS_DIR%\Kobold-Service.bat"
goto status

REM ============================================================================
REM   [3] MemOS — установка / обновление
REM ============================================================================
:install_memos
cls
echo.
echo %ESC%[1;33m-%ESC%[0m %ESC%[1mMemOS — память агента: установка / обновление...%ESC%[0m
echo.
echo %ESC%[2m  Источник: npm (@memtensor/memos-local-plugin, latest).%ESC%[0m
echo %ESC%[2m  Рефлексия LLM: локальный KoboldCPP http://127.0.0.1:5101/v1.%ESC%[0m
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
goto status

:exit
exit /b 0
