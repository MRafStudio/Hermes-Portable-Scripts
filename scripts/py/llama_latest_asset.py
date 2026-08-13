#!/usr/bin/env python3
"""llama_latest_asset.py - browser_download_url ассета llama.cpp (CUDA 13.3, win-x64).

llama.cpp переименовал ассеты: llama-<build>-bin-win-cuda-13.3-x64.zip (с номером билда!)
Старое имя llama-bin-win-... больше не существует (404). Установщик должен брать
имя из GitHub API (releases/latest).

Вывод: browser_download_url ассета, например
  https://github.com/ggml-org/llama.cpp/releases/download/b10375/llama-b10375-bin-win-cuda-13.3-x64.zip
(или пусто при ошибке / недоступном API).

ВАЖНО: прямые github.com-ссылки из РФ режутся для curl (52 Empty reply), но
через локальный прокси 127.0.0.1:10809 качаются (проверено). Скрипт-установщик
качает :download: сначала напрямую, при падении - через прокси.

Использование:
  llama_latest_asset.py                  # основной bin-ассет (llama-*cuda-13.3-x64)
  llama_latest_asset.py <подстрока>      # любой ассет по подстроке имени
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
    assets = d.get("assets", [])
    if len(sys.argv) > 1:
        # фильтр по подстроке имени (например: cudart-llama-bin-win-cuda-13.3-x64)
        f = sys.argv[1]
        cand = [a for a in assets if f in a["name"]]
    else:
        # приоритет: llama-*bin-win-cuda-13.3-x64 (CUDA 13.3 для Blackwell/5090!)
        want = "cuda-13.3-x64"
        cand = [a for a in assets if a["name"].startswith("llama-") and want in a["name"]]
    if cand:
        print(cand[0]["browser_download_url"])
        return 0
    print("")
    return 1


if __name__ == "__main__":
    sys.exit(main())
