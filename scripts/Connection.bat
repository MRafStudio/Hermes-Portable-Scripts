@REM scripts\Connection.bat — параметры подключения и авторизации Hermes Portable
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

title Hermes — Параметры подключения

REM ============================================================================
REM   Определение путей
REM ============================================================================
set "SCRIPTS_DIR=%~dp0"
if "%SCRIPTS_DIR:~-1%"=="\" set "SCRIPTS_DIR=%SCRIPTS_DIR:~0,-1%"

for %%F in ("%SCRIPTS_DIR%\..") do set "ROOT_DIR=%%~fF"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "DATA_DIR=%ROOT_DIR%\data"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"
set "HERMES_EXE=%REPO_DIR%\venv\Scripts\hermes.exe"
set "START_INI=%HERMES_HOME%\portable_start.ini"

REM ============================================================================
REM   Изоляция PATH и данных
REM ============================================================================
set "PATH=%HERMES_HOME%\bin;%ProgramFiles%\Git\cmd;%windir%\system32;%windir%;%windir%\System32\Wbem;%windir%\System32\WindowsPowerShell\v1.0"
set "TEMP=%DATA_DIR%\temp"
set "TMP=%DATA_DIR%\temp"
set "APPDATA=%DATA_DIR%\appdata"
set "LOCALAPPDATA=%DATA_DIR%\localappdata"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Чтение параметров подключения из portable_start.ini
REM ============================================================================
set "CONSOLE=0"
set "REMOTE_HOST=127.0.0.1"
set "REMOTE_PORT=9119"
set "REMOTE_URL=http://127.0.0.1:9119"
if exist "%START_INI%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%START_INI%") do (
        if /i "%%a"=="CONSOLE" set "CONSOLE=%%b"
        if /i "%%a"=="REMOTE_HOST" set "REMOTE_HOST=%%b"
        if /i "%%a"=="REMOTE_PORT" set "REMOTE_PORT=%%b"
        if /i "%%a"=="REMOTE_URL" set "REMOTE_URL=%%b"
    )
)

REM ============================================================================
REM   Чтение параметров авторизации из config.yaml (через hermes config get)
REM ============================================================================
set "AUTH_USER="
set "AUTH_PASS="
if exist "%HERMES_EXE%" (
    for /f "usebackq delims=" %%u in (`%REPO_DIR%\venv\Scripts\python.exe -u %SCRIPTS_DIR%\py\get_basic_auth.py %HERMES_EXE% username`) do set "AUTH_USER=%%u"
    for /f "usebackq delims=" %%p in (`%REPO_DIR%\venv\Scripts\python.exe -u %SCRIPTS_DIR%\py\get_basic_auth.py %HERMES_EXE% password`) do set "AUTH_PASS=%%p"
)

:menu
cls
echo %ESC%[1;36m################################################################################%ESC%[0m
echo %ESC%[1;36m##%ESC%[0m                  %ESC%[1;37mHermes Portable%ESC%[0m — %ESC%[1;33mПараметры подключения%ESC%[0m                   %ESC%[1;36m##%ESC%[0m
echo %ESC%[1;36m################################################################################%ESC%[0m
echo.
echo   %ESC%[1;33mHERMES_HOME:%ESC%[0m %ESC%[2m%HERMES_HOME%%ESC%[0m
echo.
echo   %ESC%[1;33mПодключение:%ESC%[0m
echo     %ESC%[2mАдрес:     %ESC%[0m !REMOTE_HOST!
echo     %ESC%[2mПорт:      %ESC%[0m !REMOTE_PORT!
echo     %ESC%[2mURL:       %ESC%[0m !REMOTE_URL!
echo     %ESC%[2mКонсоль:   %ESC%[0m !CONSOLE! ^(1 — окно с логами^)
echo.
echo   %ESC%[1;33mАвторизация ^(dashboard.basic_auth^):%ESC%[0m
if defined AUTH_USER (
    echo     %ESC%[2mЛогин:    %ESC%[0m !AUTH_USER!
) else (
    echo     %ESC%[2mЛогин:    %ESC%[0m %ESC%[1;31mне задан%ESC%[0m
)
if defined AUTH_PASS (
    echo     %ESC%[2mПароль:   %ESC%[0m %ESC%[32mзадан ^(***^)%ESC%[0m
) else (
    echo     %ESC%[2mПароль:   %ESC%[0m %ESC%[1;31mне задан%ESC%[0m
)
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mИзменить параметры подключения%ESC%[0m
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mИзменить логин и пароль ^(локальный сервер^)%ESC%[0m
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите действие: %ESC%[0m"
if not "!choice!"=="" set "choice=!choice: =!"
if "!choice!"=="1" goto set_connection
if "!choice!"=="2" goto set_auth
if "!choice!"=="0" exit /b 0
goto menu

REM ============================================================================
REM   [1] Изменение параметров подключения
REM ============================================================================
:set_connection
cls
echo %ESC%[1;33mИзменение параметров подключения%ESC%[0m
echo.
echo   %ESC%[1;33m-%ESC%[0m Доступные адреса прослушивания:
echo   %ESC%[2m      [1] 0.0.0.0   — все адаптеры (по умолчанию, удалённый доступ)%ESC%[0m
echo   %ESC%[2m      [2] 127.0.0.1 — только локальный%ESC%[0m
set "IP_N=2"
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^169\.254' -and $_.IPAddress -notmatch '^127\.' } | Select-Object -ExpandProperty IPAddress)"`) do (
    set /a IP_N+=1
    set "IP_!IP_N!=%%i"
    echo   %ESC%[2m      [!IP_N!] %%i%ESC%[0m
)
echo   %ESC%[2m      [0] Ввести адрес вручную ^(сторонний сервер^)%ESC%[0m
set "REMOTE_HOST="
set "HOST_CHOICE="
set /p "HOST_CHOICE=%ESC%[1mВыберите адрес%ESC%[0m %ESC%[2m[Enter = 0.0.0.0]%ESC%[0m: "
if not "!HOST_CHOICE!"=="" set "HOST_CHOICE=!HOST_CHOICE: =!"
if "!HOST_CHOICE!"=="" set "REMOTE_HOST=0.0.0.0"
if "!HOST_CHOICE!"=="1" set "REMOTE_HOST=0.0.0.0"
if "!HOST_CHOICE!"=="2" set "REMOTE_HOST=127.0.0.1"
if "!HOST_CHOICE!"=="0" (
    set /p "REMOTE_HOST=%ESC%[1mАдрес сервера%ESC%[0m %ESC%[2m(IP или host, напр. 192.168.0.25)%ESC%[0m: "
    if not "!REMOTE_HOST!"=="" set "REMOTE_HOST=!REMOTE_HOST: =!"
)
if defined HOST_CHOICE if !HOST_CHOICE! GTR 2 (
    set "REMOTE_HOST="
    for %%x in (!HOST_CHOICE!) do if defined IP_%%x set "REMOTE_HOST=!IP_%%x!"
)
if "!REMOTE_HOST!"=="" (
    echo %ESC%[1;31m[ОШИБКА] Неверный выбор — подключение не изменено.%ESC%[0m
    echo.
    pause
    goto menu
)
set "REMOTE_PORT="
set /p "REMOTE_PORT=%ESC%[1mПорт%ESC%[0m %ESC%[2m[Enter = 9119]%ESC%[0m: "
if "!REMOTE_PORT!"=="" set "REMOTE_PORT=9119"
if not "!REMOTE_PORT!"=="" set "REMOTE_PORT=!REMOTE_PORT: =!"
set "REMOTE_URL=http://!REMOTE_HOST!:!REMOTE_PORT!"
if "!REMOTE_HOST!"=="0.0.0.0" set "REMOTE_URL=http://127.0.0.1:!REMOTE_PORT!"
echo.
set "CHECK="
set /p "CHECK=%ESC%[1mПроверить соединение%ESC%[0m %ESC%[2m(y/N)%ESC%[0m: "
if /i "!CHECK!"=="y" (
    echo %ESC%[1;33m- %ESC%[0mПроверяю доступность !REMOTE_HOST!:!REMOTE_PORT!...
    set "TCP_OK=False"
    for /f "usebackq delims=" %%r in (`powershell -NoProfile -Command "(Test-NetConnection -ComputerName '!REMOTE_HOST!' -Port !REMOTE_PORT! -WarningAction SilentlyContinue).TcpTestSucceeded"`) do set "TCP_OK=%%r"
    if /i "!TCP_OK!"=="False" (
        echo %ESC%[1;31m[ОШИБКА] Сервер !REMOTE_HOST!:!REMOTE_PORT! недоступен — параметры не сохранены.%ESC%[0m
        echo.
        pause
        goto menu
    )
    echo %ESC%[1;32m+ %ESC%[0mСервер доступен!
) else (
    echo %ESC%[1;33m. %ESC%[0mПроверка пропущена — сохраняю параметры.
)
> "%START_INI%" echo CONSOLE=!CONSOLE!
>> "%START_INI%" echo REMOTE_HOST=!REMOTE_HOST!
>> "%START_INI%" echo REMOTE_PORT=!REMOTE_PORT!
>> "%START_INI%" echo REMOTE_URL=!REMOTE_URL!
echo %ESC%[1;32m+ %ESC%[0mПараметры сохранены: %START_INI%
echo.
pause
goto menu

REM ============================================================================
REM   [2] Изменение логина и пароля
REM ============================================================================
:set_auth
cls
echo %ESC%[1;33mИзменение логина и пароля ^(dashboard.basic_auth^)%ESC%[0m
echo.
if not exist "%HERMES_EXE%" (
    echo %ESC%[1;31m[ОШИБКА] hermes.exe не найден: %HERMES_EXE%%ESC%[0m
    echo.
    pause
    goto menu
)
echo   %ESC%[2mНЕ используйте символы %%%% и ^!^! и пробелы.%ESC%[0m
set "NEW_USER="
set /p "NEW_USER=%ESC%[1mЛогин%ESC%[0m %ESC%[2m[Enter = !AUTH_USER!]%ESC%[0m: "
if not "!NEW_USER!"=="" set "NEW_USER=!NEW_USER: =!"
if "!NEW_USER!"=="" if defined AUTH_USER if not "!AUTH_USER!"=="" set "NEW_USER=!AUTH_USER!"
if "!NEW_USER!"=="" set "NEW_USER=admin"
"%REPO_DIR%\venv\Scripts\python.exe" "%SCRIPTS_DIR%\py\validate_credentials.py" "!NEW_USER!"
if errorlevel 1 (
    echo   %ESC%[1;31m  Логин содержит запрещённые символы (%%%% или ^!^! или пробел) - не изменён.%ESC%[0m
    goto menu
)
echo   %ESC%[2mНЕ используйте символы %%%% и ^!^! — раскрытие переменных cmd.%ESC%[0m
set "NEW_PASS="
set /p "NEW_PASS=%ESC%[1mПароль%ESC%[0m %ESC%[2m[Enter — без изменений]%ESC%[0m: "
if errorlevel 1 (
    echo   %ESC%[1;31m  Пароль содержит запрещённые символы (%%%% или ^!^!) — не изменён.%ESC%[0m
    goto menu
)
if not "!NEW_PASS!"=="" (
    "%REPO_DIR%\venv\Scripts\python.exe" "%SCRIPTS_DIR%\py\validate_credentials.py" "!NEW_PASS!"
    if errorlevel 1 (
        echo   %ESC%[1;31m  Пароль содержит запрещённые символы — не изменён.%ESC%[0m
        goto menu
    )
)
echo.
if not "!NEW_PASS!"=="" (
    "%HERMES_EXE%" config set dashboard.basic_auth.username "!NEW_USER!"
    "%HERMES_EXE%" config set dashboard.basic_auth.password "!NEW_PASS!"
    "%REPO_DIR%\venv\Scripts\python.exe" "%SCRIPTS_DIR%\py\update_ini_auth.py" "%START_INI%" "!NEW_USER!" "!NEW_PASS!"
    echo %ESC%[1;32m+ %ESC%[0mЛогин и пароль обновлены в config.yaml и portable_start.ini.
) else (
    "%HERMES_EXE%" config set dashboard.basic_auth.username "!NEW_USER!"
    echo %ESC%[1;32m+ %ESC%[0mЛогин обновлён в config.yaml ^(пароль без изменений^).
)
echo %ESC%[2m      Перезапустите сервер, чтобы изменения вступили в силу.%ESC%[0m
echo.
pause
goto menu
