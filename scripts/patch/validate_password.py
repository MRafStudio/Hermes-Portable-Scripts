# validate_password.py — проверка пароля для dashboard.basic_auth.
# Пароль — АРГУМЕНТ (argv[1]): delayed-раскрытие (!VAR!) безопасно от & | < > ^,
# поэтому запрещены ТОЛЬКО % и ! (раскрытие переменных/вложенности в cmd).
# Вывод: OK (exit 0) / BAD (exit 1) / EMPTY (exit 2)
import sys

p = sys.argv[1] if len(sys.argv) > 1 else ""
if not p:
    print("EMPTY")
    sys.exit(2)
if any(c in p for c in "%!"):
    print("BAD")
    sys.exit(1)
print("OK")
sys.exit(0)
