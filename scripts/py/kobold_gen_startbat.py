# kobold_gen_startbat.py — генерация start_kobold.bat (UTF-8, CRLF, chcp 65001) для data\kobold
# Использование: python kobold_gen_startbat.py <KCPP_DIR> <MODEL_FILE> <MMPROJ_FILE> [PORT]
# Генерит ОДИН инстанс (модель + порт из аргументов) — для схемы "2 инстанса" (Q4:5101, Q6:5102).
# Параметры под Qwen3.6-35B-A3B: --contextsize 262144 (256K нативный, KV ~12.6GB) --usemtp (MTP-обучена) --flashattention (НЕ SWA)
import os
import sys

kobold_dir = sys.argv[1].rstrip('\\')
model = sys.argv[2]
mmproj = sys.argv[3]
port = sys.argv[4] if len(sys.argv) > 4 else '5101'

lines = [
    '@echo off',
    'chcp 65001 >nul',
    'rem Инстанс koboldcpp: start_kobold.bat [МОДЕЛЬ.gguf] [ПОРТ]  (Gemma-3-27B :5101!)',
    'set "KCPP_DIR=%~dp0"',
    'set "MODEL=%~1"',
    'if "%MODEL%"=="" set "MODEL=' + model + '"',
    'set "PORT=%~2"',
    'if "%PORT%"=="" set "PORT=' + port + '"',
    'set "MMPROJ=%KCPP_DIR%\\models\\' + mmproj + '"',
    'set "MODEL_PATH=%KCPP_DIR%\\models\\%MODEL%"',
    'title KoboldCPP %MODEL% (port %PORT%)',
    'if not exist "%MODEL_PATH%" (',
    '    echo [ERROR] модель не найдена: %MODEL%',
    '    echo Скачай через InstallOrUpdate-Kobold.bat',
    '    pause',
    '    exit /b 1',
    ')',
    'echo Запуск KoboldCPP: %MODEL% ^| порт %PORT% ^| контекст 256K (нативный, KV 12.6GB) + MTP + flash',
    'echo Загрузка модели до ~1-2 мин...',
    '"%KCPP_DIR%\\koboldcpp.exe" --model "%MODEL_PATH%" --mmproj "%MMPROJ%" --usemtp --gpulayers 999 --contextsize 262144 --defaultgenamt 16384 --batchsize 4096 --flashattention --host 0.0.0.0 --port %PORT%',
    'pause',
]
content = '\r\n'.join(lines) + '\r\n'
with open(kobold_dir + '\\start_kobold.bat', 'wb') as f:
    f.write(content.encode('utf-8'))
print('start_kobold.bat generated:', kobold_dir + '\\start_kobold.bat')
