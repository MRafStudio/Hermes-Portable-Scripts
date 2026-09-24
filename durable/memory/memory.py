#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""hermes-memory — моя долговременная память (суть + нить).

  python memory.py add <kind> "<тема>" "<текст>" [вес]
      kind: lesson | decision | fact | person | idea
  python memory.py find "<запрос>"        # полнотекстовый поиск
  python memory.py list [N]               # последние N
  python memory.py chat "<запрос>"        # поиск по ВСЕЙ истории разговоров (state.db)
"""
import os, sys, sqlite3

DB   = os.path.join(os.path.dirname(os.path.abspath(__file__)), "hermes-memory.db")
CHAT = r"D:\NEURO\Hermes\data\hermes\state.db"


def con(db=DB):
    c = sqlite3.connect(db)
    c.row_factory = sqlite3.Row
    return c


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__); return

    if a[0] == "add" and len(a) >= 4:
        kind, topic, body = a[1], a[2], a[3]
        w = int(a[4]) if len(a) > 4 else 5
        c = con()
        c.execute("INSERT INTO memory (kind, topic, body, source, weight) VALUES (?,?,?,?,?)",
                  (kind, topic, body, "agent", w))
        c.commit(); print("записано:", topic)
        return

    if a[0] == "find" and len(a) > 1:
        c = con()
        q = " ".join(a[1:])
        for r in c.execute("SELECT m.topic, m.kind, m.body FROM memory m "
                           "JOIN memory_fts f ON f.rowid = m.id "
                           "WHERE memory_fts MATCH ? ORDER BY m.weight DESC LIMIT 20", (q,)):
            print(f"[{r['kind']}] {r['topic']}\n    {r['body'][:300]}")
        return

    if a[0] == "list":
        n = int(a[1]) if len(a) > 1 else 20
        c = con()
        for r in c.execute("SELECT created, kind, topic, weight FROM memory "
                           "ORDER BY weight DESC, id DESC LIMIT ?", (n,)):
            print(f"  {r['created'][:10]} [{r['kind']:<8}] w{r['weight']} {r['topic']}")
        return

    if a[0] == "chat" and len(a) > 1:
        q = " ".join(a[1:])
        c = con(CHAT)
        print(f"=== история разговоров: «{q}» ===")
        rows = c.execute("""SELECT m.timestamp, m.role, substr(m.content,1,220) AS txt
                            FROM messages m WHERE m.id IN
                            (SELECT rowid FROM messages_fts WHERE messages_fts MATCH ? LIMIT 20)
                            ORDER BY m.timestamp DESC""", (q,)).fetchall()
        import datetime
        for r in rows:
            try: ts = datetime.datetime.fromtimestamp(float(r["timestamp"])).strftime("%d.%m %H:%M")
            except Exception: ts = str(r["timestamp"])[:16]
            print(f"\n  [{ts}] {r['role']}: {str(r['txt']).replace(chr(10),' ')[:200]}")
        print(f"\nвсего найдено (ограничено 20): {len(rows)}")
        return

    print(__doc__)


if __name__ == "__main__":
    main()
