@REM scripts\Model-Setup.bat
@echo off
chcp 65001 >nul

REM ============================================================================
REM   Определение модели по GPU и сохранение в Config.ini
REM   Возвращает переменные: DEFAULT_MODEL, DEFAULT_MMPROJ, MODEL_REPO, MODEL_SIZE, MMPROJ_SIZE
REM   %1 = AUTOCLOSE (1 = авто, 0 = интерактив)
REM
REM   ВНИМАНИЕ: setlocal здесь НЕ используется ОСОЗНАННО —
REM   переменные должны остаться в окружении вызывающего скрипта!
REM ============================================================================
set "AUTOCLOSE=0"
if "%1"=="1" set "AUTOCLOSE=1"

for %%F in ("%~dp0..") do set "ROOT_DIR=%%~fF"
set "SCRIPTS_DIR=%ROOT_DIR%\scripts"
set "CONFIG_FILE=%SCRIPTS_DIR%\Config.ini"

REM Получение ESC
for /f "delims=#" %%a in ('"prompt #$E# & echo on & for %%_ in (1) do rem"') do set "ESC=%%a"

REM Определение GPU
call "%SCRIPTS_DIR%\DetectGPU.bat" quiet

REM Страховка: если DetectGPU не вернул VRAM — считаем нулём
if not defined GPU_VRAM_NUM set "GPU_VRAM_NUM=0"

cls
echo.
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo  %ESC%[1;36m##%ESC%[0m                 %ESC%[1;37mHermes Portable%ESC%[0m   —   %ESC%[1;33mВыбор модели KoboldCpp%ESC%[0m               %ESC%[1;36m##%ESC%[0m
echo  %ESC%[1;36m################################################################################%ESC%[0m
echo.

if not "%GPU_TYPE%"=="UNKNOWN" (
    echo   %ESC%[1;32mGPU: %GPU_NAME% ^| %GPU_VRAM_MB% MB VRAM%ESC%[0m
    echo.
)

REM Авто-выбор по GPU
if "%GPU_TYPE%"=="NVIDIA" (
    if %GPU_VRAM_NUM% GEQ 32000 (
        set "DEFAULT_MODEL=2-Coding_Agents/1-Architect_and_Executor/Qwen3-Coder-30B-A3B-Instruct-Q5_K_M/Qwen3-Coder-30B-A3B-Instruct-Q5_K_M.gguf"
        set "DEFAULT_MMPROJ="
        set "MODEL_REPO=m15dg/local-ai-toolkit"
        set "MODEL_SIZE=18.6 GB"
        set "MMPROJ_SIZE=899 MB"
    ) else if %GPU_VRAM_NUM% GEQ 24000 (
        set "DEFAULT_MODEL=Qwen_Qwen3.6-27B-Q3_K_M.gguf"
        set "DEFAULT_MMPROJ=mmproj-Qwen_Qwen3.6-27B-f16.gguf"
        set "MODEL_REPO=bartowski/Qwen_Qwen3.6-27B-GGUF"
        set "MODEL_SIZE=15 GB"
        set "MMPROJ_SIZE=928 MB"
    ) else if %GPU_VRAM_NUM% GEQ 16000 (
        set "DEFAULT_MODEL=Qwen_Qwen2.5-VL-14B-Instruct-Q4_K_M.gguf"
        set "DEFAULT_MMPROJ=mmproj-Qwen_Qwen2.5-VL-14B-Instruct-f16.gguf"
        set "MODEL_REPO=bartowski/Qwen_Qwen2.5-VL-14B-Instruct-GGUF"
        set "MODEL_SIZE=8.5 GB"
        set "MMPROJ_SIZE=500 MB"
    ) else (
        set "DEFAULT_MODEL=Qwen_Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"
        set "DEFAULT_MMPROJ=mmproj-Qwen_Qwen2.5-VL-7B-Instruct-f16.gguf"
        set "MODEL_REPO=bartowski/Qwen_Qwen2.5-VL-7B-Instruct-GGUF"
        set "MODEL_SIZE=4.7 GB"
        set "MMPROJ_SIZE=1.4 GB"
    )
) else if "%GPU_TYPE%"=="AMD" (
    if %GPU_VRAM_NUM% GEQ 24000 (
        set "DEFAULT_MODEL=Qwen_Qwen3.6-27B-Q3_K_M.gguf"
        set "DEFAULT_MMPROJ=mmproj-Qwen_Qwen3.6-27B-f16.gguf"
        set "MODEL_REPO=bartowski/Qwen_Qwen3.6-27B-GGUF"
        set "MODEL_SIZE=15 GB"
        set "MMPROJ_SIZE=928 MB"
    ) else if %GPU_VRAM_NUM% GEQ 16000 (
        set "DEFAULT_MODEL=Qwen2.5-VL-7B-Instruct-Q5_K_M.gguf"
        set "DEFAULT_MMPROJ=mmproj-F16.gguf"
        set "MODEL_REPO=unsloth/Qwen2.5-VL-7B-Instruct-GGUF"
        set "MODEL_SIZE=5.5 GB"
        set "MMPROJ_SIZE=1.4 GB"
    ) else (
        set "DEFAULT_MODEL=Qwen2.5-VL-7B-Instruct-Q5_K_M.gguf"
        set "DEFAULT_MMPROJ=mmproj-F16.gguf"
        set "MODEL_REPO=unsloth/Qwen2.5-VL-7B-Instruct-GGUF"
        set "MODEL_SIZE=5.5 GB"
        set "MMPROJ_SIZE=1.4 GB"
    )
) else (
    REM Intel/Unknown — минимальная модель
    set "DEFAULT_MODEL=Qwen_Qwen2.5-VL-7B-Instruct-Q4_K_M.gguf"
    set "DEFAULT_MMPROJ=mmproj-Qwen_Qwen2.5-VL-7B-Instruct-f16.gguf"
    set "MODEL_REPO=bartowski/Qwen_Qwen2.5-VL-7B-Instruct-GGUF"
    set "MODEL_SIZE=4.7 GB"
    set "MMPROJ_SIZE=1.4 GB"
)

REM ============================================================================
REM   АВТОМАТИЧЕСКИЙ РЕЖИМ: без меню — сразу рекомендуемая модель
REM ============================================================================
if "%AUTOCLOSE%"=="1" (
    echo   %ESC%[1;33mАвто-выбор модели по GPU:%ESC%[0m
    echo   %ESC%[2m       Модель:   %DEFAULT_MODEL% ^(%MODEL_SIZE%^)%ESC%[0m
    echo   %ESC%[2m       Проектор: %DEFAULT_MMPROJ% ^(%MMPROJ_SIZE%^)%ESC%[0m
    echo   %ESC%[2m       Репо:     %MODEL_REPO%%ESC%[0m
    goto save_model
)

REM Показываем выбор
echo   %ESC%[1;33mРекомендуемая модель по GPU:%ESC%[0m
echo   %ESC%[2m       Модель:   %DEFAULT_MODEL% ^(%MODEL_SIZE%^)%ESC%[0m
echo   %ESC%[2m       Проектор: %DEFAULT_MMPROJ% ^(%MMPROJ_SIZE%^)%ESC%[0m
echo   %ESC%[2m       Репо:     %MODEL_REPO%%ESC%[0m
echo.
echo   %ESC%[1;37m[1]%ESC%[0m %ESC%[1mИспользовать рекомендуемую модель%ESC%[0m
echo   %ESC%[1;37m[2]%ESC%[0m %ESC%[1mВыбрать другую модель вручную%ESC%[0m
echo   %ESC%[1;37m[0]%ESC%[0m %ESC%[1mОтмена%ESC%[0m
echo.
set "choice="
set /p "choice=%ESC%[33mВыберите: %ESC%[0m"

if "%choice%"=="0" exit /b 0
if "%choice%"=="2" goto manual_model

REM Сохраняем рекомендуемую
:save_model
call "%SCRIPTS_DIR%\CreateConfig.bat" "1" "%DEFAULT_MODEL%" "%DEFAULT_MMPROJ%" "5001" "%MODEL_REPO%"
echo   %ESC%[1;32m  +   Модель сохранена в Config.ini.%ESC%[0m
timeout /t 2 /nobreak >nul
exit /b 0

:manual_model
cls
echo.
echo   %ESC%[1;33mРучной выбор модели:%ESC%[0m
echo.
set "MANUAL_MODEL="
set "MANUAL_MMPROJ="
set "MANUAL_REPO="
set "MANUAL_SIZE="
set "MANUAL_MMPROJ_SIZE="
set /p "MANUAL_MODEL=%ESC%[33mИмя файла модели (.gguf): %ESC%[0m"
set /p "MANUAL_MMPROJ=%ESC%[33mИмя файла проектора: %ESC%[0m"
set /p "MANUAL_REPO=%ESC%[33mРепозиторий HuggingFace (user/repo): %ESC%[0m"
set /p "MANUAL_SIZE=%ESC%[33mРазмер модели (например: 8.5 GB): %ESC%[0m"
set /p "MANUAL_MMPROJ_SIZE=%ESC%[33mРазмер проектора (например: 500 MB): %ESC%[0m"

REM Валидация: модель и репозиторий обязательны
if "!MANUAL_MODEL!"=="" goto :manual_invalid
if "!MANUAL_REPO!"=="" goto :manual_invalid
goto :manual_valid

:manual_invalid
echo.
echo   %ESC%[1;31m[ОШИБКА] Имя модели и репозиторий обязательны!%ESC%[0m
echo   %ESC%[33m         Повторите ввод.%ESC%[0m
echo.
pause
goto manual_model

:manual_valid
set "DEFAULT_MODEL=%MANUAL_MODEL%"
set "DEFAULT_MMPROJ=%MANUAL_MMPROJ%"
set "MODEL_REPO=%MANUAL_REPO%"
set "MODEL_SIZE=%MANUAL_SIZE%"
set "MMPROJ_SIZE=%MANUAL_MMPROJ_SIZE%"
goto save_model