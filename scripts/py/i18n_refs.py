#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# i18n_refs.py — ЯДРО: полный словарь en и апстримный ru (с разворотом модулей).
#
# Зачем: с ~v1.0 апстрим Hermes разбил локали на модули (en_boot.ts, en_onboarding.ts, ...).
# Главный en.ts подключает их как `boot: enBoot.boot` (секция) или `...enNotices` (спред),
# а текст лежит в отдельном файле. Инструменты, читающие только en.ts, теряют ~500 ключей
# и показывают ложные «дыры». Здесь модули разворачиваются обратно в один плоский словарь.
#
# Эталоны (синхронизирует i18n_sync_refs.py):
#   scripts/en-locale/        en.ts + en_*.ts + en-constants.ts
#   scripts/upstream-locale/  ru.ts (апстрим) + ru_*.ts   — база схемы A
#
# Использование:
#   python scripts/py/i18n_refs.py --stats            # сводка
#   python scripts/py/i18n_refs.py --flat DIR         # en.flat / upstream-ru.flat / our-ru.flat
import argparse
import re
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import i18n_sort_like_en as SORT  # noqa: E402

SCRIPTS = os.path.dirname(HERE)
EN_DIR = os.path.join(SCRIPTS, "en-locale")
UP_DIR = os.path.join(SCRIPTS, "upstream-locale")
OUR_RU = os.path.join(SCRIPTS, "ru-locale", "ru.ts")

MOD_RE = re.compile(r"import\s*\{([^}]+)\}\s*from\s*'\./([a-z_0-9]+)'")
REF_RE = re.compile(r"^\s*\.\.\.((?:en|ru)[A-Z]\w*)", re.M)
CYR = re.compile(r"[А-Яа-яЁё]")


def parse_leaves(src, marker):
    """path -> raw-значение (фрагмент источника как есть)."""
    out = {}
    _o, _c, ch = SORT.parse_text(src, marker)

    def walk(ch2, p):
        for c in ch2:
            kp = (p + "." + c.key) if p else c.key
            if c.kind == "obj" and c.children is not None:
                walk(c.children, kp)
            else:
                out[kp] = src[c.val_start:c.val_end].strip()
    walk(ch, "")
    return out


def collect(base_path, marker, mod_dir):
    """Плоский словарь главного файла + развёрнутые модули."""
    src = open(base_path, encoding="utf-8", newline="").read()
    vals = parse_leaves(src, marker)
    mods = {}
    for m in MOD_RE.finditer(src):
        for name in m.group(1).split(","):
            name = name.strip()
            if re.match(r"^(?:en|ru)[A-Z]", name):
                mods.setdefault(name, os.path.join(mod_dir, m.group(2) + ".ts"))
    mod_leaves = {}
    for name, path in mods.items():
        if not os.path.exists(path):
            continue
        msrc = open(path, encoding="utf-8", newline="").read()
        try:
            mod_leaves[name] = parse_leaves(msrc, "export const " + name)
        except SystemExit:
            pass
    for k, v in list(vals.items()):
        mm = re.match(r"^((?:en|ru)[A-Z]\w*)(?:\.([\w.]+))?$", v)
        if mm and mm.group(1) in mod_leaves:
            mod, sub = mm.group(1), mm.group(2)
            del vals[k]
            for mk, mv in mod_leaves[mod].items():
                if not sub:
                    vals[k + "." + mk] = mv
                elif mk == sub or mk.startswith(sub + "."):
                    rest = mk[len(sub):].lstrip(".")
                    vals[k + ("." + rest if rest else "")] = mv
    for m in REF_RE.finditer(src):
        name = m.group(1)
        if name in mod_leaves:
            vals.update(mod_leaves[name])
    return vals


def full_en():
    return collect(os.path.join(EN_DIR, "en.ts"), "Translations = ", EN_DIR)


def upstream_ru():
    return collect(os.path.join(UP_DIR, "ru.ts"), "export const ru", UP_DIR)


def our_ru():
    return parse_leaves(open(OUR_RU, encoding="utf-8", newline="").read(), "defineLocale(")


def is_ru(raw):
    return bool(raw) and raw not in ("''", '""', "``") and CYR.search(raw) is not None


def flat_value(raw):
    s = str(raw).replace(chr(92), chr(92) * 2)
    for ch, rep in ((chr(13), chr(92) + "r"), (chr(10), chr(92) + "n"), (chr(9), chr(92) + "t")):
        s = s.replace(ch, rep)
    return s


def main():
    ap = argparse.ArgumentParser(description="Ядро локализации: полный en + апстримный ru")
    ap.add_argument("--stats", action="store_true")
    ap.add_argument("--flat", metavar="DIR", help="записать en.flat / upstream-ru.flat / our-ru.flat")
    args = ap.parse_args()

    en = full_en()
    up = upstream_ru()
    our = our_ru()

    if args.flat:
        out = os.path.abspath(args.flat)
        os.makedirs(out, exist_ok=True)
        for name, d in (("en.flat", en), ("upstream-ru.flat", up), ("our-ru.flat", our)):
            with open(os.path.join(out, name), "w", encoding="utf-8", newline="\n") as f:
                for k in en:
                    if k in d:
                        f.write("%s = %s\n" % (k, flat_value(d[k])))
        print("  записано: %s (en.flat, upstream-ru.flat, our-ru.flat)" % out)

    if args.stats or not args.flat:
        miss_our = [k for k in en if k not in our]
        miss_up = [k for k in en if k not in up]
        our_tr = [k for k in our if k in en and is_ru(our[k]) and our[k] != en[k]]
        up_tr = [k for k in up if k in en and is_ru(up[k]) and up[k] != en[k]]
        layer = [k for k in our_tr if k not in up or not is_ru(up.get(k, ""))]
        holes = [k for k in en if k not in our_tr and k not in up_tr]
        print("  полный en:                 %4d ключей" % len(en))
        print("  наш ru.ts:                 %4d (русских переводов %d)" % (len(our), len(our_tr)))
        print("  апстримный ru (+модули):   %4d (русских переводов %d)" % (len(up), len(up_tr)))
        print("  наш слой (схема A):        %4d  <- столько останется поддерживать" % len(layer))
        print("  покрытие объединением:     %4d из %d (%.0f%%)" %
              (len(en) - len(holes), len(en), 100.0 * (len(en) - len(holes)) / len(en)))
        print("  дыр у ДВОИХ (переводить):  %4d" % len(holes))
        print("  мусор у нас (нет в en):    %4d" % len([k for k in our if k not in en]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
