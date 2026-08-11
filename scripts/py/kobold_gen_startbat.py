# kobold_gen_startbat.py — генерация start_kobold.bat (UTF-8, CRLF, chcp 65001) для data\kobold
# Использование: python kobold_gen_startbat.py <KCPP_DIR> <MODEL_FILE> <MMPROJ_FILE> [PORT]
# Генерит СПИСОК моделей из kobold_models.py (все кванты) — выбранная первая (дефолт UI).
# Параметры под 1M-модель: --contextsize 131072 --defaultgenamt 16384 --batchsize 4096
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
from kobold_models import MODELS, I_FILE, I_LABEL

kobold_dir = sys.argv[1].rstrip('\\')
model = sys.argv[2]
mmproj = sys.argv[3]
port = sys.argv[4] if len(sys.argv) > 4 else '5101'

# все файлы из базы (кроме выбранного — он ПЕРВЫЙ); сохраняем порядок MODELS
files = [model]
for m in MODELS:
    if m[I_FILE] != model and m[I_FILE] not in files:
        files.append(m[I_FILE])

labels = {m[I_FILE]: m[I_LABEL] for m in MODELS}
label_txt = ' | '.join(labels.get(f, f) for f in files)
label_txt = label_txt.replace('|', '^|')  # экранируем пайп в echo (cmd оператор!)

model_args = ' '.join('"%KCPP_DIR%\\models\\' + f + '"' for f in files)
warn_loop = ''.join(
    'if not exist "%KCPP_DIR%\\models\\' + f + '" echo [WARN] модель не найдена: ' + f + '\r\n'
    for f in files
)

lines = [
    '@echo off',
    'chcp 65001 >nul',
    'title KoboldCPP - Qwythos 9B (Hermes Portable)',
    'set "KCPP_DIR=%~dp0"',
    'set "MMPROJ=%KCPP_DIR%\\models\\' + mmproj + '"',
    'echo === KoboldCPP - Qwythos 9B (port ' + port + ') ===',
    'echo Models: ' + label_txt + ' (переключение через UI: Settings - Load Model)',
    'echo Projector: %MMPROJ%',
    'echo.',
    warn_loop.rstrip('\r\n'),
    '"%KCPP_DIR%\\koboldcpp.exe" --model ' + model_args + ' --mmproj "%MMPROJ%" --gpulayers 999 --contextsize 131072 --defaultgenamt 16384 --batchsize 4096 --flashattention --host 0.0.0.0 --port ' + port,
    'pause',
]
content = '\r\n'.join(lines) + '\r\n'
with open(kobold_dir + '\\start_kobold.bat', 'wb') as f:
    f.write(content.encode('utf-8'))
print('start_kobold.bat generated:', kobold_dir + '\\start_kobold.bat')
