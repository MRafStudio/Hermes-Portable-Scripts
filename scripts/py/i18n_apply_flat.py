#!/usr/bin/env python3
# i18n_apply_flat.py — применяет переводы из flat-файла (ключ = текст) в ru.ts Hermes.
#
# Зачем: в новой архитектуре i18n ru.ts — оверрайды defineLocale({...}) поверх en.ts.
# Текст удобнее править в плоском виде (ru.flat), а этот скрипт аккуратно переносит
# правки в TS: заменяет значения существующих ключей, добавляет отсутствующие
# (создавая недостающие секции/подсекции) и по желанию удаляет осиротевшие ключи.
# Функции, ссылки на константы и форматирование не трогаются.
#
# Использование:
#   python i18n_apply_flat.py --flat ru.new.flat [--ru PATH] [--en PATH] [--prune] [--dry-run] [--out FILE]
#
# Формат flat-файла (lossless): 'ключ = текст', переносы как \n, слэши как \\.
# Строки, начинающиеся с '#', игнорируются. Значение '<функция>' и '<...>' пропускаются.

import argparse
import re
import os
import shutil
import sys

BS = chr(92)
CR = chr(13)
LF = chr(10)
TAB = chr(9)


def unescape_flat(s):
    out = []
    i = 0
    while i < len(s):
        c = s[i]
        if c == BS and i + 1 < len(s):
            nxt = s[i + 1]
            if nxt == BS:
                out.append(BS)
                i += 2
                continue
            if nxt == "n":
                out.append(LF)
                i += 2
                continue
            if nxt == "r":
                out.append(CR)
                i += 2
                continue
            if nxt == "t":
                out.append(TAB)
                i += 2
                continue
        out.append(c)
        i += 1
    return "".join(out)


def escape_ts(s, style=None):
    """TS-литерал. style — сохранить исходный стиль кавычек (' " или `)."""
    if style == "`" or (style is None and (LF in s or CR in s)):
        body = s.replace(BS, BS + BS).replace("`", BS + "`").replace("$" + "{", BS + "$" + "{")
        return "`" + body + "`"
    q = style if style in ("'", '"') else "'"
    body = s.replace(BS, BS + BS).replace(q, BS + q)
    return q + body + q


class Leaf(object):
    __slots__ = ("path", "kind", "text", "key_start", "val_start", "val_end")


class Parser(object):
    """Мини-парсер TS-объекта локали: собирает листья и позиции объектов."""

    def __init__(self, src):
        self.s = src
        self.i = 0
        self.n = len(src)
        self.leaves = {}
        self.objs = {}  # path -> (open_pos, close_pos)

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

    def read_string(self):
        s = self.s
        quote = s[self.i]
        start = self.i
        self.i += 1
        buf = []
        while self.i < self.n:
            c = s[self.i]
            if c == BS:
                buf.append(s[self.i:self.i + 2])
                self.i += 2
                continue
            if c == quote:
                self.i += 1
                break
            buf.append(c)
            self.i += 1
        kind = "template" if quote == "`" else "string"
        return "".join(buf), kind, start, self.i

    def parse_key(self):
        self.skip_ws()
        if self.i >= self.n:
            return None
        c = self.s[self.i]
        if c in ("'", '"', "`"):
            t, _kind, start, _end = self.read_string()
            return t, start
        j = self.i
        while self.i < self.n and (self.s[self.i].isalnum() or self.s[self.i] in ("_", "$", "-")):
            self.i += 1
        return self.s[j:self.i] or None, j

    def parse_value(self, path):
        self.skip_ws()
        if self.i >= self.n:
            return
        c = self.s[self.i]
        if c == "{":
            self.objs[path] = (self.i, -1)
            self.i += 1
            self.parse_object(path)
        elif c == "[":
            self.parse_array(path)
        elif c in ("'", '"', "`"):
            text, kind, start, end = self.read_string()
            lf = Leaf()
            lf.path, lf.kind, lf.text = path, kind, text
            lf.key_start, lf.val_start, lf.val_end = self.last_key_start, start, end
            self.leaves[path] = lf
        else:
            start = self.i
            depth = 0
            while self.i < self.n:
                ch = self.s[self.i]
                if ch in ("'", '"', "`"):
                    self.read_string()
                    continue
                if ch in ("(", "[", "{"):
                    depth += 1
                    self.i += 1
                    continue
                if ch in (")", "]", "}"):
                    if depth == 0:
                        break
                    depth -= 1
                    self.i += 1
                    continue
                if ch == "," and depth == 0:
                    break
                self.i += 1
            raw = self.s[start:self.i].strip()
            kind = "fn" if ("=>" in raw or raw.startswith("function")) else "other"
            lf = Leaf()
            lf.path, lf.kind, lf.text = path, kind, raw
            lf.key_start, lf.val_start, lf.val_end = self.last_key_start, start, self.i
            self.leaves[path] = lf

    def parse_array(self, path):
        self.i += 1  # '['
        idx = 0
        while self.i < self.n:
            self.skip_ws()
            if self.i >= self.n or self.s[self.i] == "]":
                self.i += 1
                break
            self.parse_value("!" + path + "[" + str(idx) + "]")
            idx += 1

    def skip_as_suffix(self):
        """Пропускает TS-приведение ' as <Type>' после значения (as Record<...> и т.п.)."""
        save = self.i
        self.skip_ws()
        if self.s[self.i:self.i + 2] != "as":
            self.i = save
            return
        nxt = self.s[self.i + 2:self.i + 3]
        if nxt.isalnum() or nxt in ("_", "$"):
            self.i = save
            return
        self.i += 2
        depth = 0
        while self.i < self.n:
            ch = self.s[self.i]
            if ch in "'\"`":
                self.read_string()
                continue
            if ch in "([{<":
                depth += 1
                self.i += 1
                continue
            if ch in ")]}>":
                if depth == 0:
                    break
                depth -= 1
                self.i += 1
                continue
            if ch == "," and depth == 0:
                break
            self.i += 1

    def parse_object(self, path):
        open_pos = self.i - 1
        while self.i < self.n:
            self.skip_ws()
            if self.i >= self.n:
                break
            if self.s[self.i] == "}":
                self.objs[path] = (open_pos, self.i)
                self.i += 1
                break
            parsed = self.parse_key()
            if parsed is None or parsed[0] is None:
                print("WARN[parse]: ключ не распознан на позиции %d: %s" %
                      (self.i, repr(self.s[max(0, self.i - 80):self.i + 80])))
                self.i += 1
                continue
            key, key_start = parsed
            self.last_key_start = key_start
            self.skip_ws()
            if self.i < self.n and self.s[self.i] == ":":
                self.i += 1
            kpath = (path + "." + key) if path else key
            self.parse_value(kpath)
            self.skip_as_suffix()


def find_root(src, marker):
    pos = src.find(marker)
    if pos < 0:
        return -1
    return src.find("{", pos)


def parse_text(src, marker):
    root = find_root(src, marker)
    if root < 0:
        raise SystemExit("не найдено начало объекта")
    p = Parser(src)
    p.i = root + 1
    p.objs[""] = (root, -1)
    p.parse_object("")
    return src, p


def parse_file(path, marker):
    with open(path, "r", encoding="utf-8", newline="") as f:
        src = f.read()
    return parse_text(src, marker)


def read_flat(path):
    updates = {}
    skipped = 0
    with open(path, "r", encoding="utf-8", newline="") as f:
        for raw in f:
            line = raw.rstrip(CR + LF)
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if " = " not in line:
                continue
            key, value = line.split(" = ", 1)
            key = key.strip()
            # хвостовые пробелы значимы (текст локали) — не обрезаем
            if "[" in key or "]" in key:
                skipped += 1  # ключи внутри массивов точечно не импортируются
                continue
            if value.strip().startswith("<") and value.strip().endswith(">"):
                continue  # <функция> и прочие маркеры не импортируем
            updates[key] = unescape_flat(value)
    return updates, skipped


def indent_of(src, pos):
    start = src.rfind(LF, 0, pos) + 1
    j = start
    while j < len(src) and src[j] in (" ", TAB):
        j += 1
    return src[start:j]


def ts_key(key):
    """TS-ключ: идентификаторы — как есть, остальное (дефисы и т.п.) — в кавычках."""
    if re.match(r"^[A-Za-z_$][A-Za-z0-9_$]*$", key):
        return key
    return "'" + key.replace("'", BS + "'") + "'"


def render_tree(node, indent, lines):
    """Рендерит дерево новых ключей одним фрагментом (без дублей секций)."""
    for key, val in node.items():
        k = ts_key(key)
        if isinstance(val, dict):
            lines.append(indent + k + ": {")
            render_tree(val, indent + "  ", lines)
            lines.append(indent + "},")
        else:
            lines.append(indent + k + ": " + escape_ts(val) + ",")


def main():
    ap = argparse.ArgumentParser(description="Применить flat-переводы в ru.ts локализации Hermes")
    ap.add_argument("--flat", required=True, help="файл переводов (ключ = текст)")
    ap.add_argument("--ru", default="scripts/ru-locale/ru.ts", help="путь к ru.ts")
    ap.add_argument("--en", default="scripts/en-locale/en.ts", help="путь к en.ts (для --prune)")
    ap.add_argument("--prune", action="store_true", help="удалять ключи, которых нет в en.ts")
    ap.add_argument("--only-new", action="store_true",
                    help="применять только отсутствующие в ru.ts ключи (существующие переводы не трогать)")
    ap.add_argument("--dry-run", action="store_true", help="ничего не писать, только показать план")
    ap.add_argument("--out", help="записать результат в другой файл (по умолчанию — в ru.ts, .bak рядом)")
    args = ap.parse_args()

    src, rp = parse_file(args.ru, "defineLocale(")
    updates, skipped_arrays = read_flat(args.flat)

    edits = []
    replaced = 0
    missing_parent = []

    # 1) замены существующих значений (только строки/шаблоны — функции и ссылки не трогаем)
    replaced_list = []
    for path, text in updates.items():
        leaf = rp.leaves.get(path)
        if leaf is None or path.startswith("!"):
            continue
        if leaf.kind not in ("string", "template"):
            continue
        style = src[leaf.val_start] if leaf.val_start < len(src) else None
        raw_old = src[leaf.val_start:leaf.val_end].strip()
        if len(raw_old) >= 2 and raw_old[0] in ("'", '"', "`") and raw_old[-1] == raw_old[0]:
            old_text = raw_old[1:-1]
        else:
            old_text = raw_old
        old_plain = old_text.replace(BS + BS, BS).replace(BS + "n", LF).replace(BS + "r", CR).replace(BS + "t", TAB)
        if old_plain == text:
            continue  # перевод не меняется — не трогаем строку вовсе
        replaced_list.append((path, old_plain, text))
        edits.append((leaf.val_start, leaf.val_end, escape_ts(text, style)))
        replaced += 1
    if args.only_new:
        updates = {k: v for k, v in updates.items() if k not in rp.leaves}

    # 2) добавление новых ключей, сгруппированных по родителю
    adds = {}
    for path, text in updates.items():
        if path in rp.leaves or path.startswith("!"):
            continue
        parts = path.split(".")
        parent = ""
        rest = parts
        for k in range(len(parts) - 1, -1, -1):
            cand = ".".join(parts[:k])
            if cand == "" or cand in rp.objs:
                parent = cand
                rest = parts[k:]
                break
        if parent == "" and len(rest) > 1 and rest[0] not in rp.objs and ("." + rest[0]) in rp.objs:
            pass
        adds.setdefault(parent, []).append((rest, text))

    # ===== ПРОХОД 1: замены + prune (позиции исходного текста) =====
    pruned = 0
    if args.prune:
        _esrc, ep = parse_file(args.en, "Translations = ")
        for path, leaf in rp.leaves.items():
            if path.startswith("!") or path in ep.leaves:
                continue
            val = src[leaf.val_start:leaf.val_end]
            if LF in val or CR in val:
                continue  # многострочное значение — не трогаем
            line_start = src.rfind(LF, 0, leaf.key_start) + 1
            line_end = src.find(LF, leaf.val_end)
            line_end = len(src) if line_end < 0 else line_end + 1
            head = src[line_start:leaf.key_start].strip()
            tail = src[leaf.val_end:line_end].strip()
            tail_clean = tail.rstrip(",").strip()
            if head != "" or tail_clean not in ("", "}"):
                continue  # ключ не единственный в строке — пропускаем
            edits.append((line_start, line_end, ""))
            pruned += 1

    out = src
    for start, end, text in sorted(edits, key=lambda e: e[0], reverse=True):
        out = out[:start] + text + out[end:]

    # ===== ПРОХОД 2: вставка новых ключей (позиции пересчитаны) =====
    added = 0
    if adds:
        out, rp2 = parse_text(out, "defineLocale(")
        additions = []
        for parent, items in adds.items():
            obj = rp2.objs.get(parent)
            if obj is None:
                missing_parent.append(parent)
                continue
            _open_pos, close_pos = obj
            child_indent = indent_of(out, close_pos) + "  "
            tree = {}
            for rest, text in items:
                node = tree
                for part in rest[:-1]:
                    node = node.setdefault(part, {})
                if isinstance(node.get(rest[-1]), dict):
                    continue
                node[rest[-1]] = text
                added += 1
            lines = []
            render_tree(tree, child_indent, lines)
            snippet = LF + LF.join(lines) + LF + indent_of(out, close_pos)
            j = close_pos - 1
            while j >= 0 and out[j] in (" ", TAB, CR, LF):
                j -= 1
            prefix = ""
            if j >= 0 and out[j] != "," and out[j] != "{":
                prefix = ","
            additions.append((j + 1, j + 1, prefix + snippet))
        for start, end, text in sorted(additions, key=lambda e: e[0], reverse=True):
            out = out[:start] + text + out[end:]

    # ===== ВАЛИДАЦИЯ: результат должен парситься, ключей не меньше ожидаемого =====
    _vsrc, vp = parse_text(out, "defineLocale(")
    expected = len(rp.leaves) + added - pruned
    if len(vp.leaves) < expected:
        print("ПРЕДУПРЕЖДЕНИЕ: ключей в результате %d, ожидалось %d" % (len(vp.leaves), expected))

    if args.dry_run:
        print("Замен: %d | Добавлений: %d | Удалений (prune): %d | Пропущено (в массивах): %d" %
          (replaced, added, pruned, skipped_arrays))
        if missing_parent:
            print("Нет родительского объекта: %s" % ", ".join(missing_parent))
        return 0

    target = args.out or args.ru
    if not args.out:
        shutil.copyfile(args.ru, args.ru + ".bak")
    with open(target, "w", encoding="utf-8", newline="") as f:
        f.write(out)

    print("Замен: %d | Добавлений: %d | Удалений (prune): %d | Пропущено (в массивах): %d" %
          (replaced, added, pruned, skipped_arrays))
    if replaced_list:
        print("Изменённые переводы (первые 10):")
        for pth, o, n in replaced_list[:10]:
            print("  %s: %s  ->  %s" % (pth, o[:60], n[:60]))
    if missing_parent:
        print("ВНИМАНИЕ, нет родителя: %s" % ", ".join(missing_parent))
    print("Записано: %s%s" % (target, "" if args.out else " (бэкап: %s.bak)" % args.ru))
    return 0


if __name__ == "__main__":
    sys.exit(main())
