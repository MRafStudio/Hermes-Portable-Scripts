#!/usr/bin/env python3
"""
Inspect the MemOS (memtensor) SQLite database: table row counts + last N traces.

Usage:
    python inspect_memos_db.py [path/to/memos.db] [N]

Defaults:
    DB path: $HERMES_HOME/memos-plugin/data/memos.db  (falls back to ~/.hermes/...)
    N: 8 (number of recent traces to print)

MemOS schema cheat-sheet (verified against memtensor 2.0.14 / Reflect2Evolve V7):
  sessions  (id, agent, owner_agent_kind, owner_profile_id, owner_workspace_id,
             started_at, last_seen_at, meta_json)
  episodes  (per-session episode records)
  traces    (id, episode_id, session_id, owner_*, ts, user_text, agent_text,
             summary, tool_calls_json, reflection, agent_thinking, value, alpha,
             r_human, priority, tags_json, error_signatures_json, vec_summary,
             vec_action, share_*, turn_id, schema_version)
             NOTE: there is NO 'content' column - text lives in user_text/agent_text.
  policies / l2_candidate_pool / world_model / skills / feedback
             - knowledge tables; may be legitimately EMPTY when the plugin was
               disabled (crystallization never ran). They fill in once enabled.
  *_fts      FTS5 search indexes (traces_fts, policies_fts, ...)
  kv         key-value store

Interpreting the output:
  - sessions/episodes/traces in the hundreds = plugin HAS been capturing data
    (even while disabled) - "memory is empty" is then a config/plugin issue, not data loss.
  - Live DB shows memos.db-wal / memos.db-shm sidecars = plugin actively writing.
"""
import os
import sqlite3
import sys


def find_db():
    if len(sys.argv) > 1:
        return sys.argv[1]
    home = os.environ.get("HERMES_HOME") or os.path.join(
        os.path.expanduser("~"), ".hermes"
    )
    cand = os.path.join(home, "memos-plugin", "data", "memos.db")
    if os.path.exists(cand):
        return cand
    raise SystemExit(f"memos.db not found at {cand}; pass the path explicitly")


def main():
    db = find_db()
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 8
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    cur = con.cursor()

    tables = [
        r[0]
        for r in cur.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        ).fetchall()
    ]
    print(f"DB: {db}")
    print(f"Tables ({len(tables)}):")
    for t in tables:
        try:
            cnt = cur.execute(f'SELECT COUNT(*) FROM "{t}"').fetchone()[0]
            print(f"  {t}: {cnt}")
        except sqlite3.Error as e:
            print(f"  {t}: ERROR {e}")

    print(f"\nLast {n} traces:")
    try:
        rows = cur.execute(
            "SELECT ts, substr(user_text,1,120), substr(agent_text,1,120) "
            "FROM traces ORDER BY ts DESC LIMIT ?",
            (n,),
        ).fetchall()
        for ts, ut, at in rows:
            print(f"--- [{ts}] USER: {ut}")
            if at:
                print(f"    AGENT: {at}")
    except sqlite3.Error as e:
        print(f"  ERROR reading traces: {e}")
    con.close()


if __name__ == "__main__":
    main()
