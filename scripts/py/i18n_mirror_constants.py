#!/usr/bin/env python3
# i18n_mirror_constants.py — приводит scripts/ru-locale/ru-constants.ts к ЗЕРКАЛУ
# constants.ts: тот же набор ключей и порядок, перевод там, где он есть,
# английский текст там, где перевода нет.
#
# Зачем: ru.ts подставляет fieldLabels: RU_FIELD_LABELS / fieldDescriptions:
# RU_FIELD_DESCRIPTIONS. Если ключа нет — подпись поля остаётся английской,
# а тест settings-i18n.test.tsx требует отличия от en. Зеркало закрывает
# это разом и не даёт константам отставать от обновлений Hermes.
#
# Использование:
#   python i18n_mirror_constants.py [--en PATH] [--ru PATH] [--out FILE] [--dry-run]

import argparse
import os
import shutil

BS = chr(92)
CR = chr(13)
LF = chr(10)
TAB = chr(9)
WS = (" ", TAB, CR, LF)

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_RU = os.path.normpath(os.path.join(HERE, "..", "ru-locale", "ru-constants.ts"))
# Эталон подписей полей: сначала scripts/en-locale/en-constants.ts (его обновляет
# InstallOrUpdate-RU.bat), затем файл репозитория Hermes.
DEFAULT_EN = os.path.normpath(os.path.join(HERE, "..", "en-locale", "en-constants.ts"))
if not os.path.exists(DEFAULT_EN):
    DEFAULT_EN = os.path.normpath(
        os.path.join(HERE, "..", "..", "data", "hermes", "hermes-agent",
                     "apps", "desktop", "src", "app", "settings", "constants.ts")
    )


def parse_obj(src, i):
    """Парсит объектный литерал, i — позиция '{'. Возвращает (tree, next_i)."""
    if src[i] != "{":
        raise ValueError("ожидался '{'")
    i += 1
    tree = {}
    while i < len(src):
        while i < len(src) and src[i] in WS or (i < len(src) and src[i] == ","):
            i += 1
        if i >= len(src):
            break
        if src[i] == "}":
            return tree, i + 1
        if src[i] in ("'", '"'):
            q = src[i]
            j = i + 1
            while j < len(src) and src[j] != q:
                j += 2 if src[j] == BS else 1
            key = src[i + 1:j]
            j += 1
        else:
            j = i
            while j < len(src) and (src[j].isalnum() or src[j] in "_$"):
                j += 1
            key = src[i:j]
        while j < len(src) and src[j] in WS:
            j += 1
        if j < len(src) and src[j] == ":":
            j += 1
        while j < len(src) and src[j] in WS:
            j += 1
        if j < len(src) and src[j] == "{":
            sub, i = parse_obj(src, j)
            tree[key] = sub
        else:
            if j < len(src) and src[j] in ("'", '"', chr(96)):
                q = src[j]
                k = j + 1
                while k < len(src) and src[k] != q:
                    k += 2 if src[k] == BS else 1
                tree[key] = src[j:k + 1]
                i = k + 1
            else:
                k = j
                while k < len(src) and src[k] not in (",", "}"):
                    k += 1
                tree[key] = src[j:k].rstrip()
                i = k
    return tree, i


def grab(src, marker):
    i = src.find(marker)
    if i < 0:
        raise SystemExit("не найден маркер: %s" % marker)
    j = src.find("{", i)
    tree, _ = parse_obj(src, j)
    return tree


def flatten(tree, path, out):
    for k, v in tree.items():
        kp = (path + "." + k) if path else k
        if isinstance(v, dict):
            flatten(v, kp, out)
        else:
            out[kp] = v
    return out


def render(en_tree, ru_flat, path, indent, lines, stats):
    for k, v in en_tree.items():
        kp = (path + "." + k) if path else k
        if isinstance(v, dict):
            lines.append(indent + k + ": {")
            render(v, ru_flat, kp, indent + "  ", lines, stats)
            lines.append(indent + "},")
        else:
            raw = ru_flat.get(kp)
            if raw is None:
                raw = v
                stats["new"] += 1
            else:
                stats["kept"] += 1
            lines.append(indent + k + ": " + raw + ",")


def main():
    ap = argparse.ArgumentParser(description="ru-constants.ts как зеркало constants.ts")
    ap.add_argument("--en", default=DEFAULT_EN, help="constants.ts (эталон)")
    ap.add_argument("--ru", default=DEFAULT_RU, help="ru-constants.ts")
    ap.add_argument("--out", help="куда записать (по умолчанию перезапись ru с .bak)")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if not os.path.exists(args.en):
        raise SystemExit("нет файла эталона: %s" % args.en)
    en_src = open(args.en, encoding="utf-8").read()
    ru_src = open(args.ru, encoding="utf-8", newline="").read()

    en_l = grab(en_src, "export const FIELD_LABELS")
    en_d = grab(en_src, "export const FIELD_DESCRIPTIONS")
    ru_l = flatten(grab(ru_src, "export const RU_FIELD_LABELS"), "", {})
    ru_d = flatten(grab(ru_src, "export const RU_FIELD_DESCRIPTIONS"), "", {})

    stats = {"kept": 0, "new": 0}
    lines = [
        "// Russian translations for field labels and descriptions.",
        "// Used by ru.ts instead of the English defaults from constants.ts.",
        "",
        "export const RU_FIELD_LABELS: Record<string, string> = {",
    ]
    render(en_l, ru_l, "", "  ", lines, stats)
    lines.append("};")
    lines.append("")
    lines.append("export const RU_FIELD_DESCRIPTIONS: Record<string, string> = {")
    render(en_d, ru_d, "", "  ", lines, stats)
    lines.append("};")
    out = LF.join(lines) + LF

    # контроль: все ключи en на месте
    en_flat = {}
    flatten(en_l, "", en_flat)
    flatten(en_d, "", en_flat)
    out_flat = {}
    flatten(grab(out, "export const RU_FIELD_LABELS"), "", out_flat)
    flatten(grab(out, "export const RU_FIELD_DESCRIPTIONS"), "", out_flat)
    lost = [k for k in en_flat if k not in out_flat]
    if lost:
        print("ОШИБКА: потеряны ключи: %s" % lost[:5])
        return 1

    print("  ключей: labels %d, descriptions %d" % (len(flatten(en_l, "", {})), len(flatten(en_d, "", {}))))
    print("  переводов сохранено: %d, добавлено из en: %d" % (stats["kept"], stats["new"]))
    dead = [k for k in list(ru_l) + list(ru_d) if k not in en_flat]
    if dead:
        print("  мёртвых ключей (нет в en) не переносим: %d" % len(dead))

    if args.dry_run:
        print("  (dry-run, файл не изменён)")
        return 0

    target = args.out or args.ru
    if not args.out:
        shutil.copyfile(args.ru, args.ru + ".bak")
    with open(target, "w", encoding="utf-8", newline="") as f:
        f.write(out)
    print("  записано: %s%s" % (target, "" if args.out else " (копия: ru-constants.ts.bak)"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
