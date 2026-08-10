# kobold_gen_startbat.py — генерация start_kobold.bat (ASCII, CRLF) для data\kobold
# Использование: python kobold_gen_startbat.py <KCPP_DIR> <MODEL_FILE> <MMPROJ_FILE> [PORT]
import sys

kobold_dir = sys.argv[1].rstrip('\\')
model = sys.argv[2]
mmproj = sys.argv[3]
port = sys.argv[4] if len(sys.argv) > 4 else '5101'

lines = [
    '@echo off',
    'chcp 65001 >nul',
    'title KoboldCPP - Qwythos 9B (Hermes Portable)',
    'set "KCPP_DIR=%~dp0"',
    'set "MODEL=%KCPP_DIR%\\models\\' + model + '"',
    'set "MMPROJ=%KCPP_DIR%\\models\\' + mmproj + '"',
    'echo === KoboldCPP - Qwythos 9B (port ' + port + ') ===',
    'echo Model: %MODEL%',
    'echo Projector: %MMPROJ%',
    'echo.',
    '"%KCPP_DIR%\\koboldcpp.exe" --model "%MODEL%" --mmproj "%MMPROJ%" --gpulayers 999 --contextsize 65536 --defaultgenamt 4096 --batchsize 2048 --flashattention --host 0.0.0.0 --port ' + port,
    'pause',
]
content = '\r\n'.join(lines) + '\r\n'
with open(kobold_dir + '\\start_kobold.bat', 'wb') as f:
    f.write(content.encode('ascii'))
print('start_kobold.bat generated:', kobold_dir + '\\start_kobold.bat')
