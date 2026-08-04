@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
REM ТЕСТ: npm-блок из Rebuild-Desktop.bat (изолированно)
set "DATA_DIR=D:\Hermes\data"
set "REAL_APPDATA=C:\Users\Администратор.WIN-3UIGTI09LG4\AppData\Roaming"
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

echo === ТЕСТ 1: npm 12 (как на сервере) ===
set "NPM_CMD=C:\Users\Администратор.WIN-3UIGTI09LG4\AppData\Roaming\npm\npm.cmd"
set "AUTOCLOSE=1"

set "NPM_VER="
for /f "delims=" %%v in ('"!NPM_CMD!" --version 2^>nul') do set "NPM_VER=%%v"
echo NPM_VER=[!NPM_VER!]
set "NPM_MAJOR=0"
set "NPM_MINOR=0"
for /f "tokens=1,2 delims=." %%a in ("!NPM_VER!") do (
    set "NPM_MAJOR=%%a"
    set "NPM_MINOR=%%b"
)
echo MAJOR=!NPM_MAJOR! MINOR=!NPM_MINOR!
set "NPM_NEEDS_UPDATE=0"
if !NPM_MAJOR! lss 11 set "NPM_NEEDS_UPDATE=1"
if !NPM_MAJOR! equ 11 (
    if !NPM_MINOR! geq 10 if !NPM_MINOR! lss 17 set "NPM_NEEDS_UPDATE=1"
)
echo NEEDS_UPDATE=!NPM_NEEDS_UPDATE!

echo.
echo === ТЕСТ 2: имитация npm 11.14 (дыра!) ===
set "NPM_VER=11.14.0"
set "NPM_MAJOR=0"
set "NPM_MINOR=0"
for /f "tokens=1,2 delims=." %%a in ("!NPM_VER!") do (
    set "NPM_MAJOR=%%a"
    set "NPM_MINOR=%%b"
)
echo MAJOR=!NPM_MAJOR! MINOR=!NPM_MINOR!
set "NPM_NEEDS_UPDATE=0"
if !NPM_MAJOR! lss 11 set "NPM_NEEDS_UPDATE=1"
if !NPM_MAJOR! equ 11 (
    if !NPM_MINOR! geq 10 if !NPM_MINOR! lss 17 set "NPM_NEEDS_UPDATE=1"
)
echo NEEDS_UPDATE=!NPM_NEEDS_UPDATE! ^(ожидаем 1^)

echo.
echo === ТЕСТ 3: полный блок с set /p (AUTOCLOSE=0) ===
set "AUTOCLOSE=0"
set "NPM_VER=11.14.0"
set "NPM_MAJOR=11"
set "NPM_MINOR=14"
set "NPM_NEEDS_UPDATE=1"
if !NPM_NEEDS_UPDATE! equ 1 (
    echo.
    echo %ESC%[1;33m[i]%ESC%[0m npm !NPM_VER! несовместим с hermes-agent ^(нужен 11.17+ или 12^).
    if "!AUTOCLOSE!"=="1" (
        echo %ESC%[1;33m→%ESC%[0m Авто-обновление до npm@12...
    ) else (
        set /p "NPM_CHOICE=%ESC%[33mОбновить npm до 12? ^(Enter — да, N — нет^): %ESC%[0m"
    )
    if /i "!NPM_CHOICE!"=="N" (
        echo %ESC%[1;33m  .   npm не обновлён — сборка может не пройти.%ESC%[0m
    ) else (
        echo %ESC%[1;33m→%ESC%[0m Обновляем npm до npm@12 в реальном профиле...
        echo %ESC%[2m    "!NPM_CMD!" install -g npm@12%ESC%[0m
    )
)
echo.
echo ТЕСТ-БЛОК ЗАВЕРШЁН БЕЗ ПАДЕНИЙ
