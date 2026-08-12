# kobold_models.py — справочник разрешённых моделей KoboldCPP и их проекторов (mmproj)
# Каждая запись: (id, КОРОТКОЕ имя, ПОЛНОЕ имя с расширением, размер, мин. VRAM GB, mmproj, repo)
#   Пример: (1, "Gemma-3-27B Q4_K_M", "gemma-3-27b-it.Q4_K_M.gguf", "16.6 GB", 20,
#            "mmproj-gemma3-q8_0.gguf", "MaziyarPanahi/gemma-3-27b-it-GGUF")
# ВАЖНО: полное имя ОБЯЗАТЕЛЬНО с расширением .gguf (имя файла на диске; в model.default оно без
# расширения — сопоставление в pick/label учитывает это). repo — путь для скачивания с Hugging Face.
# Несколько моделей могут делить один mmproj; у каждой модели может быть свой mmproj и repo.
# При добавлении новой модели ДОБАВЬ строку в MODELS — меню, статусы и загрузка
# в InstallOrUpdate-Kobold.bat обновятся автоматически (скрипт читает этот справочник).
#
# CLI:
#   list                 — все записи: id|label|file|size|vram|mmproj|repo
#   get <id> <key>       — одно поле (label|file|size|vram|mmproj|repo)
#   pick <choice> <cfg_model> <models_dir> — выбор модели (1/2/Enter→cfg_model→установленная)
#                          печатает "id|file|mmproj|repo" или ничего
#   label <cfg_model>    — короткое имя модели по model.default (для подсказки "[Enter = ...]")
#   resolve <short_name> — ПОЛНОЕ имя файла по короткому имени (или пусто)
#   menu <models_dir>    — строки меню выбора (с пометкой [файл] для установленных)
#   status <models_dir>  — статус-строки установленных моделей (все!)
#   count                — число моделей
import os
import sys

REPO_DEFAULT = "MaziyarPanahi/gemma-3-27b-it-GGUF"

MODELS = [
    # (id, короткое имя, полное имя с .gguf, размер, мин. VRAM GB, mmproj, repo для скачивания с HF)
    # ДОМ (RTX 5090 32GB)
    (1, "Gemma-3-27B Q4_K_M", "gemma-3-27b-it.Q4_K_M.gguf", "16.6 GB", 20,
     "mmproj-bggpt-gemma3-27b-it-BF16.gguf", "MaziyarPanahi/gemma-3-27b-it-GGUF"),
    (2, "Gemma-3-27B Q5_K_M", "gemma-3-27b-it.Q5_K_M.gguf", "19.3 GB", 24,
     "mmproj-bggpt-gemma3-27b-it-BF16.gguf", "MaziyarPanahi/gemma-3-27b-it-GGUF"),
    # РАБОТА (AMD 16GB)
    (3, "Gemma-3-12B Q4_K_M", "gemma-3-12b-it-Q4_K_M.gguf", "7.3 GB", 12,
     "mmproj-F16.gguf", "unsloth/gemma-3-12b-it-GGUF"),
    (4, "Gemma-3-12B Q5_K_M", "gemma-3-12b-it-Q5_K_M.gguf", "8.4 GB", 14,
     "mmproj-F16.gguf", "unsloth/gemma-3-12b-it-GGUF"),
    # ОСНОВНАЯ (2026, MoE — активных 3B — быстро как 9B, ум как 35B)
    (5, "Qwen3.6-35B-A3B IQ4_NL", "Qwen3.6-35B-A3B-UD-IQ4_NL.gguf", "16.8 GB", 22,
     "mmproj-F16.gguf", "unsloth/Qwen3.6-35B-A3B-GGUF"),
]

ESC = "\x1b"

# индексы полей
I_ID, I_LABEL, I_FILE, I_SIZE, I_VRAM, I_MMPROJ, I_REPO = range(7)


def out(s):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    sys.stdout.write(s + "\n")


def find_by_cfg(cfg_model):
    """model.default (koboldcpp/имя-без-.gguf) → запись или None."""
    if not cfg_model:
        return None
    c = cfg_model.strip()
    for m in MODELS:
        if m[I_FILE].replace(".gguf", "") in c or m[I_FILE] in c:
            return m
    return None


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "list"
    if cmd == "list":
        for m in MODELS:
            out("|".join(str(x) for x in m))
    elif cmd == "get":
        mid = int(sys.argv[2])
        key = sys.argv[3] if len(sys.argv) > 3 else "file"
        idx = {"label": I_LABEL, "file": I_FILE, "size": I_SIZE, "vram": I_VRAM,
               "mmproj": I_MMPROJ, "repo": I_REPO}[key]
        for m in MODELS:
            if m[I_ID] == mid:
                out(str(m[idx]))
                return
    elif cmd == "pick":
        choice = (sys.argv[2] if len(sys.argv) > 2 else "").strip()
        cfg_model = sys.argv[3] if len(sys.argv) > 3 else ""
        models_dir = sys.argv[4] if len(sys.argv) > 4 else ""
        picked = None
        for m in MODELS:
            if choice == str(m[I_ID]):
                picked = m
                break
        if picked is None:
            # Enter/мусорный ввод: предпочтение из config.yaml (model.default), затем первая установленная
            if cfg_model:
                for m in MODELS:
                    if m[I_FILE].replace(".gguf", "") in cfg_model or m[I_FILE] in cfg_model:
                        if os.path.exists(os.path.join(models_dir, m[I_FILE])):
                            picked = m
                            break
            if picked is None:
                for m in MODELS:
                    if os.path.exists(os.path.join(models_dir, m[I_FILE])):
                        picked = m
                        break
        if picked:
            out(f"{picked[I_ID]}|{picked[I_FILE]}|{picked[I_MMPROJ]}|{picked[I_REPO]}")
    elif cmd == "label":
        cfg_model = sys.argv[2] if len(sys.argv) > 2 else ""
        m = find_by_cfg(cfg_model)
        if m:
            out(m[I_LABEL])
    elif cmd == "resolve":
        short = (sys.argv[2] if len(sys.argv) > 2 else "").strip().lower()
        for m in MODELS:
            if short and (short == m[I_LABEL].lower() or short in m[I_FILE].lower()):
                out(m[I_FILE])
                return
    elif cmd == "menu":
        models_dir = sys.argv[2] if len(sys.argv) > 2 else ""
        for m in MODELS:
            tag = ""
            if os.path.exists(os.path.join(models_dir, m[I_FILE])):
                tag = f" {ESC}[1;32m[{m[I_FILE]}]{ESC}[0m"
            out(f"  {ESC}[1;37m[{m[I_ID]}]{ESC}[0m {ESC}[1m{m[I_LABEL]}{ESC}[0m {ESC}[2m({m[I_SIZE]}){ESC}[0m — для видеокарт с памятью (>={m[I_VRAM]} GB){tag}")
    elif cmd == "count":
        out(str(len(MODELS)))
    elif cmd == "status":
        models_dir = sys.argv[2] if len(sys.argv) > 2 else ""
        found = False
        for m in MODELS:
            if os.path.exists(os.path.join(models_dir, m[I_FILE])):
                out(f"  {ESC}[1;32m+ {ESC}[0m Модель: {ESC}[2m[{m[I_FILE]}] ({m[I_LABEL]}){ESC}[0m")
                found = True
        if not found:
            out(f"  {ESC}[1;33m. {ESC}[0m Модель: не установлена")


if __name__ == "__main__":
    main()
