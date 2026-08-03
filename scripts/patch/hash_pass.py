# scripts\patch\hash_pass.py
# Генерирует scrypt-хэш пароля для dashboard.basic_auth.
# Пароль читается из STDIN (передаётся через echo ... | python ...),
# первый аргумент — REPO_DIR (каталог hermes-agent, где лежит plugins).
# Вывод: одна строка — scrypt-хэш.
import sys
import os

if len(sys.argv) < 2:
    sys.exit(1)

sys.path.insert(0, sys.argv[1])

from plugins.dashboard_auth.basic import hash_password

password = sys.stdin.read().strip()
if not password:
    sys.exit(1)

print(hash_password(password))
