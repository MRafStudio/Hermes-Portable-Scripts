@echo off
REM ============================================================================
REM   scripts\Update-Scripts.bat
REM   Краткая синхронизация ТОЛЬКО наших скриптов с GitHub.
REM
REM   Почему не git pull: pull тянет слияние и даёт конфликты.
REM   Здесь чисто: fetch -> сравнить HEAD с origin/main -> reset --hard.
REM   Локальные правки не теряются: сохраняются патчем и веткой autostash-<дата>.
REM
REM   Коды выхода:
REM     0  - скрипты уже актуальны (ничего не меняли)
REM     1  - ошибка (нет git-репозитория, не удался fetch/reset)
REM     10 - скрипты обновились -> ВЫЗЫВАЮЩИЙ скрипт должен перезапуститься
REM ============================================================================
setlocal EnableDelayedExpansion
chcp 65001 >nul

set "ROOT=%~dp0.."
cd /d "%ROOT%" || (echo   [ОШИБКА] не открыть корень "%ROOT%" & exit /b 1)

git rev-parse --git-dir >nul 2>&1
if !errorlevel! neq 0 (
    echo   [i] Это не git-репозиторий ^(нет .git^) - синхронизация скриптов пропущена.
    exit /b 1
)

for /f "delims=" %%H in ('git rev-parse HEAD 2^>nul') do set "LOCAL=%%H"
if not defined LOCAL (
    echo   [ОШИБКА] не прочитать локальный HEAD
    exit /b 1
)

echo   -   Проверка обновлений скриптов на GitHub...
git fetch origin main >nul 2>&1
if !errorlevel! neq 0 (
    echo   [i] не удалось обратиться к GitHub ^(сеть/VPN/креды^) - продолжаем с текущими скриптами.
    exit /b 1
)

for /f "delims=" %%H in ('git rev-parse origin/main 2^>nul') do set "REMOTE=%%H"

if /I "!LOCAL!"=="!REMOTE!" (
    echo   +   Скрипты актуальны: !LOCAL:~0,7!
    exit /b 0
)

REM --- есть ли локальные правки, которые reset снесёт ---
set "DIRTY=0"
for /f "delims=" %%L in ('git status --porcelain 2^>nul') do set "DIRTY=1"

set "STAMP=%DATE:~-4%%DATE:~3,2%%DATE:~0,2%-%TIME:~0,2%%TIME:~3,2%%TIME:~6,2%"
set "STAMP=!STAMP: =0!"
set "BK=%ROOT%\data\backup"
if not exist "%BK%" mkdir "%BK%" >nul 2>&1

if "!DIRTY!"=="1" (
    echo   !   Есть локальные правки - сохраняю перед сбросом...
    git diff HEAD > "%BK%\scripts-local-!STAMP!.patch" 2>nul
    git branch -f "autostash-!STAMP!" HEAD >nul 2>&1
    echo   +   страховка: data\backup\scripts-local-!STAMP!.patch
    echo   +   страховка: ветка autostash-!STAMP!
)

echo   -   Сброс к origin/main ^(без pull - конфликтов не будет^)...
git reset --hard origin/main >nul 2>&1
if !errorlevel! neq 0 (
    echo   [ОШИБКА] reset --hard не удался. Скрипты не обновлены.
    exit /b 1
)

echo   +   Скрипты обновлены: !LOCAL:~0,7! -^> !REMOTE:~0,7!
echo   +   Нужен перезапуск скрипта, чтобы работал новый код.
exit /b 10
