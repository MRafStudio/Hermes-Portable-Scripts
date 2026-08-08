# validate_credentials.py — ЕДИНЫЙ валидатор логина и пароля (dashboard.basic_auth).
# Правила ОДИНАКОВЫ для обоих полей (служба и web-подключения):
#   - не пусто;
#   - запрещены % и ! (раскрытие переменных в cmd);
#   - запрещены пробелы (ломают аргументы/логин).
# Значение — АРГУМЕНТ (argv[1]): delayed-раскрытие (!VAR!) безопасно от & | < > ^,
# поэтому эти символы допустимы.
# Вывод: OK (exit 0) / BAD (exit 1) / EMPTY (exit 2)
import sys

v = sys.argv[1] if len(sys.argv) > 1 else ""
if not v:
    print("EMPTY")
    sys.exit(2)
if any(c in v for c in "%! "):
    print("BAD")
    sys.exit(1)
print("OK")
sys.exit(0)
