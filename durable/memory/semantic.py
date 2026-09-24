#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""semantic.py — смысловой поиск по моей памяти через локальный эмбеддер bge-m3.

Зачем: FTS5 ищет по СЛОВАМ («где пароли» не найдёт «креды в .env»),
а эмбеддер ищет по СМЫСЛУ (косинус между векторами).

  python semantic.py index [--all]     # посчитать векторы для записей (memory / raf)
  python semantic.py search "<запрос>" [N]   # смысловой поиск
  python semantic.py similar <id> [N]  # что ещё близко к записи
  python semantic.py stats
"""
import os, sys, json, sqlite3, urllib.request, time, math, struct, array, re

# numpy не обязателен: если есть — быстрее, если нет — считаем чистым Python.
# (в окружении Hermes pip заблокирован uv, поэтому зависимость делать нельзя)
try:
    import numpy as np
    HAVE_NUMPY = True
except Exception:
    np = None
    HAVE_NUMPY = False


def v_bytes(vec):
    """list[float] -> BLOB (float32)."""
    return array.array("f", vec).tobytes()


def v_load(blob):
    """BLOB -> list[float]."""
    a = array.array("f"); a.frombytes(blob); return list(a)


def v_norm(v):
    n = math.sqrt(sum(x * x for x in v)) or 1.0
    return [x / n for x in v]


def v_dot(a, b):
    s = 0.0
    for i in range(len(a)):
        s += a[i] * b[i]
    return s

HERE = os.path.dirname(os.path.abspath(__file__))
DB   = os.path.join(HERE, "hermes-memory.db")


def load_env():
    p = os.path.join(HERE, ".env")
    out = {}
    if os.path.exists(p):
        for line in open(p, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                out[k.strip()] = v.strip()
    return out

ENV = load_env()
API = ENV.get("EMBED_URL", "http://127.0.0.1:8083/v1/embeddings")
KEY = ENV.get("EMBED_KEY", "")
DIM = int(ENV.get("EMBED_DIM", "1024"))


def _one(text):
    """Один текст -> вектор. Обрезаем слишком длинные (контекст bge-m3 = 8192)."""
    t = (text or " ").strip()[:6000] or " "
    body = json.dumps({"input": [t]}).encode()
    hdr = {"Content-Type": "application/json"}
    if KEY:
        hdr["Authorization"] = "Bearer " + KEY
    req = urllib.request.Request(API, data=body, headers=hdr)
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.load(r)["data"][0]["embedding"]



SECRET_PATTERNS = [
    re.compile(r"(парол\w*\s*[:=]?\s*)([^\s,;.]+)", re.I),
    re.compile(r"(password\s*[:=]?\s*)([^\s,;.]+)", re.I),
    re.compile(r"([a-zA-Z0-9!@#$%^&*_+\-]{24,})"),   # длинные токены/хэши
]

def mask_secrets(text):
    """Секреты в вывод не попадают: пароли/токены маскируются."""
    t = str(text)
    for pat in SECRET_PATTERNS:
        def rep(m):
            if m.re.groups >= 2:
                return m.group(1) + "*" * min(len(m.group(2)), 12)
            return "***СЕКРЕТ***"
        t = pat.sub(rep, t)
    return t

def embed(texts, tries=2):
    """Тексты -> список векторов. Батчем; при сбое — по одному (один плохой текст не рушит пачку)."""
    texts = [t if t and t.strip() else " " for t in texts]
    body = json.dumps({"input": texts}).encode()
    hdr = {"Content-Type": "application/json"}
    if KEY:
        hdr["Authorization"] = "Bearer " + KEY
    for i in range(tries):
        try:
            req = urllib.request.Request(API, data=body, headers=hdr)
            with urllib.request.urlopen(req, timeout=300) as r:
                return [d["embedding"] for d in json.load(r)["data"]]
        except Exception:
            if i == tries - 1:
                # поштучно: проблемный текст не уронирует весь батч
                out = []
                for t in texts:
                    try:
                        out.append(_one(t))
                    except Exception:
                        out.append([0.0] * DIM)   # заглушка: пропускаем текст, индексация продолжается
                return out
            time.sleep(3)


def con():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    return c


def init():
    c = con()
    c.executescript("""
    CREATE TABLE IF NOT EXISTS vectors (
      src    TEXT NOT NULL,     -- 'memory' | 'raf'
      row_id INTEGER NOT NULL,
      vec    BLOB NOT NULL,
      text   TEXT NOT NULL,
      PRIMARY KEY (src, row_id)
    );
    CREATE INDEX IF NOT EXISTS idx_vectors_src ON vectors(src);
    """)
    c.commit(); return c


def rows_to_index(c, src):
    """Какие строки источника ещё не векторизованы."""
    if src == "memory":
        have = {r[0] for r in c.execute("SELECT row_id FROM vectors WHERE src='memory'")}
        allr = c.execute("SELECT id AS rid, topic || '. ' || body AS txt FROM memory").fetchall()
    else:  # raf
        have = {r[0] for r in c.execute("SELECT row_id FROM vectors WHERE src='raf'")}
        allr = c.execute("SELECT id AS rid, body AS txt FROM raf").fetchall()
    return [(r["rid"], r["txt"]) for r in allr if r["rid"] not in have]


def index(src="memory", batch=32, limit=None, verbose=True):
    c = init()
    todo = rows_to_index(c, src)
    if limit: todo = todo[:limit]
    total = len(todo)
    if not total:
        if verbose: print(f"  [{src}] всё уже векторизовано")
        return 0
    done = 0
    for i in range(0, total, batch):
        chunk = todo[i:i+batch]
        vecs = embed([t for _, t in chunk])
        for (rid, txt), v in zip(chunk, vecs):
            blob = v_bytes(v)
            c.execute("INSERT OR REPLACE INTO vectors (src, row_id, vec, text) VALUES (?,?,?,?)",
                      (src, rid, blob, txt[:4000]))
        c.commit()
        done += len(chunk)
        if verbose and (done % 320 == 0 or done == total):
            print(f"  [{src}] {done}/{total}")
    return done


def all_vecs(c, src=None):
    q = "SELECT src, row_id, vec, text FROM vectors"
    p = ()
    if src:
        q += " WHERE src = ?"; p = (src,)
    rows = c.execute(q, p).fetchall()
    if not rows:
        return [], None, []
    if HAVE_NUMPY:
        M = np.vstack([np.frombuffer(r["vec"], dtype=np.float32) for r in rows])
        M = M / np.linalg.norm(M, axis=1, keepdims=True)   # нормируем: косинус = скалярное
    else:
        M = [v_norm(v_load(r["vec"])) for r in rows]
    return rows, M, [(r["src"], r["row_id"]) for r in rows]


def search(query, n=10, src=None):
    c = con()
    rows, M, keys = all_vecs(c, src)
    if M is None:
        print("  нет векторов — сначала `python semantic.py index --all`")
        return []
    q = embed([query])[0]
    if HAVE_NUMPY:
        q = q / np.linalg.norm(q)
        sims = list(M @ q)
    else:
        q = v_norm(list(q))
        sims = [v_dot(m, q) for m in M]
    order = sorted(range(len(sims)), key=lambda i: -sims[i])[:n]
    out = []
    for i in order:
        r = rows[i]
        out.append({"score": float(sims[i]), "src": rows[i]["src"], "row_id": rows[i]["row_id"], "text": rows[i]["text"]})
    return out


def main():
    a = sys.argv[1:] or ["stats"]
    init()  # таблица векторов должна существовать всегда
    if a[0] == "index":
        if "--all" in a:
            n1 = index("memory"); n2 = index("raf")
            print(f"  всего векторизовано: memory={n1}, raf={n2}")
        else:
            src = a[1] if len(a) > 1 else "memory"
            index(src)
    elif a[0] == "search" and len(a) > 1:
        n = int(a[2]) if len(a) > 2 else 8
        res = search(" ".join(a[1:]) if len(a) != 3 else a[1], n)
        print(f"=== смысловой поиск: «{a[1]}» ===")
        for r in res:
            print(f"\n  [{r['src']}:{r['row_id']}] косинус={r['score']:.4f}")
            print("    " + mask_secrets(r["text"][:230]).replace("\n", " "))
    elif a[0] == "similar" and len(a) > 1:
        rid = int(a[1]); n = int(a[2]) if len(a) > 2 else 5
        c = con()
        row = c.execute("SELECT vec, text FROM vectors WHERE src='memory' AND row_id=?", (rid,)).fetchone()
        if not row:
            print("  нет такой записи"); return
        v = np.frombuffer(row["vec"], dtype=np.float32) if HAVE_NUMPY else v_norm(v_load(row["vec"]))
        if HAVE_NUMPY: v = v / np.linalg.norm(v)
        rows, M, _ = all_vecs(c)
        sims = list(M @ v) if HAVE_NUMPY else [v_dot(m, list(v)) for m in M]
        order = sorted(range(len(sims)), key=lambda i: -sims[i])[1:n+1]
        print(f"=== близко к записи {rid}: {mask_secrets(row['text'][:80])}… ===")
        for i in order:
            print(f"  косинус={sims[i]:.4f} | {mask_secrets(rows[i]['text'][:120])}")
    elif a[0] == "stats":
        c = con()
        for src in ("memory", "raf"):
            tot = c.execute({"memory": "SELECT COUNT(*) FROM memory", "raf": "SELECT COUNT(*) FROM raf"}[src]).fetchone()[0]
            vec = c.execute("SELECT COUNT(*) FROM vectors WHERE src=?", (src,)).fetchone()[0]
            print(f"  {src:<8} всего={tot:<6} векторов={vec}")
        print(f"  эмбеддер: {API} | размерность {DIM}")
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
