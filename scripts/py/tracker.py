#!/usr/bin/env python3
"""Чтение трекера UCS (tracker.ucs.ru, Redmine) по API-ключу из .env профиля.

Запуск::

    tracker.py search "XML-интерфейс" [--limit 10]
    tracker.py issue 214215 [--raw]
    tracker.py raw "/issues.json?project_id=-helpdesk-&status_id=*&limit=5"

Только чтение - и это ЖЁСТКОЕ правило скилла: на портал ничего не пишется (ни комментариев,
ни новых вопросов, ни смены полей). Все запросы - `GET`-подобные через `urllib`; ключ берётся
из ``TRACKER_UCS_KEY``. Единственный `POST` во всём скилле живёт в ``scripts/login.py`` и нужен
исключительно для входа, а не для правки данных.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import ssl
import urllib.error
import urllib.parse
import urllib.request

ENV = pathlib.Path("D:/NEURO/Hermes/data/hermes/.env")


def env(key: str) -> str:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.startswith(key + "="):
            return line.split("=", 1)[1].strip()
    raise SystemExit(f"нет {key} в .env")


BASE = env("TRACKER_UCS_URL").rstrip("/")
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE


def api(path: str, key: str | None = None) -> dict:
    key = key or env("TRACKER_UCS_KEY")
    url = BASE + path + (("&" if "?" in path else "?") + "key=" + urllib.parse.quote(key))
    req = urllib.request.Request(url, method="GET", headers={"User-Agent": "Mozilla/5.0",
                                                           "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60, context=CTX) as r:
            return json.loads(r.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:300] if e.fp else ""
        raise SystemExit(f"HTTP {e.code} на {path}: {body}")


def cmd_search(query: str, limit: int) -> None:
    d = api("/search.json?q=" + urllib.parse.quote(query) + f"&limit={limit}")
    print(f"найдено: {d.get('total_count')}")
    for r_ in d.get("results") or []:
        print(f"  [{r_.get('type')}] {r_.get('title')}")
        print(f"      {r_.get('url')}")


def cmd_issue(iid: str, raw: bool) -> None:
    d = api(f"/issues/{iid}.json?include=journals,attachments,relations,children")
    if raw:
        print(json.dumps(d, ensure_ascii=False, indent=1))
        return
    i = d["issue"]
    print(f"#{i['id']} [{i['project']['name']}] {i['subject']}")
    print(f"трекер: {i['tracker']['name']} | статус: {i['status']['name']} | приоритет: {i['priority']['name']}")
    print(f"автор: {(i.get('author') or {}).get('name')} | назначен: {(i.get('assigned_to') or {}).get('name')}")
    print(f"создан: {i.get('created_on')} | обновлён: {i.get('updated_on')}")
    for c in i.get("custom_fields") or []:
        if c.get("value"):
            print(f"  {c['name']}: {str(c['value'])[:80]}")
    print("\n--- описание ---\n" + (i.get("description") or "(пусто)"))
    jr = i.get("journals") or []
    print(f"\n--- журнал: {len(jr)} записей ---")
    for j in jr:
        if j.get("notes"):
            print(f"* {j.get('created_on')} {(j.get('user') or {}).get('name')}:")
            for line in j["notes"].splitlines()[:14]:
                print("   " + line)
    for a in i.get("attachments") or []:
        print(f"вложение: {a['filename']} ({a['filesize']} байт) {a['content_url']}")


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("search")
    s.add_argument("query")
    s.add_argument("--limit", type=int, default=10)
    i = sub.add_parser("issue")
    i.add_argument("id")
    i.add_argument("--raw", action="store_true")
    r = sub.add_parser("raw")
    r.add_argument("path")
    args = ap.parse_args()

    if args.cmd == "search":
        cmd_search(args.query, args.limit)
    elif args.cmd == "issue":
        cmd_issue(args.id, args.raw)
    else:
        print(json.dumps(api(args.path), ensure_ascii=False, indent=1)[:20000])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
