# kobold_check_main_model.py — проверка, настроена ли основная модель Hermes
# Печатает значение model.default/model.name, если оно НЕ пустое и НЕ молчаливый дефолт.
# Пусто/дефолт → exit 0 с пустым выводом (модель НЕ настроена).
# Использование: python kobold_check_main_model.py <CONFIG_YAML>
import sys

try:
    import yaml
except ImportError:
    yaml = None

SILENT_DEFAULTS = {"", "z-ai/glm-5.2", "gpt-4o", "gpt-4o-mini", "deepseek-chat", "deepseek-reasoner"}

cfg_path = sys.argv[1] if len(sys.argv) > 1 else ""

cur = ""
try:
    if yaml is not None:
        with open(cfg_path, "r", encoding="utf-8") as f:
            cfg = yaml.safe_load(f) or {}
        m = cfg.get("model") or {}
        cur = str(m.get("default") or m.get("name") or "").strip()
    else:
        # фолбэк: грубый grep по строкам
        with open(cfg_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if line.startswith("model.default:") or line.startswith("model.name:"):
                    cur = line.split(":", 1)[1].strip().strip("'\"")
                    break
except Exception:
    sys.exit(1)

if cur.lower() in SILENT_DEFAULTS:
    sys.exit(0)  # не настроена — пустой вывод

print(cur)
sys.exit(0)
