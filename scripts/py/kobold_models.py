# kobold_models.py — справочник разрешённых моделей KoboldCPP и их проекторов (mmproj)
# Каждая запись: (id, КОРОТКОЕ имя, ПОЛНОЕ имя с расширением, размер, мин. VRAM GB, mmproj)
#   Пример: (1, "Qwythos-9B BF16", "Qwythos-9B-Claude-Mythos-5-1M-BF16.gguf", "17.9 GB", 24, "mmproj-Qwythos-9B-Claude-Mythos-5-1M-F16.gguf")
# ВАЖНО: полное имя ОБЯЗАТЕЛЬНО с расширением .gguf (это имя файла на диске и в model.default оно без расширения — сопоставление в pick учитывает это).
# Несколько моделей могут делить один mmproj; у каждой модели может быть свой mmproj — указывай его в записи.
# При добавлении новой модели ДОБАВЬ строку в MODELS — меню, статусы и загрузка
# в InstallOrUpdate-Kobold.bat обновятся автоматически (скрипт читает этот справочник).
#
# CLI:
#   list                 — все записи: id|подпись|файл|размер|vram|mmproj
#   get <id> <key>       — одно поле (label|file|size|vram|mmproj)
#   pick <choice> <cfg_model> <models_dir> — выбор модели (1/2/Enter→cfg_model→установленная)
#                          печатает "id|файл|mmproj" или ничего
#   menu <models_dir>    — строки меню выбора (с пометкой [файл] для установленных)
#   status <models_dir>  — статус-строки установленных моделей (все!)
import os
import sys

REPO = "empero-ai/Qwythos-9B-Claude-Mythos-5-1M-GGUF"

MODELS = [
    # (id, подпись, файл модели, размер, мин. VRAM GB, mmproj)
    (1, "Qwythos-9B BF16", "Qwythos-9B-Claude-Mythos-5-1M-BF16.gguf", "17.9 GB", 24, "mmproj-Qwythos-9B-Claude-Mythos-5-1M-F16.gguf"),
    (2, "Qwythos-9B Q8_0", "Qwythos-9B-Claude-Mythos-5-1M-Q8_0.gguf", "9.5 GB", 16, "mmproj-Qwythos-9B-Claude-Mythos-5-1M-F16.gguf"),
]

ESC = "\x1b"


def out(s):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    sys.stdout.write(s + "\n")


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for m in MODELS:
            out("|".join(str(x) for x in m))
    elif cmd == "get":
        mid = int(sys.argv[2])
        key = sys.argv[3] if len(sys.argv) > 3 else "file"
        idx = {"label": 1, "file": 2, "size": 3, "vram": 4, "mmproj": 5}[key]
        for m in MODELS:
            if m[0] == mid:
                out(str(m[idx]))
                return
    elif cmd == "pick":
        choice = (sys.argv[2] if len(sys.argv) > 2 else "").strip()
        cfg_model = sys.argv[3] if len(sys.argv) > 3 else ""
        models_dir = sys.argv[4] if len(sys.argv) > 4 else ""
        picked = None
        for m in MODELS:
            if choice == str(m[0]):
                picked = m
                break
        if picked is None:
            # Enter/мусорный ввод: предпочтение из config.yaml (model.default), затем первая установленная
            if cfg_model:
                for m in MODELS:
                    if m[2].replace(".gguf", "") in cfg_model or m[2] in cfg_model:
                        if os.path.exists(os.path.join(models_dir, m[2])):
                            picked = m
                            break
            if picked is None:
                for m in MODELS:
                    if os.path.exists(os.path.join(models_dir, m[2])):
                        picked = m
                        break
        if picked:
            out(f"{picked[0]}|{picked[2]}|{picked[5]}")
    elif cmd == "menu":
        models_dir = sys.argv[2] if len(sys.argv) > 2 else ""
        for m in MODELS:
            tag = ""
            if os.path.exists(os.path.join(models_dir, m[2])):
                tag = f" {ESC}[1;32m[{m[2]}]{ESC}[0m"
            out(f"  {ESC}[1;37m[{m[0]}]{ESC}[0m {ESC}[1m{m[1]}{ESC}[0m {ESC}[2m({m[3]}){ESC}[0m — для видеокарт с памятью (>={m[4]} GB){tag}")
    elif cmd == "count":
        out(str(len(MODELS)))
    elif cmd == "status":
        models_dir = sys.argv[2] if len(sys.argv) > 2 else ""
        found = False
        for m in MODELS:
            if os.path.exists(os.path.join(models_dir, m[2])):
                out(f"  {ESC}[1;32m+ {ESC}[0m Модель: {ESC}[2m[{m[2]}] ({m[1]}){ESC}[0m")
                found = True
        if not found:
            out(f"  {ESC}[1;33m. {ESC}[0m Модель: не установлена")


if __name__ == "__main__":
    main()
