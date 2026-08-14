# llama_models.py — справочник разрешённых моделей Llama.cpp и их проекторов (mmproj)
# Каждая запись: (id, КОРОТКОЕ имя, ПОЛНОЕ имя с .gguf, размер, мин. VRAM GB,
#                 mmproj_ЛОКАЛЬНОЕ (после переименования), repo, max_ctx, mmproj_ИСТИННОЕ (в репо — для скачивания))
# Правило: скачивать по ИСТИННОМУ имени → переименовывать в ЛОКАЛЬНОЕ (mmproj-<модель>…) — единое место истины!
#   Пример: (1, "Gemma-4-26B-A4B UD-IQ4_NL", "gemma-4-26B-A4B-it-UD-IQ4_NL.gguf", "13.6 GB", 20,
#            "mmproj-Gemma-27B-F16.gguf", "unsloth/gemma-4-26B-A4B-it-GGUF", 262144, "mmproj-F16.gguf")
# ВАЖНО: полное имя ОБЯЗАТЕЛЬНО с расширением .gguf (имя файла на диске; в model.default оно без
# расширения — сопоставление в pick/label учитывает это). repo — путь для скачивания с Hugging Face.
# max_ctx — рекомендуемый контекст llmcpp для этой модели (KV-кэш должен влезать в VRAM).
# Несколько моделей могут делить один mmproj; у каждой модели может быть свой mmproj и repo.
# При добавлении новой модели ДОБАВЬ строку в MODELS — меню, статусы и загрузка
# в InstallOrUpdate-Llama.bat обновятся автоматически (скрипт читает этот справочник).
#
# CLI:
#   list                 — все записи: id|label|file|size|vram|mmproj|repo|maxctx
#   get <id> <key>       — одно поле (label|file|size|vram|mmproj|repo|maxctx)
#   pick <choice> <cfg_model> <models_dir> — выбор модели (1/2/Enter→cfg_model→установленная)
#                          печатает "id|file|mmproj|repo|maxctx" или ничего
#   label <cfg_model>    — короткое имя модели по model.default (для подсказки "[Enter = ...]")
#   resolve <short_name> — ПОЛНОЕ имя файла по короткому имени (или пусто)
#   menu <models_dir>    — строки меню выбора (с пометкой [файл] для установленных)
#   status <models_dir>  — статус-строки установленных моделей (все!)
#   count                — число моделей
import os
import sys

REPO_DEFAULT = "unsloth/Qwen3.6-35B-A3B-GGUF"

MODELS = [
    # (id, короткое имя, полное имя с .gguf, размер, мин. VRAM GB, mmproj_ЛОКАЛЬНОЕ, repo, max_ctx, mmproj_ИСТИННОЕ)
    # ==============================================================================================================
    # Базовая модель но для видеокарт начиная с 24Gb
    (1, "Qwen-3.6-35B-A3B UD-IQ4_NL", "Qwen3.6-35B-A3B-UD-IQ4_NL.gguf", "18.0 GB", 24,
     "mmproj-Qwen-35B-F16.gguf", "unsloth/Qwen3.6-35B-A3B-GGUF", 262144,
     "mmproj-F16.gguf", 1),
    # Ближайший конкурент Qwen3.6 при меньших потребностях
    # ВНИМАНИЕ: mmproj-F16.gguf из репо НЕ грузится (image_max_pixels < image_min_pixels) - только BF16!
    (2, "Gemma-4-26B-A4B  UD-IQ4_NL", "gemma-4-26B-A4B-it-UD-IQ4_NL.gguf", "13.6 GB", 20,
     "mmproj-Gemma-26B-BF16.gguf", "unsloth/gemma-4-26B-A4B-it-GGUF", 262144,
     "mmproj-BF16.gguf", 0),
    # С натяжкой: 128 контекста это буквально впритык для Hermes
    (3, "Gemma-3-12B     UD-Q4_K_XL", "gemma-3-12b-it-UD-Q4_K_XL.gguf", "7.43 GB", 11,
     "mmproj-Gemma-12B-F16.gguf", "unsloth/gemma-3-12b-it-GGUF", 131072,
     "mmproj-F16.gguf", 1),
    #
    (4, "Qwythos-9B 5-1M MTP-Q4_K_M", "Qwythos-9B-Claude-Mythos-5-1M-MTP-Q4_K_M.gguf", "5.89 GB", 16,
     "mmproj-Qwythos-9B-F16.gguf", "empero-ai/Qwythos-9B-Claude-Mythos-5-1M-GGUF", 524288,
     "mmproj-Qwythos-9B-Claude-Mythos-5-1M-F16.gguf", 1),
]

ESC = "\x1b"

# индексы полей
I_ID, I_LABEL, I_FILE, I_SIZE, I_VRAM, I_MMPROJ, I_REPO, I_MAXCTX, I_MMPROJ_SRC, I_THINKING = range(10)
# I_THINKING: 1 = думание включено (enable_thinking по умолчанию/true), 0 = выключено
# (--chat-template-kwargs {"enable_thinking":false} в llama-server; для агентских циклов с tool-calling)


def out(s):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    sys.stdout.write(s + "\n")


def find_by_cfg(cfg_model):
    """model.default (llmcpp/имя-без-.gguf) → запись или None."""
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
        # короткое имя + размер; при наличии models_dir - маркер установки (+/-)
        models_dir = sys.argv[2] if len(sys.argv) > 2 else ""
        w = max(len(m[I_LABEL]) for m in MODELS)
        for m in MODELS:
            if models_dir:
                if os.path.exists(os.path.join(models_dir, m[I_FILE])):
                    mark = f"{ESC}[1;32m+{ESC}[0m"
                else:
                    mark = f"{ESC}[1;33m-{ESC}[0m"
                out(f"{m[I_ID]}. {mark} {m[I_LABEL]:<{w}}  {m[I_SIZE]}")
            else:
                out(f"{m[I_ID]}. {m[I_LABEL]:<{w}}  {m[I_SIZE]}")
    elif cmd == "get":
        mid = int(sys.argv[2])
        key = sys.argv[3] if len(sys.argv) > 3 else "file"
        idx = {"label": I_LABEL, "file": I_FILE, "size": I_SIZE, "vram": I_VRAM,
               "mmproj": I_MMPROJ, "repo": I_REPO, "maxctx": I_MAXCTX,
               "mmprojsrc": I_MMPROJ_SRC}[key]
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
            out(f"{picked[I_ID]}|{picked[I_FILE]}|{picked[I_MMPROJ]}|{picked[I_REPO]}|{picked[I_MAXCTX]}|{picked[I_MMPROJ_SRC]}|{picked[I_LABEL]}|llama/{picked[I_FILE][:-5]}|{picked[I_THINKING]}")
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
    elif cmd == "installed":
        models_dir = sys.argv[2] if len(sys.argv) > 2 else ""
        for m in MODELS:
            if os.path.exists(os.path.join(models_dir, m[I_FILE])):
                out(f"{m[I_ID]}|{m[I_LABEL]}")
    elif cmd == "count":
        out(str(len(MODELS)))
    elif cmd == "thinking_flag":
        # Файловый обмен: python собирает флаг с ПРАВИЛЬНЫМ экранированием для cmd,
        # .bat читает его через set /p (никаких кавычек-танцев в .bat!)
        # usage: thinking_flag <start|nssm> <0|1>
        # ВАЖНО: --chat-template-kwargs {"enable_thinking":false} — deprecated (llama.cpp build 10425);
        # правильный флаг: --reasoning off
        thinking = (sys.argv[3] if len(sys.argv) > 3 else "1").strip()
        if thinking != "0":
            out("")
        else:
            out("--reasoning off")
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
