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
    elif args.cmd == "page":
        cmd_page(args.hash, args.wait)
    else:
        cmd_rest(args.path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
