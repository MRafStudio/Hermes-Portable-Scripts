# hash_pass.py — Генерирует scrypt-хэш пароля для dashboard.basic_auth.
# Пароль — ВТОРОЙ аргумент (argv[2]), НЕ stdin: аргумент с delayed-раскрытием
# (!VAR!) безопасен от & | < > ^ (cmd парсит строку ДО раскрытия).
# Первый аргумент — REPO_DIR (каталог hermes-agent, где лежит plugins).
# Вывод: одна строка — scrypt-хэш.
import sys

if len(sys.argv) < 3:
    sys.exit(1)

sys.path.insert(0, sys.argv[1])

from plugins.dashboard_auth.basic import hash_password

password = sys.argv[2]
if not password:
    sys.exit(1)

print(hash_password(password))
