# llama_gen_startbat.py — генерация start_llama.bat (UTF-8, CRLF, chcp 65001) для data\llama
# Использование: python llama_gen_startbat.py <LLAMA_DIR> <MODEL_FILE> <MMPROJ_FILE> [PORT] [MAX_CTX]
# Генерит ОДИН инстанс llama-server (модель + порт из аргументов).
# Параметры под Qwen3.6-35B-A3B: -c 262144 (256K нативный) --flash-attn 1 -ngl 999
import os
import sys

llama_dir = sys.argv[1].rstrip('\\')
model = sys.argv[2]
mmproj = sys.argv[3]
port = sys.argv[4] if len(sys.argv) > 4 else '8080'
max_ctx = sys.argv[5] if len(sys.argv) > 5 else '262144'

lines = [
    '@echo off',
    'chcp 65001 >nul',
    'rem llama.cpp server: start_llama.bat [МОДЕЛЬ.gguf] [ПОРТ]  (Qwen3.6-35B :8080!)',
    'set "LLAMA_DIR=%~dp0"',
    'for %%i in ("%LLAMA_DIR%..\\..") do set "ROOT_DIR=%%~fi"',
    'set "LLM_MODELS=%ROOT_DIR%\\data\\llm\\models"',
    'set "MODEL=%~1"',
    'if "%MODEL%"=="" set "MODEL=' + model + '"',
    'set "PORT=%~2"',
    'if "%PORT%"=="" set "PORT=' + port + '"',
    'set "MMPROJ=%~3"',
    'if "%MMPROJ%"=="" set "MMPROJ=%LLM_MODELS%\\' + mmproj + '"',
    'if not exist "%MMPROJ%" set "MMPROJ=%LLM_MODELS%\\' + mmproj + '"',
    'set "MODEL_PATH=%LLM_MODELS%\\%MODEL%"',
    'title Llama.cpp %MODEL% (port %PORT%)',
    'if not exist "%MODEL_PATH%" (',
    '    echo [ERROR] модель не найдена: %MODEL%',
    '    echo Скачай через InstallOrUpdate-Llama.bat',
    '    pause',
    '    exit /b 1',
    ')',
    'echo Запуск llama.cpp: %MODEL% ^| порт %PORT% ^| контекст ' + max_ctx + ' + flash-attn',
    'start "LlamaCPP %MODEL%" /min "%LLAMA_DIR%\\llama-server.exe" -m "%MODEL_PATH%" --mmproj "%MMPROJ%" --alias llama/%MODEL:~0,-5% -c ' + max_ctx + ' -ngl 999 --flash-attn 1 --parallel 1 --image-min-tokens 1024 --port %PORT% --host 127.0.0.1',
    'echo Сервер запущен в отдельном окне ^(свернуто^).',
    'exit /b 0',
]
content = '\r\n'.join(lines) + '\r\n'
with open(llama_dir + '\\start_llama.bat', 'wb') as f:
    f.write(content.encode('utf-8'))
print('start_llama.bat generated:', llama_dir + '\\start_llama.bat')
