# -*- coding: utf-8 -*-
"""Проверка, что headroom РЕАЛЬНО сжимает контекст.

1. health: kompress.ready == true и backend != null
2. Реальный запрос /v1/compress: ratio < 0.9 и transforms != noop
Возвращает 0 при полном успехе, 1 при любой проблеме (с детальным сообщением).
"""
import json
import sys
import time
import urllib.request

BASE = "http://127.0.0.1:8787"


def check_health() -> bool:
    import time
    # Ждём готовности kompress до 60 сек (первый запуск грузит модель)
    for _ in range(12):
        try:
            with urllib.request.urlopen(BASE + "/health", timeout=10) as r:
                d = json.loads(r.read())
            k = d.get("checks", {}).get("kompress", {})
            if k.get("ready") is True and k.get("backend"):
                print("health kompress: ready=%s backend=%s status=%s" % (
                    k.get("ready"), k.get("backend"), k.get("status")))
                return True
            print("health kompress: готовится (ready=%s backend=%s)... %ds" % (
                k.get("ready"), k.get("backend"), (_ + 1) * 5))
        except Exception as e:
            print("health: ожидание старта (%s)..." % (type(e).__name__))
        time.sleep(5)
    print("FAIL: kompress так и не стал готов (backend=%r)" % k.get("backend"))
    return False


def check_compress() -> bool:
    # Уникальный маркер — чтобы не попасть в закешированный noop-ответ
    # (первый запрос мог уйти до готовности kompress и закешироваться).
    import uuid
    marker = uuid.uuid4().hex[:8]
    text = ("Это тестовый длинный текст для проверки компрессии контекста. "
            "Он повторяется много раз, чтобы модель наверняка нашла что сжать. "
            "Маркер проверки %s. ") % marker
    text = text * 300
    payload = {
        "messages": [{"role": "user", "content": text}],
        "model": "deepseek-v4-flash",
        "config": {"compress_user_messages": True, "target_ratio": 0.4},
    }
    req = urllib.request.Request(
        BASE + "/v1/compress",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
    )
    try:
        t0 = time.time()
        with urllib.request.urlopen(req, timeout=180) as r:
            d = json.loads(r.read())
        dt = time.time() - t0
        ratio = d.get("compression_ratio", 1.0)
        transforms = d.get("transforms_applied", [])
        before = d.get("tokens_before")
        after = d.get("tokens_after")
        saved = d.get("tokens_saved")
        print("compress: %s -> %s (saved %s), ratio=%.3f, transforms=%s, %.1fs" % (
            before, after, saved, ratio, transforms, dt))
        if d.get("compression_skipped"):
            print("FAIL: compression_skipped=%s reason=%s" % (
                d.get("compression_skipped"), d.get("skip_reason")))
            return False
        if ratio >= 0.9:
            print("FAIL: ratio %.3f >= 0.9 — сжатия нет" % ratio)
            return False
        if not transforms or "noop" in str(transforms):
            print("FAIL: transforms=%s — noop" % transforms)
            return False
        print("OK: компрессия работает, экономия %.0f%%" % ((1 - ratio) * 100))
        return True
    except Exception as e:
        print("FAIL: /v1/compress:", type(e).__name__, str(e)[:200])
        return False


def main() -> int:
    ok_health = check_health()
    ok_compress = check_compress()
    if ok_health and ok_compress:
        print("VERIFY_OK")
        return 0
    print("VERIFY_FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
