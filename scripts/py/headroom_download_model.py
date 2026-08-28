# -*- coding: utf-8 -*-
"""Скачивание модели Kompress (chopratejas/kompress-v2-base) для headroom.

Пытается напрямую, при неудаче — через прокси 127.0.0.1:10809 (v2ray).
Возвращает 0 при успехе, 1 при неудаче. HF_HOME берёт из окружения.
"""
import os
import sys

HF_MODEL = "chopratejas/kompress-v2-base"
PROXY = "http://127.0.0.1:10809"

os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS", "1")
os.environ.setdefault("HF_HUB_DISABLE_SYMLINKS_WARNING", "1")


def _download(proxy: str | None) -> str:
    if proxy:
        os.environ["HTTPS_PROXY"] = proxy
        os.environ["HTTP_PROXY"] = proxy
    else:
        os.environ.pop("HTTPS_PROXY", None)
        os.environ.pop("HTTP_PROXY", None)
    from huggingface_hub import snapshot_download

    return snapshot_download(HF_MODEL)


def _check_onnx() -> bool:
    """Проверяем, что ONNX-артефакты на месте (иначе kompress не поднимется)."""
    from huggingface_hub import try_to_load_from_cache

    for fname in ("onnx/kompress-int8-wo.onnx", "onnx/kompress-fp32.onnx"):
        p = try_to_load_from_cache(HF_MODEL, fname)
        if not p:
            print("MISSING:", fname)
            return False
        print("FOUND:", fname, "->", p)
    return True


def main() -> int:
    try:
        p = _download(None)
        print("OK_DIRECT:", p)
    except Exception as e1:
        print("DIRECT_FAIL:", type(e1).__name__, str(e1)[:200])
        try:
            p = _download(PROXY)
            print("OK_VIA_PROXY:", p)
        except Exception as e2:
            print("PROXY_FAIL:", type(e2).__name__, str(e2)[:200])
            return 1
    if not _check_onnx():
        return 1
    print("MODEL_READY")
    return 0


if __name__ == "__main__":
    sys.exit(main())
