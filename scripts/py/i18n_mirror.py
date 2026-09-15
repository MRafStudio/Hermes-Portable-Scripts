#!/usr/bin/env python3
# i18n_mirror.py — приводит ru.ts к ЗЕРКАЛУ en.ts: тот же набор ключей, тот же порядок,
# та же разметка строк (кроме шапки и последней строки) — перевод там, где он есть,
# английский текст там, где перевода ещё нет.
#
# Как работает: тело берётся ИЗ en.ts (все ключи, вложенность, форматирование, функции,
# массивы, TS-приведения), значения заменяются на русские из текущего ru.ts (raw-фрагменты,
# кавычки и пробелы сохраняются). Шапка и хвост — «ру»-свои (defineLocale).
#
# Использование:
#   python i18n_mirror.py [--en PATH] [--ru PATH] [--out PATH] [--dry-run]
import argparse
import os
import shutil
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, _HERE)

import i18n_sort_like_en as SORT  # noqa: E402

BS = chr(92)
CR = chr(13)
LF = chr(10)

DEFAULT_EN = os.path.join(_HERE, "..", "en-locale", "en.ts")
DEFAULT_RU = os.path.join(_HERE, "..", "ru-locale", "ru.ts")


def ru_values(src, marker):
    """Путь -> оригинальный фрагмент значения (raw, с кавычками)."""
    _ro, _rc, children = SORT.parse_text(src, marker)
    out = {}

    def walk(ch, path):
        for c in ch:
            kp = (path + "." + c.key) if path else c.key
            if c.kind == "obj" and c.children is not None:
                walk(c.children, kp)
            else:
                out[kp] = src[c.val_start:c.val_end]
    walk(children, "")
    return out


def main():
    ap = argparse.ArgumentParser(description="ru.ts как зеркало en.ts (полнота + порядок + построчность)")
    ap.add_argument("--en", default=DEFAULT_EN)
    ap.add_argument("--ru", default=DEFAULT_RU)
    ap.add_argument("--out", default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    en_src = open(args.en, encoding="utf-8", newline="").read()
    ru_src = open(args.ru, encoding="utf-8", newline="").read()

    en_open, en_close, en_children = SORT.parse_text(en_src, "Translations = ")
    ru_open, ru_close, ru_children = SORT.parse_text(ru_src, "defineLocale(")

    en_vals = ru_values(en_src, "Translations = ")
    ru_vals = ru_values(ru_src, "defineLocale(")

    body_start = SORT.line_start(en_src, en_children[0].key_pos)
    body_end = SORT.line_start(en_src, en_close)
    body = en_src[body_start:body_end]

    # замены значений по позициям внутри body (координаты en минус body_start)
    edits = []
    translated = 0
    for path, raw_ru in ru_vals.items():
        # ищем лист en по этому пути
        leaf = None
        stack = [(c, "") for c in en_children]
        while stack:
            c, p = stack.pop()
            kp = (p + "." + c.key) if p else c.key
            if kp == path:
                leaf = c
                break
            if c.kind == "obj" and c.children is not None:
                for sub in c.children:
                    stack.append((sub, kp))
        if leaf is None or leaf.kind == "obj":
            continue
        frag = en_src[leaf.val_start:leaf.val_end]
        core_len = len(frag.rstrip())  # хвостовые переносы/отступы en сохраняем как есть
        edits.append((leaf.val_start - body_start,
                      leaf.val_start - body_start + core_len,
                      raw_ru.rstrip()))
        translated += 1

    new_body = body
    for start, end, text in sorted(edits, key=lambda e: e[0], reverse=True):
        new_body = new_body[:start] + text + new_body[end:]

    header = ru_src[:SORT.line_start(ru_src, ru_children[0].key_pos)]
    tail = ru_src[SORT.line_start(ru_src, ru_close):]
    out = header + new_body + tail

    # ---- проверки ----
    en_leaves = SORT.collect_leaves(en_src, "Translations = ")
    out_leaves = SORT.collect_leaves(out, "defineLocale(")
    problems = []
    if set(en_leaves.keys()) != set(out_leaves.keys()):
        missing = sorted(set(en_leaves) - set(out_leaves))[:5]
        extra = sorted(set(out_leaves) - set(en_leaves))[:5]
        problems.append("набор ключей не совпал с en (нет: %s; лишние: %s)" % (missing, extra))
    orphans = sorted(set(ru_vals) - set(en_vals))
    lang_mismatch = [p for p in ru_vals if p == ""]

    # построчность: сравниваем номера строк одноимённых ключей
    def lines_map(text, marker):
        _o, _c, ch = SORT.parse_text(text, marker)
        res = {}

        def walk(ch2, p):
            for c in ch2:
                kp = (p + "." + c.key) if p else c.key
                if c.kind == "obj" and c.children is not None:
                    walk(c.children, kp)
                else:
                    res[kp] = text.count(LF, 0, c.key_pos) + 1
        walk(ch, "")
        return res

    le = lines_map(en_src, "Translations = ")
    lo = lines_map(out, "defineLocale(")
    common = [k for k in le if k in lo]
    offsets = [lo[k] - le[k] for k in common]
    zero = sum(1 for d in offsets if d == 0)
    header_diff = lo[common[0]] - le[common[0]] if common else 0

    print("  ключей en: %d, переводов применено: %d" % (len(en_leaves), translated))
    print("  строк: en=%d, зеркало=%d" % (en_src.count(LF), out.count(LF)))
    print("  построчность: совпадает строка-в-строку %d из %d (сдвиг после шапки: %+d)" %
          (zero, len(common), header_diff))
    if orphans:
        print("  мёртвых ключей (нет в en) не переносим: %d" % len(orphans))

    if problems:
        print("ОШИБКА: %s" % "; ".join(problems))
        return 1

    if args.dry_run:
        print("(dry-run: файл не записан)")
        return 0

    target = args.out or args.ru
    if not args.out:
        shutil.copyfile(args.ru, args.ru + ".pre-mirror")
    with open(target, "w", encoding="utf-8", newline="") as f:
        f.write(out)
    print("Записано: %s%s" % (target, "" if args.out else " (копия до зеркалирования: %s.pre-mirror)" % args.ru))
    return 0


if __name__ == "__main__":
    sys.exit(main())
