#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# i18n_status.py — диагностика русификации по схеме A (замена compare_i18n_keys в Tools.bat [1]).
#
# Считает ПОЛНЫЙ словарь en (с модулями en_*.ts) и сравнивает с итогом сборки:
#   итог = апстримный ru.ts (+модули) + наш слой ru-layer.ts
# Показывает: покрытие, дыры (по секциям), мёртвые ключи слоя, размер нашего слоя.
#
# Использование:
#   python scripts/py/i18n_status.py                 # сводка
#   python scripts/py/i18n_status.py --holes 40      # топ дыр по секциям
#   python scripts/py/i18n_status.py --flat DIR      # en.flat / ru.flat / holes.flat (для WinMerge)
import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import i18n_refs as REFS  # noqa: E402

SCRIPTS = os.path.dirname(HERE)
LAYER = os.path.join(SCRIPTS, "ru-locale", "ru-layer.ts")


def load_layer():
    if not os.path.exists(LAYER):
        return {}
    return REFS.parse_leaves(open(LAYER, encoding="utf-8", newline="").read(),
                             "export const ruLayerOverrides")


def merged_ru(en, up, layer):
    """Итоговый словарь после сборки: база апстрима + наш слой сверху."""
    total = dict(up)
    total.update(layer)
    return total


def by_section(keys):
    d = {}
    for k in keys:
        d.setdefault(k.split(".", 1)[0], []).append(k)
    return d


def main():
    ap = argparse.ArgumentParser(description="Диагностика русификации Hermes (схема A)")
    ap.add_argument("--holes", type=int, default=0, metavar="N", help="показать N дыр по секциям")
    ap.add_argument("--flat", metavar="DIR", help="записать en.flat / ru.flat / holes.flat")
    args = ap.parse_args()

    en = REFS.full_en()
    up = REFS.upstream_ru()
    layer = load_layer()
    total = merged_ru(en, up, layer)

    holes = [k for k in en if k not in total]                       # ключа нет вовсе
    english = [k for k in en if k in total and total[k] == en[k]]   # есть, но текст английский
    # ключ слоя «мёртв», если его нет в en; подписи полей живут под ключом-листом
    # settings.fieldLabels/fieldDescriptions (апстрим собирает их через defineFieldCopy)
    dead = [k for k in layer if k not in en
            and not (k.split(".", 1)[0] == "settings"
                     and (k.startswith("settings.fieldLabels.") or k.startswith("settings.fieldDescriptions."))
                     and "settings." + k.split(".")[1] in en)]
    covered = len(en) - len(holes)

    print("=" * 78)
    print("  Русификация Hermes — схема A (база: апстрим, слой: ru-layer.ts)")
    print("=" * 78)
    print("  полный словарь en (с модулями): %d" % len(en))
    print("  апстримный ru (+модули):        %d" % len(up))
    print("  наш слой ru-layer.ts:           %d" % len(layer))
    print()
    print("  ПОКРЫТИЕ: %d из %d (%.0f%%)" % (covered, len(en), 100.0 * covered / len(en)))
    print("  дыр (ключа нет):     %d" % len(holes))
    print("  англ. текстом:       %d" % len(english))
    print("  мёртвых в слое:      %d  %s" % (len(dead), dead[:8] if dead else ""))
    print()

    if args.holes:
        sec = by_section(holes + english)
        print("  ТОП-секций с дырами:")
        for s, ks in sorted(sec.items(), key=lambda x: -len(x[1]))[:args.holes]:
            print("    %-22s %4d" % (s, len(ks)))

    if args.flat:
        out = os.path.abspath(args.flat)
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, "en.flat"), "w", encoding="utf-8", newline="\n") as f:
            for k in en:
                f.write("%s = %s\n" % (k, REFS.flat_value(en[k])))
        with open(os.path.join(out, "ru.flat"), "w", encoding="utf-8", newline="\n") as f:
            for k in en:
                f.write("%s = %s\n" % (k, REFS.flat_value(total[k]) if k in total else "<НЕТ ПЕРЕВОДА>"))
        with open(os.path.join(out, "holes.flat"), "w", encoding="utf-8", newline="\n") as f:
            f.write("# дыр: %d (нет ключа %d, английский текст %d)\n" % (len(holes) + len(english), len(holes), len(english)))
            for k in sorted(set(holes) | set(english)):
                f.write("%s = %s\n" % (k, REFS.flat_value(en[k])))
        print()
        print("  файлы для сверки: %s (en.flat, ru.flat, holes.flat)" % out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
