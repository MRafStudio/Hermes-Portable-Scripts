#!/usr/bin/env python3
"""r_k Service Desk (Naumen) - чтение через сессию и интерфейс. ТОЛЬКО ЧТЕНИЕ.

Принцип этого портала отличается от Redmine: плоского REST с ключом нет, интерфейс - GWT-SPA
на сессии (JSESSIONID + CSRF), а `find`-точки отдают данные не всякой роли. Поэтому основной
рабочий путь - вход и снятие содержимого раздела своим headless-Chrome.

Команды::

    sd.py login                 войти (python-сессия: cookies для REST)
    sd.py hlogin                войти в headless-Chrome (там, где читаем разделы)
    sd.py page ["<hash>"]       открыть раздел и напечатать текст (по умолчанию - заявки)
    sd.py rest "<подпуть>"      GET к /sd/services/rest/... python-сессией

Ничего не создаём, не комментируем, не меняем: только чтение разделов и GET-запросы.
"""
from __future__ import annotations

import argparse
import base64
import http.cookiejar
import json
import pathlib
import re
import ssl
import subprocess
import urllib.error
import urllib.parse
import urllib.request

ENV = pathlib.Path("D:/NEURO/Hermes/data/hermes/.env")
JAR = pathlib.Path("D:/NEURO/Hermes/data/temp/sd_py_cookies.txt")
PY = "D:/NEURO/Hermes/data/hermes/hermes-agent/venv/Scripts/python.exe"
CDP = "D:/NEURO/Hermes/scripts/py/chrome_cdp.py"
TAB_CALLS = ("#uuid:employee$7297673!%7B%22tab%22:%22ff4dbcb1-140c-0503-0000-ffffffffc80e7f4a%22%7D")

TXT = ENV.read_text(encoding="utf-8")
env = lambda k: next(l.split("=", 1)[1].strip() for l in TXT.splitlines() if l.startswith(k + "="))
BASE = env("SD_UCS_URL").rstrip("/")

CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE


def opener():
    jar = http.cookiejar.LWPCookieJar(str(JAR))
    if JAR.exists():
        jar.load(ignore_discard=True, ignore_expires=True)
    op = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(jar),
                                     urllib.request.HTTPSHandler(context=CTX))
    op.addheaders = [("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"),
                     ("Accept-Language", "ru,en;q=0.8")]
    return op, jar


def cmd_login() -> None:
    op, jar = opener()
    page = op.open(BASE + "/sd/", timeout=30).read().decode("utf-8", "replace")
    csrf = re.search(r'name="_csrf" value="([^"]+)"', page)
    data = urllib.parse.urlencode({"username": env("SD_UCS_USER"), "password": env("SD_UCS_PASS"),
                                   "_csrf": csrf.group(1) if csrf else ""}).encode()
    req = urllib.request.Request(BASE + "/sd/login", data=data, method="POST",
                                 headers={"Content-Type": "application/x-www-form-urlencoded"})
    with op.open(req, timeout=30) as r:
        print("вход:", r.status, "->", r.geturl())
    jar.save(ignore_discard=True, ignore_expires=True)
    print("сессия сохранена (JSESSIONID)")


def _cdp(url: str, js: str, wait: str) -> str:
    r = subprocess.run([PY, CDP, url, "--eval", js, "--wait", wait, "--keep"],
                       capture_output=True, text=True, timeout=300)
    return r.stdout or ""


def cmd_hlogin(quiet: bool = False) -> None:
    """Вход в САМОМ headless-Chrome: сессия портала привязана к браузеру, а не к cookies файла.

    Вторая сессия того же пользователя вытесняет первую (портал отвечает «Сессия завершена»),
    поэтому вход делаем там, где потом читаем - в профиле headless-Chrome.
    """
    js = ("(function(){var u=document.getElementById('username'),p=document.getElementById('password');"
          "if(!u||!p){return 'форма логина недоступна: '+location.href;}"
          f"u.value={json.dumps(env('SD_UCS_USER'))};p.value={json.dumps(env('SD_UCS_PASS'))};"
          "document.getElementById('submit-button').click();return 'форма отправлена';})()")
    out = _cdp(BASE + "/sd/", js, "8000")
    if not quiet:
        try:
            print("headless-логин:", json.loads(out)["runs"][0]["value"])
        except Exception:  # noqa: BLE001
            print("headless-логин: неясный ответ", " ".join(out.split())[:200])


def cmd_page(hash_route: str, wait: str) -> None:
    url = BASE + "/sd/operator/" + (hash_route or TAB_CALLS)
    js = ("JSON.stringify({url: location.href, title: document.title,"
          " text: document.body.innerText.slice(0, 6000)})")

    def fetch() -> dict:
        out = _cdp(url, js, wait)
        try:
            return json.loads(json.loads(out)["runs"][0]["value"])
        except Exception:  # noqa: BLE001
            return {"url": url, "title": "", "text": " ".join(out.split())[:600]}

    val = fetch()
    if "Сессия завершена" in val.get("text", ""):
        print("сессия истекла - вхожу заново в headless")
        cmd_hlogin(quiet=True)
        val = fetch()
    print("URL:", val["url"], "|", val.get("title", "")[:70])
    print(" ".join(val.get("text", "").split())[:3000])


def _route_no_nav(route: str) -> str:
    """URL раздела - без второго обращения к браузеру (для подписи в выводе)."""
    return BASE + "/sd/operator/" + route


def _route(route: str, wait: str = "18000") -> dict:
    """Открыть раздел SPA и вернуть снимок (url, текст, ссылки)."""
    js = ("JSON.stringify({url: location.href, title: document.title,"
          " text: document.body.innerText.slice(0, 12000),"
          " rows: Array.from(document.querySelectorAll('tr')).map(function(tr){"
          "var a=tr.querySelector('a[href*=\"serviceCall$\"]');"
          "var m=(tr.innerText||'').match(/^\\s*(\\d{3,7})\\s/);"
          "return {num: m?m[1]:'', href: a?a.getAttribute('href'):'',"
          " text: (tr.innerText||'').replace(/\\s+/g,' ').slice(0,170)};"
          "}).filter(function(r){return r.num;})})")
    out = _cdp(BASE + "/sd/operator/" + route, js, wait)
    try:
        return json.loads(json.loads(out)["runs"][0]["value"])
    except Exception:  # noqa: BLE001
        return {"url": route, "title": "", "text": " ".join(out.split())[:800], "links": []}


def _esearch_route(query: str, scope: str = "ALL_OBJECTS") -> str:
    """Роут поиска SPA: кавычки и пробелы кодируем, `:` и `,` - нет.

    scope: ALL_OBJECTS (по всем), ACTIVE_OBJECTS_ONLY (активные), ARCHIVE_OBJECTS_ONLY (архив).
    """
    payload = json.dumps({"query": query, "pid": "1"}, ensure_ascii=False)
    return ("#esearch:full:serviceCall:" + scope + "!"
            + payload.replace('"', "%22").replace(" ", "%20"))


def cmd_search(query: str, wait: str) -> None:
    """Поиск по ВСЕМ заявкам UCS (не только своим): интерфейс открывает свои результаты.

    Роут найден у самого интерфейса: #esearch:full:serviceCall:ALL_OBJECTS!{"query": ...}.
    Номера берём из СТРОК ТАБЛИЦЫ, а не из ссылок: у части строк номер идёт текстом без
    ссылки, и парсер по ссылкам молча теряет заявки (проверено: 9 вместо 11).
    """
    payload = _esearch_route(query)
    route = payload
    # Сброс состояния поиска: интерфейс запоминает область и падает с
    # java.lang.IllegalArgumentException: Enum constant undefined, если в сохранённом
    # состоянии остался неизвестный режим - тогда выдача приходит урезанной.
    _cdp(BASE + "/sd/operator/", "(function(){try{localStorage.clear();return 'state cleared';}"
                                   "catch(e){return 'clear failed';}})()", "6000")
    d = _route(route, wait)
    print("поиск:", query, "|", d.get("title", "")[:60])
    print(" ".join(d.get("text", "").split())[:1800])
    cards = []
    for row in d.get("rows", []):
        num, href = str(row.get("num", "")).strip(), str(row.get("href", "")).strip()
        if num.isdigit() and (num, href) not in cards:
            cards.append((num, href))
    print("\nкарточки (номер | роут):")
    for num, href in cards:
        print(f"   {num} | {href}")


def cmd_card(target: str, wait: str) -> None:
    """Карточка заявки целиком: описание, код решения, переписка (только чтение).

    target - либо номер заявки (тогда сначала поиск за номером), либо готовый роут
    ``#uuid:serviceCall$<id>``.
    """
    route = target
    if target.isdigit():
        found = _route(_esearch_route(target), wait)
        hit = next((l.split("|", 1)[1].strip() for l in found.get("links", [])
                    if l.split("|")[0].strip() == target and "serviceCall$" in l), "")
        if not hit:
            print(f"заявка {target} не найдена в выдаче поиска")
            return
        route = hit
    # Раскрываем скрытые тексты («Подробнее») И снимаем текст В ОДНОМ проходе: повторный
    # вызов chrome_cdp навигирует заново, и раскрытие теряется.
    js = ("(function(){var n=0;Array.prototype.forEach.call(document.querySelectorAll('a,span,div'),function(e){"
          "if((e.innerText||'').trim()==='Подробнее'){"
          "['mousedown','mouseup','click'].forEach(function(t){e.dispatchEvent(new MouseEvent(t,{bubbles:true,cancelable:true,view:window}));});n++;}});"
          "var fr=Array.from(document.querySelectorAll('iframe')).map(function(f){"
          "try{var d=f.contentDocument;return (d&&d.body)?d.body.innerText.replace(/\\s+/g,' ').trim():'';}"
          "catch(e){return '';}}).filter(function(s){return s.length>20;});"
          "return JSON.stringify({clicked:n, text:document.body.innerText.slice(0,14000), frames:fr});})()")
    out = _cdp(BASE + "/sd/operator/" + route, js, wait)
    try:
        val = json.loads(json.loads(out)["runs"][0]["value"])
        text = val["text"]
        print("раскрыто кнопок «Подробнее»:", val["clicked"])
        fr = val.get("frames") or []
        if fr:
            # Тексты описания и переписки живут в iframe richText (тот же origin).
            print(f"\n===== ОПИСАНИЕ И ПЕРЕПИСКА ({len(fr)} блоков) =====")
            for i, s in enumerate(fr, 1):
                print(f"\n[{i}] {' '.join(s.split())[:1200]}")
    except Exception:  # noqa: BLE001
        text = " ".join(out.split())[:4000]
    print("карточка:", _route_no_nav(route)[:120])
    print(" ".join(text.split())[:6000])


def cmd_rest(sub: str) -> None:
    op, _ = opener()
    if "/" not in sub:  # короткая форма: entity$list + фильтр JSON
        parts = sub.split(None, 1)
        entity = parts[0]
        flt = json.loads(parts[1]) if len(parts) > 1 else {}
        tok = "40x" + base64.b64encode(json.dumps(flt, ensure_ascii=False).encode()).decode()
        sub = f"/sd/services/rest/find/{entity}/{tok}"
    elif not sub.startswith("/"):
        sub = "/sd/services/rest/" + sub
    req = urllib.request.Request(BASE + sub, headers={
        "Accept": "application/json", "X-Requested-With": "XMLHttpRequest",
        "Referer": BASE + "/sd/operator/", "Origin": BASE})
    try:
        with op.open(req, timeout=60) as r:
            body = r.read().decode("utf-8", "replace")
        print(r.status, body[:2000])
    except urllib.error.HTTPError as e:
        print("HTTP", e.code, (e.read().decode("utf-8", "replace")[:300] if e.fp else ""))


def main() -> int:
    ap = argparse.ArgumentParser(description="r_k Service Desk: чтение (только GET)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("login")
    sub.add_parser("hlogin")
    s = sub.add_parser("search")
    s.add_argument("query")
    s.add_argument("--wait", default="18000")
    c = sub.add_parser("card")
    c.add_argument("target", help="номер заявки или роут #uuid:serviceCall$<id>")
    c.add_argument("--wait", default="18000")
    p = sub.add_parser("page")
    p.add_argument("hash", nargs="?", default="")
    p.add_argument("--wait", default="16000")
    rr = sub.add_parser("rest")
    rr.add_argument("path")
    args = ap.parse_args()
    if args.cmd == "login":
        cmd_login()
    elif args.cmd == "hlogin":
        cmd_hlogin()
    elif args.cmd == "search":
        cmd_search(args.query, args.wait)
    elif args.cmd == "card":
        cmd_card(args.target, args.wait)
    elif args.cmd == "page":
        cmd_page(args.hash, args.wait)
    else:
        cmd_rest(args.path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
