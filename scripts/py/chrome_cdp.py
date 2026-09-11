#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Chrome по CDP — свой headless-инстанс, БЕЗ nag про живой профиль.

ЗАЧЕМ ЭТО НУЖНО
    На этой машине живой Chrome бесполезен для автоматизации: Chromium >=136
    запрещает CDP на дефолтном профиле, открытом в UI, а harness (browser_exec)
    цепляется именно к запущенному Chrome и падает с nag про профиль.
    Поэтому инструмент поднимает СВОЙ headless Chrome с ОТДЕЛЬНЫМ
    --user-data-dir и говорит с ним по CDP. Твой браузер, вкладки, логины и
    сессии не затрагиваются вообще.

ЧТО УМЕЕТ
    --text            видимый текст страницы (innerText)
    --sel CSS         текст всех совпадений селектора (JSON-массив)
    --dom             outerHTML страницы (в stdout или --out файл)
    --eval JS         выполнить JS и вернуть значение
    --shot FILE.png   скриншот (при --widths — по файлу на каждую ширину)
    --check-overflow  найти элементы, которые не влезают по ширине
    --widths LIST     прогнать одну страницу на нескольких ширинах (300,380,460)

ПРИМЕРЫ
    python chrome_cdp.py page.html --text
    python chrome_cdp.py page.html --check-overflow --widths 300,380,460,700
    python chrome_cdp.py https://example.com --sel "h2" --shot out.png
    python chrome_cdp.py page.html --eval "document.title" --width 520
    python chrome_cdp.py page.html --dom --out dom.html
    python chrome_cdp.py page.html --eval "1+1" --keep   # не гасить Chrome

ЯЗЫК ЦЕЛИ
    Локальный путь, file://-URL или http(s):// . Относительный путь считается
    от текущего каталога.

ЗАВИСИМОСТИ
    Только stdlib; для JS/скриншотов нужен пакет websockets (в venv Hermes он
    есть: 15.x). Установка при необходимости:
    uv pip install --python <python> websockets

Что переиспользуется: если на порту (по умолчанию 9223) уже живёт наш Chrome,
инструмент не поднимает второй — повторные вызовы летают мгновенно. Опция
--fresh сначала гасит старый, потом поднимает новый.
"""
from __future__ import annotations

import argparse
import asyncio
import base64
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import urllib.request

DEFAULT_PORT = int(os.environ.get("CHROME_CDP_PORT", "9223"))
DEFAULT_PROFILE = os.path.join(tempfile.gettempdir(), "chrome-cdp-profile")

CHROME_CANDIDATES = [
    os.path.expandvars(r"%ProgramFiles%\Google\Chrome\Application\chrome.exe"),
    os.path.expandvars(r"%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"),
    os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"),
    os.path.expandvars(r"%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"),
    os.path.expandvars(r"%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"),
    "/usr/bin/google-chrome",
    "/usr/bin/chromium",
    "/usr/bin/chromium-browser",
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
]

# Элементы, которые распирают страницу вбок: клиентская ширина меньше контента.
OVERFLOW_JS = r"""
(() => {
  const bad = [];
  document.querySelectorAll('*').forEach(e => {
    const cs = getComputedStyle(e);
    if (!cs || cs.display === 'none' || cs.position === 'fixed' || cs.position === 'absolute') return;
    if (e.clientWidth > 0 && e.scrollWidth > e.clientWidth + 1) {
      bad.push({
        tag: e.tagName.toLowerCase(),
        id: e.id || '',
        cls: String(e.className || '').slice(0, 60),
        have: e.clientWidth,
        need: e.scrollWidth
      });
    }
  });
  return {
    win: innerWidth,
    doc: document.documentElement.scrollWidth,
    body: document.body ? document.body.scrollWidth : 0,
    count: bad.length,
    worst: bad.sort((a, b) => (b.need - b.have) - (a.need - a.have)).slice(0, 25)
  };
})()
"""


def die(msg: str, code: int = 2):
    print(msg, file=sys.stderr)
    raise SystemExit(code)


def find_chrome(explicit: str = "") -> str:
    if explicit:
        if pathlib.Path(explicit).exists():
            return explicit
        die(f"Chrome не найден по указанному пути: {explicit}")
    for candidate in CHROME_CANDIDATES:
        if candidate and pathlib.Path(candidate).exists():
            return candidate
    die("Chrome/Edge не найдены. Укажи путь: --chrome \"C:/path/to/chrome.exe\"")


def http_json(port: int, path: str, timeout: float = 3.0):
    url = f"http://127.0.0.1:{port}{path}"
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8", "replace"))


def port_alive(port: int) -> bool:
    try:
        http_json(port, "/json/version")
        return True
    except Exception:
        return False


def kill_stale(port: int, profile: str):
    """Погасить прошлый наш инстанс (чтобы --fresh был честным)."""
    try:
        http_json(port, "/json/close/", timeout=1.0)
    except Exception:
        pass
    try:
        browser_ws = http_json(port, "/json/version").get("webSocketDebuggerUrl")
    except Exception:
        browser_ws = None
    if browser_ws:
        try:
            asyncio.run(_ws_send(browser_ws, "Browser.close", timeout=3))
        except Exception:
            pass
    # профиль-лок держит процесс — ждём, потом добиваем по имени профиля
    for _ in range(20):
        if not port_alive(port):
            break
        time.sleep(0.2)
    if port_alive(port):
        if os.name == "nt":
            subprocess.run(
                ["taskkill", "/F", "/FI", f"WINDOWTITLE eq chrome*"],
                capture_output=True,
            )
        die(f"порт {port} занят чужим процессом; освободи его или задай --port")


async def _ws_send(ws_url: str, method: str, params: dict | None = None, timeout: float = 5):
    import websockets

    async with websockets.connect(ws_url, max_size=64 * 1024 * 1024) as ws:
        await ws.send(json.dumps({"id": 1, "method": method, "params": params or {}}))
        while True:
            raw = await asyncio.wait_for(ws.recv(), timeout=timeout)
            data = json.loads(raw)
            if data.get("id") == 1:
                return data.get("result", {})


def launch(port: int, profile: str, chrome: str, width: int, height: int) -> subprocess.Popen | None:
    if port_alive(port):
        return None
    os.makedirs(profile, exist_ok=True)
    proc = subprocess.Popen(
        [
            chrome,
            "--headless=new",
            "--disable-gpu",
            "--no-first-run",
            "--no-default-browser-check",
            "--disable-extensions",
            "--hide-scrollbars",
            f"--remote-debugging-port={port}",
            f"--user-data-dir={profile}",
            f"--window-size={width},{height}",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(80):
        if port_alive(port):
            return proc
        if proc.poll() is not None:
            die("Chrome завершился сразу после старта (проверь --user-data-dir и --chrome)")
        time.sleep(0.25)
    die(f"Chrome не открыл CDP-порт {port} за 20 с")


async def _ws_call(ws, msg_id: int, method: str, params: dict | None = None, timeout: float = 30):
    await ws.send(json.dumps({"id": msg_id, "method": method, "params": params or {}}))
    while True:
        raw = await asyncio.wait_for(ws.recv(), timeout=timeout)
        data = json.loads(raw)
        if data.get("id") == msg_id:
            if "error" in data:
                raise RuntimeError(f"CDP error on {method}: {data['error']}")
            return data.get("result", {})


async def drive(url: str, widths: list, opts: dict) -> list:
    """Открыть url на каждой ширине и выполнить запрошенные действия."""
    import websockets

    targets = http_json(opts["port"], "/json/list")
    page = next((t for t in targets if t.get("type") == "page"), None)
    if page is None:
        die("в CDP нет page-таргета")

    runs = []
    async with websockets.connect(page["webSocketDebuggerUrl"], max_size=128 * 1024 * 1024) as ws:
        mid = 0
        await _ws_call(ws, mid, "Page.enable"); mid += 1
        for width in widths:
            await _ws_call(ws, mid, "Emulation.setDeviceMetricsOverride",
                           {"width": width, "height": opts["height"],
                            "deviceScaleFactor": 1, "mobile": False}); mid += 1
            await _ws_call(ws, mid, "Page.navigate", {"url": url}); mid += 1
            await asyncio.sleep(max(opts["wait"], 0) / 1000.0)

            run = {"width": width}
            if opts["overflow"]:
                res = await _ws_call(ws, mid, "Runtime.evaluate",
                                     {"expression": OVERFLOW_JS, "returnByValue": True}); mid += 1
                run["overflow"] = res.get("result", {}).get("value")
            if opts["eval"]:
                res = await _ws_call(ws, mid, "Runtime.evaluate",
                                     {"expression": opts["eval"], "returnByValue": True,
                                      "awaitPromise": True}); mid += 1
                if res.get("exceptionDetails"):
                    run["eval_error"] = json.dumps(res["exceptionDetails"], ensure_ascii=False)[:600]
                else:
                    run["value"] = res.get("result", {}).get("value")
            if opts["sel"] or opts["text"]:
                expr = ("Array.from(document.querySelectorAll(%s)).map(e => e.innerText || e.textContent)"
                        % json.dumps(opts["sel"])) if opts["sel"] else "document.body ? document.body.innerText : ''"
                res = await _ws_call(ws, mid, "Runtime.evaluate",
                                     {"expression": expr, "returnByValue": True}); mid += 1
                value = res.get("result", {}).get("value")
                if opts["sel"]:
                    run["sel"] = value
                else:
                    run["text"] = value
            if opts["dom"]:
                res = await _ws_call(ws, mid, "Runtime.evaluate",
                                     {"expression": "document.documentElement.outerHTML",
                                      "returnByValue": True}); mid += 1
                run["dom"] = res.get("result", {}).get("value")
            if opts["shot"]:
                res = await _ws_call(ws, mid, "Page.captureScreenshot",
                                     {"format": "png", "captureBeyondViewport": True}); mid += 1
                path = opts["shot"]
                if len(widths) > 1:
                    stem, dot, ext = path.rpartition(".")
                    path = f"{stem or path}-{width}{dot}{ext}" if dot else f"{path}-{width}.png"
                pathlib.Path(path).write_bytes(base64.b64decode(res["data"]))
                run["shot"] = path
            runs.append(dict(run))
    return runs


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Chrome по CDP: свой headless-профиль, без nag и без риска для живых сессий")
    ap.add_argument("target", help="локальный путь, file:// или http(s)://")
    ap.add_argument("--text", action="store_true", help="видимый текст страницы")
    ap.add_argument("--sel", default="", help="CSS-селектор: текст всех совпадений")
    ap.add_argument("--dom", action="store_true", help="outerHTML страницы")
    ap.add_argument("--eval", default="", help="JS-выражение, вернуть значение")
    ap.add_argument("--shot", default="", help="PNG-файл для скриншота")
    ap.add_argument("--out", default="", help="куда писать большой вывод (--dom/--text)")
    ap.add_argument("--check-overflow", action="store_true",
                    help="найти элементы, распирающие страницу вбок")
    ap.add_argument("--width", type=int, default=520)
    ap.add_argument("--widths", default="", help="список ширин: 300,380,460")
    ap.add_argument("--height", type=int, default=900)
    ap.add_argument("--wait", type=int, default=1200, help="мс после навигации")
    ap.add_argument("--port", type=int, default=DEFAULT_PORT)
    ap.add_argument("--profile", default=DEFAULT_PROFILE, help="свой --user-data-dir (чужой не трогаем)")
    ap.add_argument("--chrome", default="", help="путь к chrome.exe (по умолчанию ищем сами)")
    ap.add_argument("--keep", action="store_true", help="не гасить Chrome после работы")
    ap.add_argument("--fresh", action="store_true", help="погасить прошлый наш инстанс и поднять новый")
    a = ap.parse_args()

    try:
        import websockets  # noqa: F401
    except ImportError:
        die("нужен пакет websockets: uv pip install --python <python> websockets")

    target = a.target
    if not target.startswith(("http://", "https://", "file://", "about:", "data:")):
        p = pathlib.Path(target)
        if not p.exists():
            die(f"нет такого файла: {p.resolve()}")
        target = p.resolve().as_uri()

    if a.fresh:
        kill_stale(a.port, a.profile)

    widths = [int(w) for w in a.widths.split(",") if w.strip()] if a.widths else [a.width]
    opts = {
        "port": a.port, "height": a.height, "wait": a.wait,
        "overflow": a.check_overflow, "eval": a.eval, "sel": a.sel,
        "text": a.text, "dom": a.dom, "shot": a.shot,
    }
    if not any((a.check_overflow, a.eval, a.sel, a.text, a.dom, a.shot)):
        opts["overflow"] = True          # разумный дефолт: просто «что за страница»

    proc = launch(a.port, a.profile, find_chrome(a.chrome), widths[0], a.height)
    try:
        runs = asyncio.run(drive(target, widths, opts))
    finally:
        if proc is not None and not a.keep:
            _shutdown(a.port, proc)

    # текстовые режимы печатаем как есть (удобно читать и грепать), остальное — JSON
    if len(runs) == 1 and (a.text or a.dom or a.sel) and not (a.check_overflow or a.eval or a.shot):
        payload = runs[0].get("text") or runs[0].get("dom") or "\n".join(runs[0].get("sel") or [])
        if a.out:
            pathlib.Path(a.out).write_text(payload, encoding="utf-8")
            print(f"[written] {a.out} ({len(payload)} символов)")
        else:
            print(payload)
        return 0

    if a.out and a.dom and len(runs) == 1 and runs[0].get("dom"):
        pathlib.Path(a.out).write_text(runs[0]["dom"], encoding="utf-8")
        runs[0]["dom"] = f"[written] {a.out}"
    print(json.dumps({"target": target, "runs": runs}, ensure_ascii=False, indent=2))
    return 0


def _shutdown(port: int, proc: subprocess.Popen):
    """Корректно погасить браузер: Browser.close, затем добить процесс."""
    try:
        ws_url = http_json(port, "/json/version").get("webSocketDebuggerUrl")
        if ws_url:
            asyncio.run(_ws_send(ws_url, "Browser.close", timeout=4))
    except Exception:
        pass
    for _ in range(25):
        if proc.poll() is not None:
            return
        time.sleep(0.2)
    proc.terminate()
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()


if __name__ == "__main__":
    sys.exit(main())
