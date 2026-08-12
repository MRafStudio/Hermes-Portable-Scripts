#!/usr/bin/env python3
"""normalize_crlf.py — обязательная CRLF-нормализация .bat-скриптов (Windows!).

После git pull / write_file / sed .bat-файлы могут получить LF-переводы строк —
cmd на LF-only .bat ломается («'...' is not recognized», goto-метки плывут).
Этот скрипт приводит ВСЕ .bat в репозитории к CRLF (идемпотентно).

Использование:
  python normalize_crlf.py <ROOT_DIR>      # обработать Start.bat + scripts/**/*.bat
  python normalize_crlf.py --check <ROOT_DIR>   # только проверка (exit 1 если есть LF)
"""
import os, sys

def fix(path):
    raw = open(path, 'rb').read()
    # LF -> CRLF (без двойных CRLF)
    out = raw.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
    if out != raw:
        open(path, 'wb').write(out)
        return True
    return False

def has_lf(path):
    raw = open(path, 'rb').read()
    return b'\n' in raw.replace(b'\r\n', b'')

def main():
    if len(sys.argv) < 2:
        print('Использование: normalize_crlf.py <ROOT_DIR> [--check]')
        return 2
    root = sys.argv[1]
    check = '--check' in sys.argv[2:]
    targets = []
    for dirpath, dirs, files in os.walk(root):
        if 'node_modules' in dirpath or '__pycache__' in dirpath or '.git' in dirpath:
            continue
        for f in files:
            if f.lower().endswith('.bat'):
                targets.append(os.path.join(dirpath, f))
    fixed, bad = [], []
    for p in targets:
        if has_lf(p):
            if check:
                bad.append(p)
            else:
                if fix(p):
                    fixed.append(p)
    if check:
        if bad:
            print('CRLF: НАЙДЕНЫ LF-файлы:')
            for b in bad:
                print('  ' + b)
            return 1
        print('CRLF: OK (все .bat в CRLF)')
        return 0
    print(f'CRLF: обработано {len(targets)} .bat — исправлено {len(fixed)}')
    for f in fixed:
        print('  fixed: ' + f)
    return 0

if __name__ == '__main__':
    sys.exit(main())
