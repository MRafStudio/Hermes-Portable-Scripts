# validate_password.py — проверка пароля для dashboard.basic_auth (stdin).
# Запрещены символы-разделители команд cmd: & | < > ^ (ломают set /p и config set).
# Вывод: OK (exit 0) / BAD (exit 1) / EMPTY (exit 2)
import sys

p = sys.stdin.read().strip()
if not p:
    print("EMPTY")
    sys.exit(2)
if any(c in p for c in "&|<>^"):
    print("BAD")
    sys.exit(1)
print("OK")
sys.exit(0)
