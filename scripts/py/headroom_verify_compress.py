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
    # Ждём готовности kompress до 180 сек (первый запуск грузит ONNX-модель,
    # а служба после рестарта может не слушать порт ещё ~30-60 сек).
    k = {}
    for _ in range(36):
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
            print("health: ожидание старта службы (%s)... %ds" % (
                type(e).__name__, (_ + 1) * 5))
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


def warmup() -> None:
    """Прогрев ленивой ONNX-модели. kompress.ready=true в health НЕ значит,
    что модель загружена — она грузится при первом /v1/compress. Первый
    «холостой» запрос без учёта результата просто заставляет headroom
    загрузить модель, чтобы боевой замер не попал на прогревочные noop."""
    import uuid
    text = ("Прогрев модели компрессии. " * 200) + uuid.uuid4().hex
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
        with urllib.request.urlopen(req, timeout=180) as r:
            r.read()
        print("warmup: запрос на прогрев отправлен")
    except Exception as e:
        print("warmup: (%s) — прогревочный запрос, игнорируем" % type(e).__name__)


def main() -> int:
    # Порядок критичен: модель грузится ЛЕНИВО при первом /v1/compress.
    # 1) прогрев (первый запрос — noop, модель грузится в фоне)
    # 2) ожидание ready=true (после прогрева наступит)
    # 3) боевой замер (второй запрос уже сжимает)
    warmup()
    ok_health = check_health()
    if not ok_health:
        print("VERIFY_FAIL")
        return 1
    ok_compress = check_compress()
    if ok_health and ok_compress:
        print("VERIFY_OK")
        return 0
    print("VERIFY_FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main())
