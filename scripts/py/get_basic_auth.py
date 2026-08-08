"""Чтение basic_auth из config.yaml для Connection.bat.

НЕ парсит YAML вручную — использует штатный механизм Hermes:
`hermes config get dashboard.basic_auth.<key>` (config.py Hermes).

Использование: python get_basic_auth.py <hermes_exe> <username|password>
Выводит значение или пустую строку. 'Config key not set' в stdout не попадает.
"""
import subprocess
import sys


def main():
    if len(sys.argv) < 3:
        sys.exit(1)
    hermes_exe, key = sys.argv[1], sys.argv[2]
    try:
        r = subprocess.run(
            [hermes_exe, 'config', 'get', 'dashboard.basic_auth.%s' % key],
            capture_output=True, text=True, timeout=60)
        out = (r.stdout or '').strip()
        if out and not out.startswith('Config key not set'):
            print(out)
    except Exception:
        pass  # hermes недоступен — выводим пусто


if __name__ == '__main__':
    main()
