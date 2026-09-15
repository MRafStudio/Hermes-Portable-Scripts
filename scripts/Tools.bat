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
echo  %ESC%[1;36m##%ESC%[0m %ESC%[1;37m                      Hermes%ESC%[0m — %ESC%[1;33mИнструменты пользователя%ESC%[0m                    %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mСравнить ключи RU локализации%ESC%[0m %ESC%[2m— WinMerge: en.flat vs ru.flat%ESC%[0m
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mСравнить исходники en.ts vs ru.ts%ESC%[0m %ESC%[2m— WinMerge (прямое сравнение)%ESC%[0m
echo   %ESC%[1;37m[3]%ESC%[0m %ESC%[1mОткрыть файл .env%ESC%[0m %ESC%[2m— %HERMES_HOME%\.env%ESC%[0m
echo   %ESC%[1;37m[4]%ESC%[0m %ESC%[1mОткрыть файл config.yaml%ESC%[0m %ESC%[2m— %HERMES_HOME%\config.yaml%ESC%[0m
echo.
echo   %ESC%[1;37m[5]%ESC%[0m %ESC%[1mПересобрать Hermes Desktop и запустить%ESC%[0m %ESC%[2m— с бэкапом текущего рабочего состояния%ESC%[0m
echo   %ESC%[1;37m[6]%ESC%[0m %ESC%[1mОткатить русификацию к бэкапу%ESC%[0m %ESC%[2m— вернуть рабочие файлы и сборку%ESC%[0m
echo.
echo   %ESC%[1;37m[7]%ESC%[0m %ESC%[1;31mОчистить репозиторий%ESC%[0m %ESC%[2m— Удалить hermes-agent (данные сохраняются)%ESC%[0m
echo   %ESC%[1;37m[8]%ESC%[0m %ESC%[1mПроверка русификации%ESC%[0m %ESC%[2m— структура + esbuild + порядок (workflow)%ESC%[0m
echo.
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mНазад в главное меню%ESC%[0m
echo.
echo.

set "choice="
set /p "choice=%ESC%[33mВыберите действие (0-8): %ESC%[0m"
set "choice=%choice: =%"

if "%choice%"=="0" goto exit
if "%choice%"=="1" goto compare_locale_en
if "%choice%"=="2" goto compare_locale_ts
if "%choice%"=="3" goto open_env
if "%choice%"=="4" goto open_config_yaml
if "%choice%"=="5" goto build_desktop
if "%choice%"=="6" goto rollback_ru
if "%choice%"=="7" goto clean_hermes_repo
if "%choice%"=="8" goto verify_i18n
goto menu

REM ============================================================================
REM   [1] Сравнить ключи локализации — WinMerge: en.flat vs ru.flat
REM   Компаратор scripts\py\compare_i18n_keys.py строит нормализованные списки
REM   ключей ('ключ = текст', по алфавиту) — построчный диф становится осмысленным
REM   (прямое сравнение en.ts/ru.ts бессмысленно: разные форматы обёрток).
REM ============================================================================
:compare_locale_en
cls
echo.
echo   %ESC%[1;33mСравнение ключей локализации (en.ts эталон vs ru.ts перевод)...%ESC%[0m
echo.

set "EN_FILE=%SCRIPTS_DIR%\en-locale\en.ts"
set "RU_FILE=%SCRIPTS_DIR%\ru-locale\ru.ts"
set "COMPARE_PY=%SCRIPTS_DIR%\py\compare_i18n_keys.py"
set "COMPARE_DIR=%DATA_DIR%\temp\i18n-compare"

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

if not exist "%COMPARE_PY%" (
    echo   %ESC%[1;31m[ОШИБКА] Не найден компаратор ключей: %COMPARE_PY%%ESC%[0m
    echo.
    pause
    goto menu
)

REM Python: venv репозитория, иначе системный
set "PY_CMD="%REPO_DIR%\venv\Scripts\python.exe""
if not exist "%REPO_DIR%\venv\Scripts\python.exe" set "PY_CMD=python"

echo   %ESC%[1;33m  i   Строю нормализованные списки ключей...%ESC%[0m
echo.
%PY_CMD% "%COMPARE_PY%" --en "%EN_FILE%" --ru "%RU_FILE%" --flatten "%COMPARE_DIR%"
if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Не удалось построить списки ключей.%ESC%[0m
    echo.
    pause
    goto menu
)
echo.

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
    echo   %ESC%[2m       Списки ключей готовы — откройте вручную:%ESC%[0m
    echo   %ESC%[2m         %COMPARE_DIR%\en.flat     — эталон%ESC%[0m
    echo   %ESC%[2m         %COMPARE_DIR%\ru.flat     — перевод%ESC%[0m
    echo   %ESC%[2m         %COMPARE_DIR%\missing.flat — список для доперевода%ESC%[0m
    echo.
    pause
    goto menu
)

echo   %ESC%[1;32m  +   Открываю WinMerge: en.flat vs ru.flat%ESC%[0m
echo   %ESC%[2m       Непереведённые — строки, которые есть слева и отсутствуют справа%ESC%[0m
echo   %ESC%[2m       Список для доперевода: %COMPARE_DIR%\missing.flat%ESC%[0m
echo   %ESC%[2m       Перевод вписывать в: %RU_FILE%%ESC%[0m
echo   %ESC%[2m       После правок: InstallOrUpdate-RU.bat, затем [5] — пересборка Desktop%ESC%[0m
echo   %ESC%[1;33m  !   Строки идут 1:1 с en.ts (порядок ключей одинаковый):%ESC%[0m
echo   %ESC%[2m       справа сразу видно каждый непереведённый ключ%ESC%[0m
echo   %ESC%[2m       <НЕТ ПЕРЕВОДА> = строки нет в ru.ts — добавляйте её в scripts\ru-locale\ru.ts%ESC%[0m
echo.

start "" "%WINMERGE_EXE%" "%COMPARE_DIR%\en.flat" "%COMPARE_DIR%\ru.flat"

goto menu

REM ============================================================================
REM   [2] Сравнить исходники — WinMerge: en.ts vs ru.ts (прямое сравнение)
REM   Нужно потому, что сборщик копирует именно ru.ts в репозиторий Hermes:
REM   все изменённые строки обязаны попасть в ru.ts.
REM ============================================================================
:compare_locale_ts
cls
echo.
echo   %ESC%[1;33mСравнение исходников локализации ^(en.ts vs ru.ts^)...%ESC%[0m
echo.

set "EN_TS=%SCRIPTS_DIR%\en-locale\en.ts"
set "RU_TS=%SCRIPTS_DIR%\ru-locale\ru.ts"

if not exist "%EN_TS%" (
    echo   %ESC%[1;31m[ОШИБКА] Файл не найден: %EN_TS%%ESC%[0m
    echo   %ESC%[33m       Сначала запустите InstallOrUpdate-RU.bat для загрузки en.ts%ESC%[0m
    echo.
    pause
    goto menu
)

if not exist "%RU_TS%" (
    echo   %ESC%[1;31m[ОШИБКА] Файл не найден: %RU_TS%%ESC%[0m
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
    echo   %ESC%[2m         %EN_TS%%ESC%[0m
    echo   %ESC%[2m         %RU_TS%%ESC%[0m
    echo.
    pause
    goto menu
)

echo   %ESC%[1;32m  +   WinMerge найден: %WINMERGE_EXE%%ESC%[0m
echo   %ESC%[2m       en.ts: %EN_TS%%ESC%[0m
echo   %ESC%[2m       ru.ts: %RU_TS%%ESC%[0m
echo   %ESC%[1;33m  !   ru.ts должен получить все изменённые строки — именно его копирует сборщик.%ESC%[0m
echo.

start "" "%WINMERGE_EXE%" "%EN_TS%" "%RU_TS%"

goto menu

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
REM   [5] Собрать новый Hermes Desktop
REM ============================================================================
:build_desktop
cls
echo.
echo   %ESC%[1;33mСборка Hermes Desktop...%ESC%[0m
echo.

echo   %ESC%[1;33m  i   Перед сборкой будет сделан БЭКАП рабочего состояния:%ESC%[0m
echo   %ESC%[2m       - файлы локализации ^(scripts\ru-locale, i18n^)%ESC%[0m
echo   %ESC%[2m       - текущая готовая сборка ^(release^) — для отката пунктом [6]%ESC%[0m
echo.
set "confirm="
set /p "confirm=%ESC%[33mПродолжить? (y/n): %ESC%[0m"
if /I not "%confirm%"=="y" (
    echo   %ESC%[1;33mОтменено.%ESC%[0m
    pause
    goto menu
)

REM --- Hermes должен быть закрыт: иначе сборку (release) не сохранить ---
tasklist /FI "IMAGENAME eq Hermes.exe" 2>nul | findstr /I "Hermes.exe" >nul
if !errorlevel! equ 0 (
    echo.
    echo   %ESC%[1;33m  !   Hermes Desktop запущен.%ESC%[0m
    echo   %ESC%[2m       Для бэкапа сборки его нужно закрыть — иначе откат будет без сборки.%ESC%[0m
    set "killh="
    set /p "killh=%ESC%[33mЗакрыть Hermes сейчас? (y/n): %ESC%[0m"
    if /I "!killh!"=="y" (
        taskkill /IM Hermes.exe /F >nul 2>&1
        echo   %ESC%[1;32m  +   Hermes закрыт.%ESC%[0m
        call "%SCRIPTS_DIR%\SmartPause.bat" 2
    ) else (
        echo   %ESC%[1;33m  .   Продолжаем без сохранения сборки.%ESC%[0m
    )
)

set "BK_PY=%SCRIPTS_DIR%\py\ru_locale_backup.py"
set "PY_CMD="%REPO_DIR%\venv\Scripts\python.exe""
if not exist "%REPO_DIR%\venv\Scripts\python.exe" set "PY_CMD=python"

echo.
echo   %ESC%[1;33m  -   Бэкап рабочего состояния...%ESC%[0m
%PY_CMD% "%BK_PY%" backup --quiet
if errorlevel 2 (
    echo   %ESC%[1;33m  !   Сборка не сохранена — откат [6] вернёт только файлы локализации.%ESC%[0m
)

echo.
REM --- Проверка синтаксиса TS перед сборкой (esbuild из node_modules) ---
set "ESB=%REPO_DIR%\node_modules\@esbuild\win32-x64\esbuild.exe"
if exist "!ESB!" (
    echo   %ESC%[1;33m  -   Проверка синтаксиса локализации...%ESC%[0m
    "!ESB!" "%SCRIPTS_DIR%\ru-locale\ru.ts" --outfile="%DATA_DIR%\temp\ru-check.js" --log-level=warning >nul 2>&1
    if !errorlevel! neq 0 (
        echo   %ESC%[1;31m  [ОШИБКА] ru.ts не компилируется — сборка отменена, ничего не собрано.%ESC%[0m
        "!ESB!" "%SCRIPTS_DIR%\ru-locale\ru.ts" --outfile="%DATA_DIR%\temp\ru-check.js" --log-level=warning
        echo.
        pause
        goto menu
    )
    echo   %ESC%[1;32m  +   Синтаксис ru.ts в порядке%ESC%[0m
) else (
    echo   %ESC%[2m       ^(esbuild не найден — проверка синтаксиса пропущена^)%ESC%[0m
)

call "%SCRIPTS_DIR%\Rebuild-Desktop.bat" 1
if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m  [ОШИБКА] Сборка не удалась.%ESC%[0m
    echo   %ESC%[1;33m  →   Запустите пункт [6] — откат к рабочему бэкапу.%ESC%[0m
    pause
) else (
    echo   %ESC%[1;32m  +   Сборка завершена успешно%ESC%[0m
)
goto menu

REM ============================================================================
REM   [6] Откатить русификацию к последнему бэкапу
REM   Возвращает файлы локализации и готовую сборку из бэкапа, сделанного в [5].
REM ============================================================================
:rollback_ru
cls
echo.
echo   %ESC%[1;33mОткат русификации к последнему бэкапу...%ESC%[0m
echo.

set "BK_PY=%SCRIPTS_DIR%\py\ru_locale_backup.py"
set "PY_CMD="%REPO_DIR%\venv\Scripts\python.exe""
if not exist "%REPO_DIR%\venv\Scripts\python.exe" set "PY_CMD=python"

if not exist "%BK_PY%" (
    echo   %ESC%[1;31m[ОШИБКА] Не найден скрипт бэкапа: %BK_PY%%ESC%[0m
    echo.
    pause
    goto menu
)

echo   %ESC%[2m       Состояние бэкапа:%ESC%[0m
%PY_CMD% "%BK_PY%" status --quiet
if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Бэкап не найден — откатывать нечего.%ESC%[0m
    echo   %ESC%[2m       Бэкап создаётся автоматически в пункте [5] перед сборкой.%ESC%[0m
    echo.
    pause
    goto menu
)

echo.
set "confirm="
set /p "confirm=%ESC%[33mОткатить к этому бэкапу? (y/n): %ESC%[0m"
if /I not "%confirm%"=="y" (
    echo   %ESC%[1;33mОтменено.%ESC%[0m
    pause
    goto menu
)

REM Hermes должен быть закрыт: сборку нужно вернуть на место
tasklist /FI "IMAGENAME eq Hermes.exe" 2>nul | findstr /I "Hermes.exe" >nul
if !errorlevel! equ 0 (
    echo.
    echo   %ESC%[1;33m  !   Hermes Desktop запущен — закрываю для отката...%ESC%[0m
    taskkill /IM Hermes.exe /F >nul 2>&1
    call "%SCRIPTS_DIR%\SmartPause.bat" 2
)

echo.
%PY_CMD% "%BK_PY%" restore --quiet
if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m[ОШИБКА] Откат не удался.%ESC%[0m
    echo.
    pause
    goto menu
)

echo.
echo   %ESC%[1;32m  +   Откат выполнен.%ESC%[0m
echo   %ESC%[2m       Файлы локализации и сборка возвращены к рабочему состоянию.%ESC%[0m
echo.
set "runh="
set /p "runh=%ESC%[33mЗапустить Hermes сейчас? (y/n): %ESC%[0m"
if /I "!runh!"=="y" (
    call "%SCRIPTS_DIR%\Start-Hermes-Desktop.bat" 1
)
echo.
pause
goto menu

REM ============================================================================
REM   [8] Проверка русификации — структура + esbuild + порядок (ядро workflow)
REM ============================================================================
:verify_i18n
cls
echo.
echo   %ESC%[1;33mПроверка русификации (workflow-тест)...%ESC%[0m
echo.

set "VERIFY_PY=%SCRIPTS_DIR%\py\i18n_verify.py"
set "PY_CMD="%REPO_DIR%\venv\Scripts\python.exe""
if not exist "%REPO_DIR%\venv\Scripts\python.exe" set "PY_CMD=python"

if not exist "%VERIFY_PY%" (
    echo   %ESC%[1;31m[ОШИБКА] Не найден %VERIFY_PY%%ESC%[0m
    echo.
    pause
    goto menu
)

%PY_CMD% "%VERIFY_PY%"
if errorlevel 1 (
    echo.
    echo   %ESC%[1;31m  !   Есть ошибки — сборку не запускать (см. RU-WORKFLOW.md).%ESC%[0m
) else (
    echo.
    echo   %ESC%[1;32m  +   Можно собирать: пункт [5]%ESC%[0m
)
echo.
pause
goto menu

REM ============================================================================
REM   [7] Очистить репозиторий
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
    echo   %ESC%[1;33m  [i]  Notepad++ не найден. Используем стандартный Notepad.%ESC%[0m
    set "EDITOR_EXE=notepad"
) else (
    echo   %ESC%[1;32m  +   Notepad++ найден: %EDITOR_EXE%%ESC%[0m
)
exit /b 0

:exit
exit /b 0