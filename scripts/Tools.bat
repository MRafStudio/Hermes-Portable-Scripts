@REM scripts\Tools.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Инструменты

REM ============================================================================
REM   Корректное определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"

set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "DESKTOP_DIR=%REPO_DIR%\apps\desktop"
set "HERMES_EXE=%DESKTOP_DIR%\release\win-unpacked\Hermes.exe"
set "DATA_DIR=%ROOT_DIR%\data"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul

REM ============================================================================
REM   Получение ESC (стандартный трюк, без PowerShell)
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

:menu
cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                      Hermes%ESC%[0m — %ESC%[1;33mИнструменты пользователя%ESC%[0m                    %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mСравнить/изменить файлы RU локализации%ESC%[0m %ESC%[2m— WinMerge: en.ts vs ru.ts%ESC%[0m
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mОткрыть файл .env%ESC%[0m %ESC%[2m— %HERMES_HOME%\.env%ESC%[0m
echo   %ESC%[1;37m[3]%ESC%[0m %ESC%[1mОткрыть файл config.yaml%ESC%[0m %ESC%[2m— %HERMES_HOME%\config.yaml%ESC%[0m
echo.
echo   %ESC%[1;37m[4]%ESC%[0m %ESC%[1mЗапустить KoboldCpp (ОТЛАДКА)%ESC%[0m %ESC%[2m— окно остаётся открытым (cmd /k)%ESC%[0m
echo   %ESC%[1;37m[5]%ESC%[0m %ESC%[1mПересобрать Hermes Desktop и запустить%ESC%[0m %ESC%[2m— Пересборка с RU локализацией%ESC%[0m
echo.
echo   %ESC%[1;37m[8]%ESC%[0m %ESC%[1;31mОчистить репозиторий%ESC%[0m %ESC%[2m— Удалить hermes-agent (данные сохраняются)%ESC%[0m
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo.

set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-5, 8): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" goto exit
if "%choice%"=="1" goto compare_locale_en
if "%choice%"=="2" goto open_env
if "%choice%"=="3" goto open_config_yaml
if "%choice%"=="4" goto debug_kobold
if "%choice%"=="5" goto build_desktop
if "%choice%"=="8" goto clean_hermes_repo
goto menu

REM ============================================================================
REM   [1] Сравнить файлы локализации — WinMerge: en.ts vs ru.ts
REM ============================================================================
:compare_locale_en
cls
echo.
echo   %ESC%[1;33mСравнение файлов локализации...%ESC%[0m
echo.

set "EN_FILE=%SCRIPTS_DIR%\en-locale\en.ts"
set "RU_FILE=%SCRIPTS_DIR%\ru-locale\ru.ts"

REM Проверяем наличие файлов
if not exist "%EN_FILE%" (
    echo   %ESC%[1;31m[ОШИБКА] Файл не найден: %EN_FILE%%ESC%[0m
    echo   %ESC%[33m       Сначала запустите InstallOrUpdate-RU.bat для загрузки en.ts%ESC%[0m
    echo.
    pause
    goto menu
)

if not exist "%RU_FILE%" (
    echo   %ESC%[1;31m[ОШИБКА] Файл не найден: %RU_FILE%%ESC%[0m
    echo   %ESC%[33m       Убедитесь, что ru.ts находится в scripts\ru-locale\%ESC%[0m
    echo.
    pause
    goto menu
)

REM Ищем WinMerge
set "WINMERGE_EXE="
if exist "C:\Program Files\WinMerge\WinMergeU.exe" (
    set "WINMERGE_EXE=C:\Program Files\WinMerge\WinMergeU.exe"
) else if exist "C:\Program Files (x86)\WinMerge\WinMergeU.exe" (
    set "WINMERGE_EXE=C:\Program Files (x86)\WinMerge\WinMergeU.exe"
)

if not defined WINMERGE_EXE (
    echo   %ESC%[1;31m[ОШИБКА] WinMerge не найден%ESC%[0m
    echo   %ESC%[33m       Установите WinMerge: https://winmerge.org/%ESC%[0m
    echo.
    echo   %ESC%[2m       Или откройте файлы вручную:%ESC%[0m
    echo   %ESC%[2m         %EN_FILE%%ESC%[0m
    echo   %ESC%[2m         %RU_FILE%%ESC%[0m
    echo.
    pause
    goto menu
)

echo   %ESC%[1;32m  +   WinMerge найден: %WINMERGE_EXE%%ESC%[0m
echo   %ESC%[2m       en.ts: %EN_FILE%%ESC%[0m
echo   %ESC%[2m       ru.ts: %RU_FILE%%ESC%[0m
echo.

start "" "%WINMERGE_EXE%" "%EN_FILE%" "%RU_FILE%"

goto menu

REM ============================================================================
REM   [2] Открыть файл .env
REM ============================================================================
:open_env
cls
echo.
echo   %ESC%[1;33mОткрытие .env...%ESC%[0m
echo.

set "ENV_FILE=%HERMES_HOME%\.env"

if not exist "%ENV_FILE%" (
    echo   %ESC%[1;31m[ОШИБКА] Файл не найден: %ENV_FILE%%ESC%[0m
    echo   %ESC%[33m       Сначала выполните установку Hermes.%ESC%[0m
    echo.
    pause
    goto menu
)

call :find_editor

echo   %ESC%[1;32m  +   Открываем: %ENV_FILE%%ESC%[0m
echo.

start "" "%EDITOR_EXE%" "%ENV_FILE%"

goto menu

REM ============================================================================
REM   [3] Открыть файл config.yaml
REM ============================================================================
:open_config_yaml
cls
echo.
echo   %ESC%[1;33mОткрытие config.yaml...%ESC%[0m
echo.

set "CONFIG_YAML=%HERMES_HOME%\config.yaml"

if not exist "%CONFIG_YAML%" (
    echo   %ESC%[1;31m[ОШИБКА] Файл не найден: %CONFIG_YAML%%ESC%[0m
    echo   %ESC%[33m       Сначала выполните установку Hermes.%ESC%[0m
    echo.
    pause
    goto menu
)

call :find_editor

echo   %ESC%[1;32m  +   Открываем: %CONFIG_YAML%%ESC%[0m
echo.

start "" "%EDITOR_EXE%" "%CONFIG_YAML%"

goto menu

REM ============================================================================
REM   [4] Запустить KoboldCpp (ОТЛАДКА — cmd /k, окно остаётся открытым)
REM ============================================================================
:debug_kobold
cls
echo.
echo   %ESC%[1;33mОтладочный запуск KoboldCpp...%ESC%[0m
echo.
echo   %ESC%[1;33m  i   Окно консоли НЕ закроется после завершения KoboldCpp (cmd /k).%ESC%[0m
echo   %ESC%[1;33m  i   Режим для чтения логов и поиска ошибок. Продакшн-запуск — из главного меню.%ESC%[0m
echo.

call "%SCRIPTS_DIR%\Start-Kobold.bat" start 0 1
if %errorlevel% lss 0 (
    echo.
    echo   %ESC%[1;31m  [ОШИБКА] KoboldCpp не был запущен.%ESC%[0m
    echo.
    pause
)
goto menu

REM ============================================================================
REM   [5] Собрать новый Hermes Desktop
REM ============================================================================
:build_desktop
cls
echo.
echo   %ESC%[1;33mСборка Hermes Desktop...%ESC%[0m
echo.

echo   %ESC%[1;33m  i   Будет выполнена ПЕРЕСБОРКА с текущими изменениями.%ESC%[0m
echo.
set "confirm="
set /p "confirm=%ESC%[33mПродолжить? (y/n): %ESC%[0m"
if /I not "%confirm%"=="y" (
    echo   %ESC%[1;33mОтменено.%ESC%[0m
    pause
    goto menu
)

call "%SCRIPTS_DIR%\Rebuild-Desktop.bat" 1
if errorlevel 1 (
    echo   %ESC%[1;31m  [ОШИБКА] Сборка не удалась.%ESC%[0m
	pause
) else (
    echo   %ESC%[1;32m  +   Сборка завершена успешно%ESC%[0m
)
goto menu

REM ============================================================================
REM   [8] Очистить репозиторий
REM ============================================================================
:clean_hermes_repo
cls
echo.
echo  %ESC%[1;31m################################################################################%ESC%[0m
echo  %ESC%[1;31m##                                                                            ##%ESC%[0m
echo  %ESC%[1;31m##%ESC%[0m %ESC%[1;37m                   ВНИМАНИЕ - РЕПОЗИТОРИЙ БУДЕТ УДАЛЁН%ESC%[0m                      %ESC%[1;31m##%ESC%[0m
echo  %ESC%[1;31m##                                                                            ##%ESC%[0m
echo  %ESC%[1;31m################################################################################%ESC%[0m
echo.
echo   %ESC%[1;31mБудет удалено:%ESC%[0m
echo     %ESC%[1;31m- %ESC%[0m %REPO_DIR%
echo.
echo   %ESC%[1;32mСохранится:%ESC%[0m
echo     %ESC%[1;32m+ %ESC%[0m %HERMES_HOME% (без hermes-agent)
echo     %ESC%[1;32m+ %ESC%[0m Все конфиги, кэши, логи
echo.
echo   %ESC%[1;33mВведите DELETE для подтверждения:%ESC%[0m
set "confirm="
set /p "confirm=%ESC%[33m> %ESC%[0m"
if /I not "%confirm%"=="DELETE" (
    echo   %ESC%[1;33mОтменено.%ESC%[0m
    pause
    goto menu
)

echo.
echo   %ESC%[1;33mУдаление репозитория...%ESC%[0m

if exist "%REPO_DIR%" (
    rmdir /s /q "%REPO_DIR%"
    echo   %ESC%[1;32m  +   Репозиторий удалён: %REPO_DIR%%ESC%[0m
) else (
    echo   %ESC%[1;33m  .   Репозиторий не найден.%ESC%[0m
)

echo.
echo   %ESC%[1;32mГотово. Запустите установку заново через главное меню.%ESC%[0m
echo.
pause
goto menu

REM ============================================================================
REM   Подпрограмма: поиск Notepad++ (результат в EDITOR_EXE)
REM   LOCALAPPDATA здесь НЕ изолирован — читаем реальный профиль, это верно.
REM ============================================================================
:find_editor
set "EDITOR_EXE="
if exist "%ProgramFiles%\Notepad++\notepad++.exe" (
    set "EDITOR_EXE=%ProgramFiles%\Notepad++\notepad++.exe"
) else if exist "%ProgramFiles(x86)%\Notepad++\notepad++.exe" (
    set "EDITOR_EXE=%ProgramFiles(x86)%\Notepad++\notepad++.exe"
) else if exist "%LOCALAPPDATA%\Programs\Notepad++\notepad++.exe" (
    set "EDITOR_EXE=%LOCALAPPDATA%\Programs\Notepad++\notepad++.exe"
)

if not defined EDITOR_EXE (
    echo   %ESC%[1;33m  ⚠  Notepad++ не найден. Используем стандартный Notepad.%ESC%[0m
    set "EDITOR_EXE=notepad"
) else (
    echo   %ESC%[1;32m  +   Notepad++ найден: %EDITOR_EXE%%ESC%[0m
)
exit /b 0

:exit
exit /b 0