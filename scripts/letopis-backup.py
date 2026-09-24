#!/usr/bin/env python3
"""letopis-backup.py — ежедневно сохраняет базу разговоров Hermes и выгружает активные сессии.
Запуск: Планировщик (задача Hermes letopis backup), раз в сутки."""
import os, sqlite3, shutil, datetime, glob
DB = r"D:\NEURO\Hermes\data\hermes\state.db"
OUT = r"D:\NEURO\Hermes\durable\ЛЕТОПИСЬ"
KEEP = 14  # сколько копий базы храним

os.makedirs(OUT, exist_ok=True)
stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H%M")
dst = os.path.join(OUT, f"state-{stamp}.db")
try:
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.execute("VACUUM INTO ?", (dst,))
    con.close()
    print("backup ok:", dst, os.path.getsize(dst) // 1024 // 1024, "MB")
except Exception as e:
    print("backup error:", e)

# чистим старые копии
olds = sorted(glob.glob(os.path.join(OUT, "state-*.db")))
for f in olds[:-KEEP]:
    try: os.remove(f)
    except Exception: pass
