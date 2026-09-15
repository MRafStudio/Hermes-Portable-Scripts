#!/usr/bin/env python3
# i18n_verify.py — быстрая проверка русификации перед сборкой (ядро workflow).
#
# Проверяет по порядку:
#   1) структура ru.ts читается (парсер), ключей не меньше порога, нет мусорных ключей
#   2) esbuild компилирует ru.ts и ru-constants.ts (синтаксис TS)
#   3) порядок ключей ru.ts совпадает с порядком en.ts (для построчного WinMerge)
#   4) сводка: непереведённые / осиротевшие
#
# Код возврата: 0 — всё в порядке (можно собирать), 1 — есть ошибки (сборку не запускать).
#
# Использование:
#   python scripts/py/i18n_verify.py [--en PATH] [--ru PATH] [--no-esbuild] [--quiet]
import argparse
import os
import subprocess
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

import compare_i18n_keys as CMP          # noqa: E402
import i18n_sort_like_en as SORT         # noqa: E402

DEFAULT_EN = os.path.join(_HERE, "..", "en-locale", "en.ts")
DEFAULT_RU = os.path.join(_HERE, "..", "ru-locale", "ru.ts")
DEFAULT_RU_CONST = os.path.join(_HERE, "..", "ru-locale", "ru-constants.ts")

# esbuild в node_modules репозитория Hermes (быстрая транспиляция без сборки)
ESBUILD_CANDIDATES = [
    os.path.join(_HERE, "..", "..", "data", "hermes", "hermes-agent", "node_modules",
                 "@esbuild", "win32-x64", "esbuild.exe"),
    os.path.join(_HERE, "..", "..", "data", "hermes", "hermes-agent", "apps", "desktop",
                 "node_modules", "@esbuild", "win32-x64", "esbuild.exe"),
]


def find_esbuild():
    for c in ESBUILD_CANDIDATES:
        if os.path.exists(c):
            return os.path.abspath(c)
    return None


def esbuild_check(exe, path, tmp_dir):
    out = os.path.join(tmp_dir, "i18n-verify-out.js")
    r = subprocess.run([exe, path, "--outfile=" + out, "--log-level=warning"],
                       capture_output=True, text=True, timeout=120,
                       encoding="utf-8", errors="replace")
    try:
        os.remove(out)
    except OSError:
        pass
    return r.returncode == 0, (r.stdout or "") + (r.stderr or "")


def main():
    ap = argparse.ArgumentParser(description="Проверка русификации перед сборкой")
    ap.add_argument("--en", default=DEFAULT_EN)
    ap.add_argument("--ru", default=DEFAULT_RU)
    ap.add_argument("--ru-const", default=DEFAULT_RU_CONST)
    ap.add_argument("--no-esbuild", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    ok = True
    problems = []

    def say(msg):
        if not args.quiet:
            print(msg)

    # ---------- 1) структура ----------
    try:
        src = open(args.ru, encoding="utf-8", newline="").read()
        _ro, _rc, ru_children = SORT.parse_text(src, "defineLocale(")
        _esrc = open(args.en, encoding="utf-8", newline="").read()
        _eo, _ec, en_children = SORT.parse_text(_esrc, "Translations = ")
    except SystemExit as ex:
        print("[ОШИБКА] не разобрать ru.ts: %s" % ex)
        return 1

    leaves = SORT.collect_leaves(src, "defineLocale(")
    n_keys = len(leaves)
    if n_keys < 3000:
        ok = False
        problems.append("ключей в ru.ts всего %d — структура сломана?" % n_keys)

    bad_keys = [k for k in leaves if k.endswith(".as") or k.endswith(".string") or "?unparsed?" in k]
    if bad_keys:
        ok = False
        problems.append("мусорные ключи (TS-приведение разобрано как ключ): %s" % bad_keys[:5])

    say("  [1/4] структура ru.ts: ключей %d%s" % (n_keys, "" if ok else "  <-- ПРОБЛЕМА"))

    # ---------- 2) esbuild ----------
    exe = None if args.no_esbuild else find_esbuild()
    if args.no_esbuild:
        say("  [2/4] esbuild: пропущен (--no-esbuild)")
    elif exe is None:
        say("  [2/4] esbuild: НЕ НАЙДЕН (проверка синтаксиса пропущена)")
    else:
        tmp_dir = os.path.dirname(os.path.abspath(args.ru))
        good_ru, log_ru = esbuild_check(exe, args.ru, tmp_dir)
        good_c, log_c = esbuild_check(exe, args.ru_const, tmp_dir) if os.path.exists(args.ru_const) else (True, "")
        if good_ru and good_c:
            say("  [2/4] esbuild: синтаксис ru.ts и ru-constants.ts — OK")
        else:
            ok = False
            problems.append("esbuild: синтаксис сломан")
            print(log_ru or log_c)

    # ---------- 3) порядок как в en ----------
    en_entries = CMP.parse_locale(args.en)
    en_order_list = [p for p, k, t in en_entries if p and k not in ("obj", "arr")]
    ru_paths = list(leaves.keys())
    if en_order_list:
        pos = {k: i for i, k in enumerate(en_order_list)}
        seq = [pos[k] for k in ru_paths if k in pos]
        violations = sum(1 for a, b in zip(seq, seq[1:]) if b < a)
        if violations == 0:
            say("  [3/4] порядок ключей: соответствует en.ts")
        else:
            ok = False
            problems.append("порядок ключей нарушен в %d местах (нужен i18n_sort_like_en.py)" % violations)
            say("  [3/4] порядок ключей: %d нарушений" % violations)
    else:
        say("  [3/4] порядок ключей: проверка недоступна")

    # ---------- 4) сводка ----------
    try:
        en_leaves, _es = CMP.split(CMP.parse_locale(args.en))
        ru_leaves_map, _rs = CMP.split(CMP.parse_locale(args.ru))
        missing = [k for k in en_leaves if k not in ru_leaves_map]
        orphans = [k for k in ru_leaves_map if k not in en_leaves]
        say("  [4/4] непереведённых: %d, осиротевших: %d (не блокирует сборку)" % (len(missing), len(orphans)))
    except Exception as ex:  # noqa: BLE001
        say("  [4/4] сводка недоступна: %s" % ex)

    print()
    if ok:
        print("ИТОГ: проверка пройдена — можно собирать (Tools.bat [5])")
        return 0
    print("ИТОГ: ЕСТЬ ОШИБКИ — сборку не запускать:")
    for p in problems:
        print("  - %s" % p)
    return 1


if __name__ == "__main__":
    sys.exit(main())
