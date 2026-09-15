#!/usr/bin/env python3
# compare_i18n_keys.py — сравнение ключей локализации Hermes (en.ts эталон vs ru.ts оверрайды).
#
# Зачем: в новой архитектуре Hermes/Desktop en.ts — полный словарь
# (`export const en: Translations = {...}`), а ru.ts — ОВЕРРАЙДЫ
# (`export const ru = defineLocale({...})` = mergeTranslations(en, overrides)).
# Поэтому построчное сравнение файлов (WinMerge) бессмысленно: разные обёртки,
# импорты и порядок секций. Этот скрипт сравнивает СТРУКТУРУ КЛЮЧЕЙ и выдаёт:
#   * НЕ ПЕРЕВЕДЁННЫЕ ключи (есть в en, нет в ru) — с английским текстом
#   * ОСИРОТЕВШИЕ ключи (есть в ru, нет в en) — мусор после обновлений Hermes
#   * ключи с ИДЕНТИЧНЫМ текстом en/ru — возможный неперевод
#   * сводку по секциям
#
# Использование:
#   python compare_i18n_keys.py [--en PATH] [--ru PATH] [--text] [--same] [--json]
#
# По умолчанию: ../en-locale/en.ts и ../ru-locale/ru.ts относительно scripts/py.
# Скрипт только читает файлы (read-only).
import argparse
import json
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEFAULT_EN = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "en-locale", "en.ts"))
DEFAULT_RU = os.path.normpath(os.path.join(SCRIPT_DIR, "..", "ru-locale", "ru.ts"))

VALUE_KINDS = ("string", "template", "other", "number")


class LocaleParser:
    """Мини-парсер TS-объекта локали: собирает (путь, вид, текст) по ключам."""

    def __init__(self, src):
        if src.startswith("\ufeff"):
            src = src[1:]
        self.s = src
        self.i = 0
        self.n = len(src)
        self.entries = []

    # ---------- низкоуровневые помощники ----------
    def skip_ws(self):
        s, n = self.s, self.n
        while self.i < n:
            c = s[self.i]
            if c in " \t\r\n":
                self.i += 1
            elif c == "/" and self.i + 1 < n and s[self.i + 1] == "/":
                j = s.find("\n", self.i)
                self.i = n if j < 0 else j + 1
            elif c == "/" and self.i + 1 < n and s[self.i + 1] == "*":
                j = s.find("*/", self.i + 2)
                self.i = n if j < 0 else j + 2
            else:
                break

    def read_string(self):
        """Читает строковый литерал ('..', "..", `..`) с escape. Возвращает (текст, вид)."""
        s = self.s
        quote = s[self.i]
        self.i += 1
        buf = []
        while self.i < self.n:
            c = s[self.i]
            if c == "\\":
                buf.append(s[self.i:self.i + 2])
                self.i += 2
                continue
            if c == quote:
                self.i += 1
                break
            buf.append(c)
            self.i += 1
        kind = "template" if quote == "`" else "string"
        return "".join(buf), kind

    def parse_key(self):
        """Ключ: идентификатор или строковый литерал. Вычисляемые [..] пропускаем."""
        self.skip_ws()
        if self.i >= self.n:
            return None
        c = self.s[self.i]
        if c in "'\"`":
            text, _ = self.read_string()
            return text
        if c == "[":
            depth = 0
            while self.i < self.n:
                ch = self.s[self.i]
                if ch in "'\"`":
                    self.read_string()
                    continue
                if ch == "[":
                    depth += 1
                elif ch == "]":
                    depth -= 1
                    self.i += 1
                    if depth == 0:
                        break
                    continue
                self.i += 1
            return None
        j = self.i
        while self.i < self.n and (self.s[self.i].isalnum() or self.s[self.i] in "_$"):
            self.i += 1
        return self.s[j:self.i] or None

    def join(self, path, key):
        if not key:
            return path
        return (path + "." + key) if path else key

    # ---------- структурный обход ----------
    def parse_object(self, path):
        assert self.s[self.i] == "{"
        self.i += 1
        while self.i < self.n:
            self.skip_ws()
            if self.i >= self.n:
                break
            c = self.s[self.i]
            if c == "}":
                self.i += 1
                break
            if c == ",":
                self.i += 1
                continue
            key = self.parse_key()
            self.skip_ws()
            if self.i < self.n and self.s[self.i] == ":":
                self.i += 1
            elif self.i < self.n and self.s[self.i] == "(":
                # геттер/метод — пропускаем тело до }
                pass
            self.parse_value(self.join(path, key))

    def parse_array(self, path):
        assert self.s[self.i] == "["
        self.i += 1
        idx = 0
        while self.i < self.n:
            self.skip_ws()
            if self.i >= self.n:
                break
            if self.s[self.i] == "]":
                self.i += 1
                break
            if self.s[self.i] == ",":
                self.i += 1
                continue
            self.parse_value("%s[%d]" % (path, idx))
            idx += 1

    def parse_value(self, path):
        self.skip_ws()
        if self.i >= self.n:
            return
        c = self.s[self.i]
        if c == "{":
            self.entries.append((path, "obj", ""))
            self.parse_object(path)
            return
        if c == "[":
            self.entries.append((path, "arr", ""))
            self.parse_array(path)
            return
        if c in "'\"`":
            text, kind = self.read_string()
            self.entries.append((path, kind, text))
            return
        # скаляр/функция: читаем до , или } или ] с учётом вложенности и строк
        start = self.i
        depth = 0
        while self.i < self.n:
            ch = self.s[self.i]
            if ch in "'\"`":
                self.read_string()
                continue
            if ch in "([{":
                depth += 1
                self.i += 1
                continue
            if ch in ")]}":
                if depth == 0:
                    break
                depth -= 1
                self.i += 1
                continue
            if ch == "," and depth == 0:
                break
            self.i += 1
        raw = self.s[start:self.i].strip()
        if "=>" in raw or raw.startswith("function"):
            self.entries.append((path, "fn", ""))
        elif raw and raw[0].isdigit():
            self.entries.append((path, "number", raw))
        else:
            self.entries.append((path, "other", raw))


def parse_locale(path):
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        src = f.read()
    p = LocaleParser(src)
    # точка входа: первый '{' после объявления локали
    anchor = src.find("export const ru")
    if anchor < 0:
        anchor = src.find("export const en")
    if anchor < 0:
        anchor = 0
    brace = src.find("{", anchor)
    if brace < 0:
        raise SystemExit("не найден объект локали в %s" % path)
    p.i = brace
    p.parse_object("")
    return p.entries


def split(entries):
    """Возвращает (листья {path: (kind, text)}, секции-множество)."""
    leaves = {}
    sections = set()
    for path, kind, text in entries:
        if not path:
            continue
        sections.add(path.split(".", 1)[0].split("[", 1)[0])
        if kind not in ("obj", "arr"):
            leaves[path] = (kind, text)
    return leaves, sections


def truncate(text, limit=60):
    text = " ".join(str(text).split())
    return text if len(text) <= limit else text[: limit - 1] + "…"


def main():
    ap = argparse.ArgumentParser(description="Сравнение ключей en.ts (эталон) и ru.ts (оверрайды)")
    ap.add_argument("--en", default=DEFAULT_EN, help="путь к en.ts (эталон)")
    ap.add_argument("--ru", default=DEFAULT_RU, help="путь к ru.ts (перевод)")
    ap.add_argument("--text", action="store_true", help="показывать английский текст непереведённых ключей")
    ap.add_argument("--same", action="store_true", help="показать ключи с идентичным текстом en/ru (возможный неперевод)")
    ap.add_argument("--limit", type=int, default=25, help="сколько ключей печатать в списке (0 = все)")
    ap.add_argument("--json", action="store_true", help="вывод в JSON")
    args = ap.parse_args()

    for label, path in (("en", args.en), ("ru", args.ru)):
        if not os.path.exists(path):
            raise SystemExit("[ОШИБКА] не найден %s: %s" % (label, path))

    en_entries = parse_locale(args.en)
    ru_entries = parse_locale(args.ru)
    en, en_sections = split(en_entries)
    ru, ru_sections = split(ru_entries)

    missing = sorted(set(en) - set(ru))
    extra = sorted(set(ru) - set(en))
    same = sorted(k for k in (set(en) & set(ru)) if en[k][1] and en[k][1] == ru[k][1])

    # сводка по секциям: сколько ключей-значений в en и в ru
    def per_section(leaves):
        out = {}
        for k in leaves:
            sec = k.split(".", 1)[0].split("[", 1)[0]
            out[sec] = out.get(sec, 0) + 1
        return out

    en_sec, ru_sec = per_section(en), per_section(ru)
    sec_rows = []
    for sec in sorted(set(en_sec) | set(ru_sec)):
        e, r = en_sec.get(sec, 0), ru_sec.get(sec, 0)
        if e != r or e == 0:
            sec_rows.append((sec, e, r, r - e))

    if args.json:
        print(json.dumps({
            "en": {"file": args.en, "sections": len(en_sections), "values": len(en)},
            "ru": {"file": args.ru, "sections": len(ru_sections), "values": len(ru)},
            "missing": [{"key": k, "en": en[k][1]} for k in missing],
            "extra": extra,
            "same_text": same,
            "sections": [{"section": s, "en": e, "ru": r, "delta": d} for s, e, r, d in sec_rows],
        }, ensure_ascii=False, indent=2))
        return 0

    print("=" * 78)
    print("  Сравнение ключей локализации Hermes: en.ts (эталон) vs ru.ts (оверрайды)")
    print("=" * 78)
    print("  en.ts: %s" % args.en)
    print("  ru.ts: %s" % args.ru)
    print()
    print("  en: секций %d, ключей-значений %d" % (len(en_sections), len(en)))
    print("  ru: секций %d, ключей-значений %d" % (len(ru_sections), len(ru)))
    print()

    # --- не переведено ---
    print("  НЕ ПЕРЕВЕДЕНО (есть в en, нет в ru): %d ключей" % len(missing))
    if missing:
        by_sec = {}
        for k in missing:
            by_sec.setdefault(k.split(".", 1)[0].split("[", 1)[0], []).append(k)
        for sec in sorted(by_sec, key=lambda s: (-len(by_sec[s]), s)):
            keys = by_sec[sec]
            whole = sec not in ru_sections
            print("    %-22s %3d ключей%s" % (sec, len(keys), "  ← вся секция отсутствует" if whole else ""))
            shown = keys if args.limit == 0 else keys[: args.limit]
            for k in shown:
                if args.text:
                    print("        %s  →  %s" % (k, truncate(en[k][1], 70)))
                else:
                    print("        %s" % k)
            if args.limit and len(keys) > args.limit:
                print("        … и ещё %d" % (len(keys) - args.limit))
    print()

    # --- осиротевшие ---
    print("  ОСИРОТЕВШИЕ (есть в ru, нет в en): %d ключей" % len(extra))
    if extra:
        shown = extra if args.limit == 0 else extra[: args.limit]
        for k in shown:
            print("    %s" % k)
        if args.limit and len(extra) > args.limit:
            print("    … и ещё %d" % (len(extra) - args.limit))
    print()

    # --- идентичный текст ---
    if args.same:
        print("  ИДЕНТИЧНЫЙ ТЕКСТ en/ru (возможный неперевод): %d ключей" % len(same))
        shown = same if args.limit == 0 else same[: args.limit]
        for k in shown:
            print("    %s  =  %s" % (k, truncate(en[k][1], 60)))
        if args.limit and len(same) > args.limit:
            print("    … и ещё %d" % (len(same) - args.limit))
        print()
    else:
        print("  ИДЕНТИЧНЫЙ ТЕКСТ en/ru: %d ключей (показать: --same)" % len(same))
        print()

    # --- сводка по секциям ---
    if sec_rows:
        print("  СВОДКА ПО СЕКЦИЯМ (только расхождения en/ru):")
        print("    %-24s %6s %6s %7s" % ("секция", "en", "ru", "Δ"))
        for sec, e, r, d in sec_rows:
            print("    %-24s %6d %6d %+7d" % (sec, e, r, d))
        print()
    else:
        print("  СВОДКА ПО СЕКЦИЯМ: расхождений нет")
        print()

    print("  ИТОГ: непереведённых %d, осиротевших %d, идентичных (возможных) %d" % (len(missing), len(extra), len(same)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
