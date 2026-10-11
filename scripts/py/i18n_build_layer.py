#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# i18n_build_layer.py — схема A: апстримный ru.ts как БАЗА + наш компактный слой.
#
# Что делает:
#   1) строит scripts/ru-locale/ru-layer.ts — НАШ слой: только те переводы, которых у
#      апстрима нет (вычитание upstream-locale из наших ru.ts + ru-constants.ts);
#   2) с --install собирает apps/desktop/src/i18n/ru.ts = АПСТРИМНЫЙ ru.ts + одна строка
#      подключения слоя (никаких ps1-патчей: файл конструируется из эталона);
#   3) кладёт ru-layer.ts рядом.
#
# Зачем так: апстрим сам развивает ru.ts (3531 перевод, плюрализация, модули) — его
# обновления подхватываются автоматически; наш файл — только «добивка». Старый подход
# (наш единый ru.ts поверх апстримного) стирал их переводы и не давал их обновлений.
#
# Использование:
#   python scripts/py/i18n_build_layer.py                 # только ru-layer.ts
#   python scripts/py/i18n_build_layer.py --install       # + собрать ru.ts в репозитории
#   python scripts/py/i18n_build_layer.py --dry-run
import argparse
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import i18n_refs as REFS  # noqa: E402

SCRIPTS = os.path.dirname(HERE)
ROOT = os.path.dirname(SCRIPTS)
REPO = os.path.join(ROOT, "data", "hermes", "hermes-agent")
I18N = os.path.join(REPO, "apps", "desktop", "src", "i18n")
RU_DIR = os.path.join(SCRIPTS, "ru-locale")
LAYER_OUT = os.path.join(RU_DIR, "ru-layer.ts")
OUR_CONST = os.path.join(RU_DIR, "ru-constants.ts")

RU_LINE = "export const ru = defineLocale(ruOverrides)"
RU_LINE_NEW = "export const ru = defineLocale(mergeTranslations(ruOverrides, ruLayerOverrides))"
HEADER = """// ВНИМАНИЕ: файл автогенерируется — не правьте здесь.
// Генератор: scripts/py/i18n_build_layer.py   |   Схема A: база — апстримный ru.ts.
// Здесь только то, чего нет у апстрима. Правьте scripts/ru-locale/ru.ts (переводы)
// и scripts/ru-locale/ru-constants.ts (подписи полей), затем перегенерируйте.
import type { TranslationOverrides } from './define-locale'

export const ruLayerOverrides: TranslationOverrides = {
"""


def flat_object(src, anchor):
    """Плоский словарь объекта: path -> RAW-фрагмент (с кавычками, как в источнике)."""
    return REFS.parse_leaves(src, anchor)


def quote_key(key):
    return key if re.match(r"^[A-Za-z_$][A-Za-z0-9_$]*$", key) else "'" + key + "'"


FLAT_PREFIXES = ("settings.fieldLabels", "settings.fieldDescriptions")


def build_tree(flat, order_index):
    """Плоские 'a.b.c' -> вложенное дерево (dict), ключи в порядке en.

    Внутри settings.fieldLabels/fieldDescriptions ключи остаются ПЛОСКИМИ
    ('browser.useRealProfile'): апстрим собирает их через defineFieldCopy, и
    они должны сливаться как Record<string, string>, а не как под-объекты."""
    keys = sorted(flat, key=lambda k: (order_index.get(k, 1 << 30), k))
    root = {}
    for k in keys:
        parts = k.split(".")
        cut = None
        for i in range(1, len(parts)):
            if ".".join(parts[:i]) in FLAT_PREFIXES:
                cut = i
        if cut is not None:
            head, leaf = parts[:cut], ".".join(parts[cut:])
        else:
            head, leaf = parts[:-1], parts[-1]
        node = root
        for p in head:
            node = node.setdefault(p, {})
        node[leaf] = flat[k]
    return root


def render(node, indent):
    lines = []
    for key, val in node.items():
        k = quote_key(key)
        if isinstance(val, dict):
            if not val:
                continue
            lines.append("%s%s: {" % (indent, k))
            lines.extend(render(val, indent + "  "))
            lines.append("%s}," % indent)
        else:
            lines.append("%s%s: %s," % (indent, k, val))
    return lines


def main():
    ap = argparse.ArgumentParser(description="Сборка нашего слоя русификации (схема A)")
    ap.add_argument("--install", action="store_true", help="собрать ru.ts в репозитории Hermes")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    def say(msg):
        if not args.quiet:
            print(msg)

    en = REFS.full_en()
    up = REFS.upstream_ru()
    our = REFS.our_ru()
    order = {k: i for i, k in enumerate(en)}

    # --- наши переводы, которых апстрим не имеет ---
    layer = {}
    for k, v in our.items():
        if k not in en:            # мусор от старых версий — в слой не идёт
            continue
        if not REFS.is_ru(v) or v == en[k]:
            continue
        if k in up and REFS.is_ru(up[k]):
            continue               # базa апстрима уже переводит — не дублируем
        layer[k] = v

    # --- подписи/описания полей: добираем те, которых нет у апстрима ---
    our_const = open(OUR_CONST, encoding="utf-8", newline="").read()
    up_src = open(os.path.join(REFS.UP_DIR, "ru.ts"), encoding="utf-8", newline="").read()
    field_extra = 0
    for our_anchor, up_anchor, out_key in (
        ("export const RU_FIELD_LABELS", "fieldLabels: defineFieldCopy(", "settings.fieldLabels"),
        ("export const RU_FIELD_DESCRIPTIONS", "fieldDescriptions: defineFieldCopy(", "settings.fieldDescriptions"),
    ):
        mine = flat_object(our_const, our_anchor)
        theirs = flat_object(up_src, up_anchor)
        for k, v in mine.items():
            if k not in theirs and REFS.is_ru(v):
                layer[out_key + "." + k] = v
                field_extra += 1

    tree = build_tree(layer, order)
    body = render(tree, "  ")
    text = HEADER + "\n".join(body) + "\n}\n"

    say("  наш слой: %d переводов (%d из них — подписи/описания полей)" % (len(layer), field_extra))
    say("  строк в ru-layer.ts: %d" % text.count("\n"))

    if args.dry_run:
        say("  (dry-run: файлы не записаны)")
        return 0

    os.makedirs(RU_DIR, exist_ok=True)
    if os.path.exists(LAYER_OUT):
        shutil.copyfile(LAYER_OUT, LAYER_OUT + ".pre-build")
    with open(LAYER_OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    say("  записано: %s" % LAYER_OUT)

    if not args.install:
        return 0

    # --- устанавливаем слой + собираем ru.ts из АПСТРИМНОГО ---
    if not os.path.isdir(I18N):
        print("  [ОШИБКА] нет каталога %s" % I18N)
        return 1
    base = open(os.path.join(REFS.UP_DIR, "ru.ts"), encoding="utf-8", newline="").read()
    if RU_LINE not in base:
        print("  [ОШИБКА] в апстримном ru.ts нет строки:\n    %s" % RU_LINE)
        print("          апстрим изменил формат — проверьте scripts/upstream-locale/ru.ts")
        return 1
    anchor = [ln for ln in base.split("\n") if "from './define-locale'" in ln]
    if not anchor:
        print("  [ОШИБКА] в апстримном ru.ts нет импорта './define-locale'")
        return 1
    base = base.replace(anchor[0],
                        anchor[0] + "\nimport { mergeTranslations } from '@hermes/shared/i18n'"
                                    "\nimport { ruLayerOverrides } from './ru-layer'", 1)
    base = base.replace(RU_LINE, RU_LINE_NEW, 1)

    dst_ru = os.path.join(I18N, "ru.ts")
    dst_layer = os.path.join(I18N, "ru-layer.ts")
    shutil.copyfile(LAYER_OUT, dst_layer)
    with open(dst_ru, "w", encoding="utf-8", newline="") as f:
        f.write(base)
    say("  установлено: ru-layer.ts + ru.ts (апстрим + подключение слоя)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
