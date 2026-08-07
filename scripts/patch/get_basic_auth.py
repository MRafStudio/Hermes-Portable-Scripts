"""Чтение basic_auth из config.yaml (username/password) для Connection.bat.
Использование: python get_basic_auth.py <config.yaml> <username|password>
Выводит значение или пустую строку — без 'Config key not set' в stdout.
"""
import sys
import yaml

def main():
    if len(sys.argv) < 3:
        sys.exit(1)
    cfg_path, key = sys.argv[1], sys.argv[2]
    try:
        with open(cfg_path, 'r', encoding='utf-8') as f:
            cfg = yaml.safe_load(f) or {}
        value = cfg.get('dashboard', {}).get('basic_auth', {}).get(key, '')
        if value:
            print(value)
    except Exception:
        pass  # нет файла/секции — выводим пусто

if __name__ == '__main__':
    main()
