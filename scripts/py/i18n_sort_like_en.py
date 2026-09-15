#!/usr/bin/env python3
# i18n_sort_like_en.py — переставляет ключи и секции ru.ts в порядок en.ts.
#
# Значения, отступы внутри значений, функции, массивы и шаблонные строки НЕ пересоздаются:
# берётся оригинальный текст значения (src[val_start:val_end]). Меняется только порядок
# ключей/секций и генерируются переносы строк с отступом в 2 пробела на уровень.
# Итог: ru.ts идёт строка-в-строку как en.ts — WinMerge показывает пропуски наглядно.
#
# Использование:
#   python i18n_sort_like_en.py [--en PATH] [--ru PATH] [--out PATH] [--drop-orphans] [--dry-run]
import argparse
import os
import shutil
import sys

BS = chr(92)
CR = chr(13)
LF = chr(10)
TAB = chr(9)

_HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_EN = os.path.join(_HERE, "..", "en-locale", "en.ts")
DEFAULT_RU = os.path.join(_HERE, "..", "ru-locale", "ru.ts")


def line_start(src, pos):
    return src.rfind(LF, 0, pos) + 1


class Child(object):
    __slots__ = ("key", "key_raw", "kind", "key_pos", "val_start", "val_end", "children")

    def __init__(self, key, key_raw, kind, key_pos, val_start, val_end):
        self.key = key
        self.key_raw = key_raw
        self.kind = kind
        self.key_pos = key_pos
        self.val_start = val_start
        self.val_end = val_end
        self.children = None


class Parser(object):
    def __init__(self, src):
        self.s = src
        self.i = 0
        self.n = len(src)

    def skip_ws(self):
        s = self.s
        while self.i < self.n:
            c = s[self.i]
            if c in (" ", TAB, CR, LF) or c == ",":
                self.i += 1
            elif c == "/" and self.i + 1 < self.n and s[self.i + 1] == "/":
                j = s.find(LF, self.i)
                self.i = self.n if j < 0 else j + 1
            elif c == "/" and self.i + 1 < self.n and s[self.i + 1] == "*":
                j = s.find("*/", self.i + 2)
                self.i = self.n if j < 0 else j + 2
            else:
                break

    def read_raw_string(self):
        st = self.i
        q = self.s[self.i]
        self.i += 1
        while self.i < self.n:
            c = self.s[self.i]
            if c == BS:
                self.i += 2
                continue
            if c == q:
                self.i += 1
                break
            self.i += 1
        return self.s[st:self.i]

    def read_key(self):
        """Возвращает (key, key_raw) или (None, None)."""
        self.skip_ws()
        if self.i >= self.n:
            return None, None
        c = self.s[self.i]
        if c in ("'", '"', "`"):
            raw = self.read_raw_string()
            key = raw[1:-1] if len(raw) >= 2 else raw
            return key, raw
        j = self.i
        while self.i < self.n and (self.s[self.i].isalnum() or self.s[self.i] in ("_", "$", "-")):
            self.i += 1
        if self.i == j:
            return None, None
        return self.s[j:self.i], self.s[j:self.i]

    def skip_scalar(self):
        depth = 0
        while self.i < self.n:
            c = self.s[self.i]
            if c in ("'", '"', "`"):
                self.read_raw_string()
                continue
            if c in ("(", "[", "{"):
                depth += 1
                self.i += 1
                continue
            if c in (")", "]", "}"):
                if depth == 0:
                    return
                depth -= 1
                self.i += 1
                continue
            if c == "," and depth == 0:
                return
            self.i += 1

    def skip_array(self):
        depth = 0
        while self.i < self.n:
            c = self.s[self.i]
            if c in ("'", '"', "`"):
                self.read_raw_string()
                continue
            if c == "[":
                depth += 1
            elif c == "]":
                depth -= 1
                self.i += 1
                if depth == 0:
                    return
                continue
            self.i += 1

    def parse_object(self):
        """self.i — сразу после '{'. Возвращает (children, close_pos)."""
        children = []
        while self.i < self.n:
            self.skip_ws()
            if self.i >= self.n:
                break
            if self.s[self.i] == "}":
                close = self.i
                self.i += 1
                return children, close
            key, key_raw = self.read_key()
            if key is None:
                self.i += 1
                continue
            key_pos = self.i - len(key_raw)
            self.skip_ws()
            if self.i < self.n and self.s[self.i] == ":":
                self.i += 1
            self.skip_ws()
            if self.i >= self.n:
                break
            c = self.s[self.i]
            if c == "{":
                val_start = self.i
                self.i += 1
                sub, close_pos = self.parse_object()
                child = Child(key, key_raw, "obj", key_pos, val_start, close_pos + 1)
                child.children = sub
            elif c == "[":
                val_start = self.i
                self.skip_array()
                child = Child(key, key_raw, "arr", key_pos, val_start, self.i)
            else:
                val_start = self.i
                self.skip_scalar()
                child = Child(key, key_raw, "leaf", key_pos, val_start, self.i)
            children.append(child)
        return children, max(self.n - 1, 0)


def parse_text(text, marker):
    pos = text.find(marker)
    if pos < 0:
        raise SystemExit("не найден маркер %s" % marker)
    root_open = text.find("{", pos)
    p = Parser(text)
    p.i = root_open + 1
    children, root_close = p.parse_object()
    return root_open, root_close, children


def en_order(children, path, out):
    out[path] = [c.key for c in children]
    for c in children:
        if c.kind == "obj" and c.children is not None:
            en_order(c.children, (path + "." + c.key) if path else c.key, out)


def reorder(children, en_map, path, drop_orphans, dropped):
    order = en_map.get(path)
    if order is None:
        return list(children)
    idx = {}
    for i, k in enumerate(order):
        idx.setdefault(k, i)
    known = [c for c in children if c.key in idx]
    unknown = [c for c in children if c.key not in idx]
    known.sort(key=lambda c: idx[c.key])
    if drop_orphans:
        for c in unknown:
            dropped.append((path + "." + c.key) if path else c.key)
    else:
        known.extend(unknown)
    return known


def render(children, src, en_map, path, indent, drop_orphans, dropped, lines):
    for c in reorder(children, en_map, path, drop_orphans, dropped):
        if c.kind == "obj" and c.children is not None:
            if c.children:
                lines.append(indent + c.key_raw + ": {" + LF)
                render(c.children, src, en_map, (path + "." + c.key) if path else c.key,
                       indent + "  ", drop_orphans, dropped, lines)
                lines.append(indent + "}," + LF)
            else:
                lines.append(indent + c.key_raw + ": {}," + LF)
        else:
            val = src[c.val_start:c.val_end]
            lines.append(indent + c.key_raw + ": " + val + "," + LF)


def collect_leaves(text, marker):
    root_open, root_close, children = parse_text(text, marker)
    res = {}

    def walk(ch, path):
        for c in ch:
            kp = (path + "." + c.key) if path else c.key
            if c.kind == "obj" and c.children is not None:
                walk(c.children, kp)
            else:
                res[kp] = text[c.val_start:c.val_end]
    walk(children, "")
    return res


def main():
    ap = argparse.ArgumentParser(description="Порядок ключей ru.ts как в en.ts")
    ap.add_argument("--en", default=DEFAULT_EN)
    ap.add_argument("--ru", default=DEFAULT_RU)
    ap.add_argument("--out", default=None)
    ap.add_argument("--drop-orphans", action="store_true", help="выбросить ключи, которых нет в en.ts")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    with open(args.en, "r", encoding="utf-8", newline="") as f:
        en_src = f.read()
    with open(args.ru, "r", encoding="utf-8", newline="") as f:
        ru_src = f.read()

    _eo, _ec, en_children = parse_text(en_src, "Translations = ")
    ru_open, ru_close, ru_children = parse_text(ru_src, "defineLocale(")

    en_map = {}
    en_order(en_children, "", en_map)

    dropped = []
    lines = []
    render(ru_children, ru_src, en_map, "", "  ", args.drop_orphans, dropped, lines)

    header = ru_src[:line_start(ru_src, ru_children[0].key_pos)]
    tail = ru_src[line_start(ru_src, ru_close):]
    out = header + "".join(lines) + tail

    before = collect_leaves(ru_src, "defineLocale(")
    after = collect_leaves(out, "defineLocale(")
    for p in dropped:
        before.pop(p, None)

    problems = []
    if set(before.keys()) != set(after.keys()):
        problems.append("набор ключей: до=%d после=%d" % (len(before), len(after)))
        lost = sorted(set(before) - set(after))[:6]
        new = sorted(set(after) - set(before))[:6]
        problems.append("потеряны: %s" % lost)
        problems.append("появились: %s" % new)
    else:
        diff = [k for k in before if before[k] != after[k]]
        if diff:
            problems.append("изменилось содержимое %d ключей: %s" % (len(diff), diff[:6]))

    if problems:
        print("ОШИБКА: " + "; ".join(problems))
        if args.out:
            with open(args.out, "w", encoding="utf-8", newline="") as f:
                f.write(out)
            print("(результат сохранён в %s для осмотра)" % args.out)
        return 1

    print("Проверка пройдена: ключей %d (до и после идентичны), выброшено мёртвых: %d" %
          (len(after), len(dropped)))
    if args.dry_run:
        print("(dry-run: файл не записан)")
        return 0

    target = args.out or args.ru
    if not args.out:
        shutil.copyfile(args.ru, args.ru + ".pre-sort")
    with open(target, "w", encoding="utf-8", newline="") as f:
        f.write(out)
    print("Записано: %s%s" % (target, "" if args.out else " (копия до сортировки: %s.pre-sort)" % args.ru))
    return 0


if __name__ == "__main__":
    sys.exit(main())
