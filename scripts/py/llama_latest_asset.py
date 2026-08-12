#!/usr/bin/env python3
"""llama_latest_asset.py - получение имени актуального ассета llama.cpp (CUDA 13.3, win-x64).

llama.cpp переименовал ассеты: llama-<build>-bin-win-cuda-13.3-x64.zip (с номером билда!)
Старое имя llama-bin-win-... больше не существует (404). Установщик должен брать
имя из GitHub API (releases/latest).
Вывод: <asset_name> (или пусто при ошибке).
"""
import json
import sys
import urllib.request

URL = "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest"
REQ = urllib.request.Request(URL, headers={"User-Agent": "hermes-portable"})


def main():
    try:
        d = json.load(urllib.request.urlopen(REQ, timeout=20))
    except Exception:
        print("")
        return 1
    # приоритет: llama-*bin-win-cuda-13.3-x64 (CUDA 13.3 для Blackwell/5090!)
    names = [a["name"] for a in d.get("assets", [])]
    want = "cuda-13.3-x64"
    cand = [n for n in names if n.startswith("llama-") and want in n]
    if cand:
        # берём НЕ cudart (это отдельный архив) - сюда попадают только llama-*bin-*
        print(cand[0])
        return 0
    print("")
    return 1


if __name__ == "__main__":
    sys.exit(main())
