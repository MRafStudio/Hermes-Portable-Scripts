# memos.db maintenance (MemOS SQLite)

DB: `$HERMES_HOME/memos-plugin/data/memos.db` (WAL mode; `-wal`/`-shm` sidecars present while bridge runs).

## traces table schema (key columns, from PRAGMA table_info)
```
id                      TEXT    NOT NULL  -- 'tr_<12 hex>' uuid, NOT autoincrement
episode_id              TEXT    NOT NULL
session_id              TEXT    NOT NULL
owner_agent_kind        TEXT    NOT NULL  default 'unknown'
owner_profile_id        TEXT    NOT NULL  default 'default'
owner_workspace_id      TEXT
ts                      INTEGER NOT NULL  -- epoch ms
user_text               TEXT    NOT NULL
agent_text              TEXT    NOT NULL
summary                 TEXT
tool_calls_json         TEXT    NOT NULL  default '[]'
reflection              TEXT
agent_thinking          TEXT
value                   REAL    NOT NULL  default 0
alpha                   REAL    NOT NULL  default 0
r_human                 REAL
priority                REAL    NOT NULL  default 0
tags_json               TEXT    NOT NULL  default '[]'
error_signatures_json   TEXT    NOT NULL  default '[]'
vec_summary             BLOB
vec_action              BLOB
share_scope             TEXT    default 'private'
share_target            TEXT
shared_at               INTEGER
turn_id                 INTEGER NOT NULL
schema_version          INTEGER NOT NULL  default 1
```
Other tables: `sessions`, `episodes`, `policies`, `l2_candidate_pool`, `world_model`, `skills`, `kv`, `traces_fts` (FTS5 + trigram). `policies`/`world_model`/`skills` stay EMPTY while the plugin is disabled — they only fill when capture/crystallization runs.

## Clean junk traces (e.g. test spam "Запомни: любимый X — Y")
```python
import sqlite3
con = sqlite3.connect(r'D:\NEURO\Hermes\data\hermes\memos-plugin\data\memos.db')
cur = con.cursor()
n = cur.execute("DELETE FROM traces WHERE user_text LIKE 'Запомни: любим%'").rowcount
con.commit()          # ← WITHOUT commit the delete is rolled back on next failed op
print('deleted', n)
```
Real-world case: 500 test rows of `Запомни: любимый <вещь> — <значение>` (Telegram/Фудзи/плавание) polluted the DB; user asked to purge them.

## Insert a trace manually (facts the user asked to remember)
```python
import sqlite3, time, uuid
con = sqlite3.connect(r'D:\NEURO\Hermes\data\hermes\memos-plugin\data\memos.db')
cur = con.cursor()
tid = 'tr_' + uuid.uuid4().hex[:12]
ts = int(time.time() * 1000)
user_text = 'Запомни: ...'          # phrase it like a real user message so memos_search finds it
agent_text = 'OK, запомнил.'
cur.execute('''INSERT INTO traces
 (id, episode_id, session_id, owner_agent_kind, owner_profile_id, ts,
  user_text, agent_text, summary, tool_calls_json, value, alpha, priority,
  tags_json, error_signatures_json, turn_id, schema_version)
 VALUES (?, ?, ?, 'hermes', 'default', ?, ?, ?, ?, '[]', 1.0, 0.5, 3.0, '[]', '[]', 1, 1)''',
 (tid, 'ep_manual', 'manual', ts, user_text, agent_text, 'short summary'))
con.commit()
```

## Gotchas
- `SELECT MAX(id)` on TEXT ids is lexical — meaningless; order by `ts` (epoch ms) instead.
- IntegrityError "NOT NULL constraint failed: traces.X" = missing required column (see schema above).
- Cyrillic LIKE matching is exact — em-dash '—' differs from hyphen '-'; test the pattern with a COUNT first.
- `memos_search` hit shape: `{"tier": 2, "refId": "tr_...", "refKind": "trace", "snippet": "[user] Запомни: ..."}`.
- Viewer health check: `curl http://127.0.0.1:18800/` → HTTP 200 while bridge daemon runs.
