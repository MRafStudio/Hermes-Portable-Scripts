#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# i18n_verify.py — проверка русификации по схеме A перед сборкой (ядро workflow).
#
#   [1/5] структура: ru-layer.ts парсится, непустой, ключи уникальны
#   [2/5] esbuild: синтаксис ru-layer.ts (эталон) и ru.ts/ru-layer.ts в репозитории
#   [3/5] ключи слоя: нет мёртвых (все есть в полном en; подписи полей — под своими ключами)
#   [4/5] установка: ru.ts в репозитории = апстримный + подключение слоя; слой совпадает
#   [5/5] сводка: покрытие, дыры (сколько осталось переводить)
#
# Код возврата: 0 — можно собирать, 1 — ошибки (сборку не запускать).
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import i18n_refs as REFS  # noqa: E402

SCRIPTS = os.path.dirname(HERE)
ROOT = os.path.dirname(SCRIPTS)
REPO = os.path.join(ROOT, "data", "hermes", "hermes-agent")
I18N = os.path.join(REPO, "apps", "desktop", "src", "i18n")
LAYER_SRC = os.path.join(SCRIPTS, "ru-locale", "ru-layer.ts")
LAYER_REPO = os.path.join(I18N, "ru-layer.ts")
RU_REPO = os.path.join(I18N, "ru.ts")
RU_LINE_NEW = "defineLocale(mergeTranslations(ruOverrides, ruLayerOverrides))"

ESBUILD_CANDIDATES = [
    os.path.join(REPO, "node_modules", "@esbuild", "win32-x64", "esbuild.exe"),
    os.path.join(REPO, "apps", "desktop", "node_modules", "@esbuild", "win32-x64", "esbuild.exe"),
]


TS_CANDIDATES = [
    os.path.join(REPO, "node_modules", "typescript", "lib", "typescript.js"),
    os.path.join(REPO, "apps", "desktop", "node_modules", "typescript", "lib", "typescript.js"),
]
TS_CHECK_JS = os.path.join(HERE, "ts_check.js")


def find_esbuild():
    for c in ESBUILD_CANDIDATES:
        if os.path.exists(c):
            return c
    return None


def find_ts():
    """typescript.js из репозитория Hermes (esbuild после перехода на rolldown больше не ставится)."""
    if not os.path.exists(TS_CHECK_JS):
        return None
    for c in TS_CANDIDATES:
        if os.path.exists(c):
            return c
    return None


def ts_ok(tslib, path):
    r = subprocess.run(["node", TS_CHECK_JS, path, tslib],
                       capture_output=True, text=True, timeout=180,
                       encoding="utf-8", errors="replace")
    return r.returncode == 0, (r.stdout or "") + (r.stderr or "")


def esbuild_ok(exe, path, tmp):
    out = os.path.join(tmp, "i18n-verify-out.js")
    r = subprocess.run([exe, path, "--outfile=" + out, "--log-level=warning"],
                       capture_output=True, text=True, timeout=120,
                       encoding="utf-8", errors="replace")
    try:
        os.remove(out)
    except OSError:
        pass
    return r.returncode == 0, (r.stdout or "") + (r.stderr or "")


def main():
    ap = argparse.ArgumentParser(description="Проверка русификации (схема A)")
    ap.add_argument("--no-esbuild", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    ok = True
    problems = []

    def say(m):
        if not args.quiet:
            print(m)

    # ---------- 1) структура слоя ----------
    if not os.path.exists(LAYER_SRC):
        print("[ОШИБКА] нет %s" % LAYER_SRC)
        return 1
    src = open(LAYER_SRC, encoding="utf-8", newline="").read()
    try:
        layer = REFS.parse_leaves(src, "export const ruLayerOverrides")
    except SystemExit as ex:
        print("[ОШИБКА] не разобрать ru-layer.ts: %s" % ex)
        return 1
    if len(layer) < 100:
        ok = False
        problems.append("в слое всего %d ключей — структура сломана?" % len(layer))
    say("  [1/5] структура ru-layer.ts: ключей %d%s" % (len(layer), "" if ok else "  <-- ПРОБЛЕМА"))

    # ---------- 2) синтаксис: esbuild, если есть; иначе tsc через node ----------
    if args.no_esbuild:
        say("  [2/5] синтаксис: пропущен (--no-esbuild)")
    else:
        exe = find_esbuild()
        tslib = None if exe else find_ts()
        tool = "esbuild" if exe else ("tsc" if tslib else None)
        files = [("ru-layer.ts (эталон)", LAYER_SRC)]
        if os.path.exists(LAYER_REPO):
            files.append(("ru-layer.ts (репо)", LAYER_REPO))
        if os.path.exists(RU_REPO):
            files.append(("ru.ts (репо)", RU_REPO))
        targets = []
        if tool == "esbuild":
            tmp = os.path.join(ROOT, "data", "temp")
            os.makedirs(tmp, exist_ok=True)
            for name, path in files:
                g, l = esbuild_ok(exe, path, tmp)
                targets.append((name, g, l))
        elif tool == "tsc":
            try:
                for name, path in files:
                    g, l = ts_ok(tslib, path)
                    targets.append((name, g, l))
            except FileNotFoundError:
                tool = None
                targets = []

        if not targets:
            say("  [2/5] синтаксис: НЕ проверен (нет ни esbuild, ни node+typescript)")
        else:
            bad = [n for n, g, _ in targets if not g]
            if bad:
                ok = False
                problems.append("%s: синтаксис сломан в %s" % (tool, ", ".join(bad)))
                for n, g, l in targets:
                    if not g:
                        print(l)
                say("  [2/5] %s: ПРОБЛЕМА (%s)" % (tool, ", ".join(bad)))
            else:
                say("  [2/5] %s: синтаксис OK (%s)" % (tool, ", ".join(n for n, _, _ in targets)))

    # ---------- 3) ключи слоя ----------
    en = REFS.full_en()
    dead = [k for k in layer if k not in en
            and not ((k.startswith("settings.fieldLabels.") or k.startswith("settings.fieldDescriptions."))
                     and "settings." + k.split(".")[1] in en)]
    if dead:
        ok = False
        problems.append("мёртвые ключи в слое (%d): %s -> удалите из scripts/ru-locale/ru.ts" %
                        (len(dead), dead[:5]))
        say("  [3/5] ключи слоя: мёртвых %d  <-- ПРОБЛЕМА" % len(dead))
    else:
        say("  [3/5] ключи слоя: все %d живые" % len(layer))

    # ---------- 4) установка в репозиторий ----------
    inst = []
    if not os.path.exists(RU_REPO):
        inst.append("ru.ts не установлен")
    else:
        ru = open(RU_REPO, encoding="utf-8", newline="").read()
        if RU_LINE_NEW not in ru:
            inst.append("в ru.ts нет подключения слоя (%s)" % RU_LINE_NEW)
        if "ru-layer" not in ru:
            inst.append("в ru.ts нет импорта './ru-layer'")
    if os.path.exists(LAYER_REPO):
        a = open(LAYER_SRC, encoding="utf-8", newline="").read()
        b = open(LAYER_REPO, encoding="utf-8", newline="").read()
        if a.replace("\r\n", "\n") != b.replace("\r\n", "\n"):
            inst.append("ru-layer.ts в репозитории отличается от эталона -> переустановите")
    else:
        inst.append("ru-layer.ts не установлен в репозиторий")
    if inst:
        ok = False
        problems.extend(inst)
        say("  [4/5] установка: ПРОБЛЕМА (%s)" % "; ".join(inst))
    else:
        say("  [4/5] установка: ru.ts = апстрим + слой, ru-layer.ts совпадает")

    # ---------- 5) сводка ----------
    up = REFS.upstream_ru()
    total = dict(up)
    total.update(layer)
    holes = [k for k in en if k not in total]
    english = [k for k in en if k in total and total[k] == en[k]]
    say("  [5/5] покрытие: %d из %d (%.0f%%) | дыр %d | англ. текстом %d" %
        (len(en) - len(holes), len(en), 100.0 * (len(en) - len(holes)) / len(en),
         len(holes), len(english)))

    # ---------- слой устарел? ----------
    try:
        stale = os.path.getmtime(REFS.OUR_RU) > os.path.getmtime(LAYER_SRC) + 1
    except OSError:
        stale = False
    if stale:
        ok = False
        problems.append("слой ru-layer.ts старше ru.ts — пересоберите (Tools.bat [9] или i18n_build_layer.py), иначе новые переводы не доедут до сборки")
        say("  [!] слой устарел: ru.ts новее, чем ru-layer.ts")

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
