# -*- coding: utf-8 -*-
"""Сводка экономии headroom-прокси (127.0.0.1:8787)."""
import json
import urllib.request
import sys

BASE = "http://127.0.0.1:8787"


def get(path, timeout=8):
    try:
        with urllib.request.urlopen(BASE + path, timeout=timeout) as r:
            return json.loads(r.read().decode("utf-8"))
    except Exception as e:
        print("✖ Прокси headroom не отвечает:", e)
        print("  Проверь службу:  services.msc  ->  Headroom")
        sys.exit(1)


def pct(saved, total):
    return saved / max(total + saved, 1) * 100.0


def main():
    print("=" * 52)
    print("  HEADROOM — сводка экономии токенов")
    print("=" * 52)

    health = get("/health")
    print("Прокси: %s | v%s | аптайм %.1f мин" % (
        health.get("status", "?"), health.get("version", "?"),
        health.get("uptime_seconds", 0) / 60))

    d = get("/stats-history")
    s = d.get("display_session", {})
    lt = d.get("lifetime", {})

    print("\n--- ТЕКУЩАЯ СЕССИЯ ---")
    print("Запросов:          %d" % s.get("requests", 0))
    print("Токенов сэкономлено: %d  (%.2f%%)" % (
        s.get("tokens_saved", 0), s.get("savings_percent", 0)))
    print("Денег сэкономлено: $%.5f" % s.get("compression_savings_usd", 0))
    print("Входных токенов:   %d  (стоимость $%.5f)" % (
        s.get("total_input_tokens", 0), s.get("total_input_cost_usd", 0)))

    bm = d.get("by_model", {})
    if bm:
        print("\n--- ПО МОДЕЛЯМ ---")
        for m, v in bm.items():
            print("  %-22s %3d запр. | saved %6d (%.2f%%)" % (
                m, v.get("requests", 0), v.get("tokens_saved", 0),
                v.get("savings_percent", 0)))

    print("\n--- ЗА ВСЁ ВРЕМЯ (lifetime) ---")
    print("Запросов: %d | saved %d токенов ($%.5f)" % (
        lt.get("requests", 0), lt.get("tokens_saved", 0),
        lt.get("compression_savings_usd", 0)))
    print("Вход: %d токенов, $%.5f" % (
        lt.get("total_input_tokens", 0), lt.get("total_input_cost_usd", 0)))
    print("\nПодробная статистика:  http://127.0.0.1:8787/stats-history")


if __name__ == "__main__":
    main()
