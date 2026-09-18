#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""code_highlight.py - общая подсветка фрагментов кода для HTML (SD, Redmine и др.).

Вынесено из `sd_topic.py` (там работало и проверено на живых заявках), чтобы Redmine
и SD красили код ОДИНАКОВО, а не двумя копиями.

API:
    from code_highlight import highlight_code, looks_like_code, CLS_STYLE
    html = highlight_code(text, esc)      # esc - функция экранирования (html.escape)

Поддерживает: JSON, XML/XAML, SQL, C#, YAML, bat/скрипты.
Раскраска: ключевые слова, строки, теги, комментарии, числа, атрибуты,
URL (делает кликабельной ссылкой), `{ }` жёлтым, `[ ]` синим.
"""

from __future__ import annotations

import re

_CODE_KW = re.compile(
    r"\b(?i:SELECT|INSERT|UPDATE|DELETE|FROM|JOIN|LEFT|INNER|OUTER|GROUP|ORDER|HAVING|EXEC|EXECUTE"
    r"|CREATE|ALTER|DROP|TABLE|VIEW|PROCEDURE|FUNCTION|DECLARE|BEGIN|END|RETURN|INTO|VALUES|AND|OR"
    r"|NOT|NULL|AS|ON|TOP|DISTINCT|UNION|CAST|CONVERT|SET|IF|ELSE|WITH|CASE|WHEN|THEN"
    r"|public|private|protected|internal|static|void|class|struct|interface|enum|namespace|using|new"
    r"|var|string|int|bool|double|decimal|object|foreach|while|try|catch|finally|throw|async|await"
    r"|this|get|set|readonly|override|virtual|abstract|base|params|ref|out|in|null|true|false"
    r"|def|import|elif|except|lambda|None|True|False|self|print|yield|global|pass"
    r"|echo|goto|call|exit|rem|start|cd|del|copy|setlocal|endlocal)\b"
)
_CODE_STR = re.compile(r'("(?:[^"\\\n]|\\.)*"|\'(?:[^\'\\\n]|\\.)*\')')
_CODE_TAG = re.compile(r"</?[A-Za-z_][\w:.-]*")
_CODE_CMT = re.compile(r"(?://[^\n]*|#[^\n]*|::[^\n]*|<!--.*?-->|/\*.*?\*/)", re.S)
_CODE_NUM = re.compile(r"\b\d+(?:\.\d+)?\b")
_CODE_ATTR = re.compile(r"\b([A-Za-z_][\w:.-]*)(?=\s*=)")
_CODE_URL = re.compile(r"https?://[^\s<>\"')\]]+")
_CODE_BRACE = re.compile(r"[{}]")
_CODE_BRACK = re.compile(r"[\[\]]")

CLS_STYLE = {
    "kw": "color:#c792ea;font-weight:600",
    "str": "color:#85e89d",
    "num": "color:#ffab70",
    "tag": "color:#79b8ff",
    "cmt": "color:#7d8590;font-style:italic",
    "attr": "color:#ffd580",
    "url": "color:#79d4ff;text-decoration:underline",
    "brace": "color:#ffd580",
    "brack": "color:#79b8ff",
}


def looks_like_code(t: str) -> bool:
    """Похож ли текст на фрагмент кода (первый символ, ключевые слова, теги, структура)."""
    s = t.strip()
    if len(s) < 6:
        return False
    if "://" in s:                       # URL - тоже «код», чтобы покрасить и сделать ссылкой
        return True
    if s[0] in "{[<" or s.startswith("<!--"):
        return True
    if re.match(r"(?i)^(SELECT|INSERT|UPDATE|DELETE|EXEC|CREATE|ALTER|DROP|DECLARE|SET|WITH)\b", s):
        return True
    # код ВНУТРИ текста: JSON/XML/скрипт в середине абзаца
    if ('":' in s and ("{" in s or "[" in s)) or re.search(r"<[A-Za-z_/][\w:.-]*\s*/?>", s) \
            or re.search(r"(?i)\b(SELECT|INSERT|EXEC|FROM|WHERE)\b\s", s) \
            or (";" in s and ("{" in s or "(" in s) and s.count(chr(10)) >= 1):
        return True
    if re.search(r"(?m)^\s*(#include|using |namespace |public |private |def |import |@echo|::|//|<[?\w])", s):
        return True
    if re.search(r"(?m)^\s*[\w.\-]+\s*:\s*\S", s) and t.count(chr(10)) >= 2:
        return True          # yaml-подобное
    return bool(re.search(r"[;{}]\s*$", s) and ("(" in s or "=" in s) and t.count(chr(10)) >= 1)


def highlight_code(t: str, esc) -> str:
    """Подсветка кода для HTML. Экранирование - по частям, `esc` - функция (html.escape)."""
    if not looks_like_code(t):
        return esc(t)
    pat = re.compile(
        f"(?P<cmt>{_CODE_CMT.pattern})|(?P<str>{_CODE_STR.pattern})"
        f"|(?P<tag>{_CODE_TAG.pattern})|(?P<kw>{_CODE_KW.pattern})"
        f"|(?P<num>{_CODE_NUM.pattern})|(?P<attr>{_CODE_ATTR.pattern})"
        f"|(?P<url>{_CODE_URL.pattern})|(?P<brace>{_CODE_BRACE.pattern})|(?P<brack>{_CODE_BRACK.pattern})",
        re.M,
    )
    order = ("cmt", "str", "url", "tag", "kw", "num", "attr", "brace", "brack")
    out, last = [], 0
    for m in pat.finditer(t):
        out.append(esc(t[last:m.start()]))
        cls = next(k for k in order if m.group(k) is not None)
        if cls == "url":
            _u = esc(m.group(0))
            out.append(f'<a href="{_u}" target="_blank" rel="noopener" '
                       f'style="{CLS_STYLE["url"]}">{_u}</a>')
        else:
            out.append(f'<span style="{CLS_STYLE[cls]}">{esc(m.group(0))}</span>')
        last = m.end()
    out.append(esc(t[last:]))
    return "".join(out)
