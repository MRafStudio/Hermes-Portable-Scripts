# kobold_check_main_model.py — проверка, настроена ли основная модель Hermes
# НЕ парсит YAML вручную — использует штатный механизм Hermes:
# `hermes config get model.default` / `model.name` (config.py Hermes).
# Пусто/дефолт → exit 0 с пустым выводом (модель НЕ настроена).
# Использование: python kobold_check_main_model.py <hermes_exe>
import subprocess
import sys

SILENT_DEFAULTS = {
    "",
    "z-ai/glm-5.2",
    "gpt-4o",
    "gpt-4o-mini",
    "deepseek-chat",
    "deepseek-reasoner",
    "anthropic/claude-opus-4.6",  # рекомендуемая модель Hermes (models.py) — не настройка пользователя
}


def config_get(key):
    try:
        r = subprocess.run(
            [hermes_exe, "config", "get", key],
            capture_output=True, text=True, timeout=60)
        out = (r.stdout or "").strip()
        if out and not out.startswith("Config key not set"):
            return out
    except Exception:
        pass  # hermes недоступен — считаем не настроенной
    return ""


if len(sys.argv) < 2:
    sys.exit(1)
hermes_exe = sys.argv[1]

cur = config_get("model.default") or config_get("model.name")
cur = cur.strip()

if cur.lower() in SILENT_DEFAULTS:
    sys.exit(0)  # не настроена — пустой вывод

print(cur)
sys.exit(0)
