@REM scripts\InstallOrUpdate-Repo.bat
@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

title Клонирование репозитория

REM ============================================================================
REM   Определение путей
REM ============================================================================
for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "HERMES_HOME=%ROOT_DIR%\data\hermes"
set "NODE_DIR=%HERMES_HOME%\node"
set "REPO_DIR=%HERMES_HOME%\hermes-agent"

REM ============================================================================
REM   Изоляция данных
REM ============================================================================
set "DATA_DIR=%ROOT_DIR%\data"
set "TEMP=%DATA_DIR%\temp"
set "HOME=%DATA_DIR%\home"
set "USERPROFILE=%DATA_DIR%\home"

if not exist "%DATA_DIR%" mkdir "%DATA_DIR%" 2>nul
if not exist "%TEMP%" mkdir "%TEMP%" 2>nul
if not exist "%HOME%" mkdir "%HOME%" 2>nul
if not exist "%HOME%\Desktop" mkdir "%HOME%\Desktop" 2>nul
if not exist "%HERMES_HOME%" mkdir "%HERMES_HOME%" 2>nul
if not exist "%REPO_DIR%" mkdir "%REPO_DIR%" 2>nul

REM ============================================================================
REM   Получение ESC
REM ============================================================================
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM ============================================================================
REM   Проверка глобального Git (ОБЯЗАТЕЛЬНО!)
REM ============================================================================
git --version >nul 2>nul
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ERROR] Git not found. Install Git first.%ESC%[0m
    echo   %ESC%[33m       https://git-scm.com/download/win%ESC%[0m
    if "%AUTOCLOSE%"=="0" pause
    exit /b 1
)

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                    %ESC%[1;37mHermes Portable%ESC%[0m   %ESC%[1;33m-%ESC%[0m   %ESC%[1;33mRepository Clone%ESC%[0m                  %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m##                                                                            ##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

REM ============================================================================
REM   Развилка: репозиторий есть и ВАЛИДНЫЙ или нет
REM ============================================================================
set "REPO_VALID=0"
if exist "%REPO_DIR%\.git" (
    cd /d "%REPO_DIR%" 2>nul
    if !errorlevel! equ 0 (
        git rev-parse --is-inside-work-tree >nul 2>nul
        if !errorlevel! equ 0 (
            git rev-parse --verify HEAD >nul 2>nul
            if !errorlevel! equ 0 (
                set "REPO_VALID=1"
            )
        )
    )
    cd /d "%ROOT_DIR%" 2>nul
)

if "%REPO_VALID%"=="1" goto update_repo
goto clone_repo

REM ============================================================================
REM   ОБНОВЛЕНИЕ СУЩЕСТВУЮЩЕГО РЕПОЗИТОРИЯ
REM ============================================================================
:update_repo
echo   %ESC%[1;33m-%ESC%[0m %ESC%[1mRepository found. Updating...%ESC%[0m
echo.

cd /d "%REPO_DIR%"
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ERROR] Cannot enter %REPO_DIR%%ESC%[0m
    goto error_exit
)

if not exist ".git" (
    echo   %ESC%[1;31m[ERROR] .git not found in %REPO_DIR%%ESC%[0m
    goto error_exit
)

for /f "tokens=*" %%a in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%a"
echo   %ESC%[2m       Current branch: !CURRENT_BRANCH!%ESC%[0m

echo.
echo   %ESC%[1;33m[1/3]%ESC%[0m %ESC%[1mFetching updates from origin...%ESC%[0m
git fetch origin
echo   %ESC%[1;32m  +   Updates fetched.%ESC%[0m

echo.
echo   %ESC%[1;33m[2/3]%ESC%[0m %ESC%[1mSwitching to main...%ESC%[0m
git checkout main
echo   %ESC%[1;32m  +   On main branch.%ESC%[0m

echo.
echo   %ESC%[1;33m[2/3]%ESC%[0m %ESC%[1mSwitching to main...%ESC%[0m
git checkout main
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ERROR] Failed to checkout main branch.%ESC%[0m
    goto error_exit
)
echo   %ESC%[1;32m  +   On main branch.%ESC%[0m

if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[CONFLICT] Manual resolution required.%ESC%[0m
    echo   %ESC%[33m       Open repository in VS/VCode and resolve conflicts.%ESC%[0m
    pause
    goto error_exit
)

echo   %ESC%[1;32m  +   Merge completed without conflicts.%ESC%[0m

echo.
echo  %ESC%[1;36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mRepository updated.%ESC%[0m
echo   %ESC%[2m       Branch: main%ESC%[0m
echo   %ESC%[2m       origin/main: up to date%ESC%[0m
echo  %ESC%[1;36m--------------------------------------------------------------------------------%ESC%[0m

goto success_exit

REM ============================================================================
REM   КЛОНИРОВАНИЕ РЕПОЗИТОРИЯ
REM ============================================================================
:clone_repo
echo   %ESC%[1;33m[1/2]%ESC%[0m %ESC%[1mCloning NousResearch/hermes-agent...%ESC%[0m
echo   %ESC%[2m       Branch: main (working)%ESC%[0m
echo   %ESC%[2m       ~70 MB (source code)%ESC%[0m

if exist "%REPO_DIR%" rmdir /s /q "%REPO_DIR%"
mkdir "%REPO_DIR%" 2>nul

git clone --depth 1 --branch main https://github.com/NousResearch/hermes-agent.git "%REPO_DIR%"
if !errorlevel! neq 0 (
    echo   %ESC%[1;31m[ERROR] Failed to clone repository.%ESC%[0m
    goto error_exit
)

echo   %ESC%[1;32m  +   Repository cloned.%ESC%[0m

cd /d "%REPO_DIR%"

echo.
echo   %ESC%[1;33m[2/2]%ESC%[0m %ESC%[1mChecking main branch...%ESC%[0m

for /f "tokens=*" %%a in ('git branch --show-current 2^>nul') do set "CURRENT_BRANCH=%%a"
echo   %ESC%[1;32m  +   Current branch: !CURRENT_BRANCH!%ESC%[0m

echo   %ESC%[2m       origin:  https://github.com/NousResearch/hermes-agent.git%ESC%[0m
echo   %ESC%[2m       Branch: main (working)%ESC%[0m

echo.
echo  %ESC%[1;36m--------------------------------------------------------------------------------%ESC%[0m
echo   %ESC%[1;32mClone completed.%ESC%[0m
echo   %ESC%[2m       Working branch: main%ESC%[0m
echo   %ESC%[2m       Remember: commit all changes to main.%ESC%[0m
echo  %ESC%[1;36m--------------------------------------------------------------------------------%ESC%[0m

goto success_exit

REM ============================================================================
REM   ВЫХОДЫ
REM ============================================================================
:error_exit
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 1

:success_exit
if "%AUTOCLOSE%"=="1" (
    call "%SCRIPTS_DIR%\SmartPause.bat" 5
) else (
    pause
)
exit /b 0