---
name: memos-memory-diagnosis
description: "Use when MemOS memory is unavailable: diagnose it."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [memos, memory, memtensor, plugin, sqlite, diagnosis, troubleshooting, config]
    related_skills: [hermes-agent, memory-not-available]
---

# MemOS Memory Diagnosis

Diagnose and fix "memory unavailable / memory empty" reports in Hermes. Verified end-to-end on a Windows host with the memtensor (MemOS Local, Reflect2Evolve V7) plugin.

## When to Use

- `memory` tool fails with "Memory is not available" (built-in Hermes memory).
- `memos_search` / `memos_get` return zero hits or empty results.
- User asks why the agent "doesn't remember" preferences across sessions.
- User reports memory flags are off or the memtensor plugin is disabled.

## Key insight: MemOS runs independently of core memory

- `memory.*` config flags (Hermes core memory) and the `memtensor` plugin (MemOS) are **separate switches**. Both must be on for full memory UX.
- The MemOS plugin **keeps writing traces even while disabled** — a "nothing found" search result does NOT mean the DB is empty. Always inspect the SQLite DB before concluding data loss.
- Plugin changes take effect **on the next session** (`/reset` or new chat), never mid-conversation (prompt caching invariant).

## Diagnosis workflow

1. **Check core memory config** (Hermes built-in memory):
   ```bash
   hermes config get memory.memory_enabled
   hermes config get memory.user_profile_enabled
   ```
   If either is `false`, enable:
   ```bash
   hermes config set memory.memory_enabled true
   hermes config set memory.user_profile_enabled true
   ```

2. **Check the MemOS plugin status** — command is `plugins` (plural):
   ```bash
   hermes plugins list | grep -i memtensor
   ```
   Status must be `enabled`. If `not enabled`:
   ```bash
   hermes plugins enable memtensor
   ```
   (It will ask about tool overrides — declining is fine for memory-only use.)

3. **Check plugin config** (`$HERMES_HOME/memos-plugin/config.yaml`):
   - `embedding.provider: local` + `embedding.model` must point to a local model dir (e.g. `all-MiniLM-L6-v2`).
   - `algorithm.lightweightMemory.enabled: true`.
   - `algorithm.capture.embedTraces: true` = semantic (vector) search ON; `false` = keyword-only FTS (search still works, just no meaning-based recall). Old traces written while `false` can be backfilled via `POST /api/v1/embeddings/rebuild`.
   - `llm.provider: local_only` with empty `endpoint` is the user's INTENDED autonomous state (no forced LLM) — NOT a misconfiguration. Crystallization into `policies`/`world_model` requires an LLM and will simply not run until the user enables one themselves via viewer Config (e.g. `openai_compatible` + external endpoint, or `host` = LLM through Hermes). Do not "fix" this by forcing a provider.

4. **Inspect the MemOS database** — run the probe script:
   ```bash
   python <skill_dir>/scripts/inspect_memos_db.py
   ```
   Healthy DB: `sessions`/`episodes`/`traces` populated (hundreds), FTS tables present. `policies`/`world_model`/`skills` may legitimately be empty when the plugin was disabled (crystallization never ran) — they fill in once the plugin is enabled in a live session.

5. **Probe search independently of the tools** — the HTTP viewer exposes the same search core, so it isolates "tool broken" from "search broken":
   ```bash
   curl -s "http://127.0.0.1:18800/api/v1/memory/search?q=<PERCENT-ENCODED>&agent=hermes&top=5"
   ```
   Other viewer endpoints: `GET /api/v1/health` (version, namespace, paths, llm status incl. `lastError`), `GET /api/v1/memory/trace|policy|world?id=...`. NOTE: the JSON-RPC bridge (`memory.search` etc.) is **stdio-based**; :18800 is only the viewer/web API. ALWAYS percent-encode Cyrillic in `q` — raw UTF-8 in the query string silently returns zero hits (false negative). Also try the same query via SQLite FTS to separate encoding from indexing issues:
   ```bash
   python -c "import sqlite3;c=sqlite3.connect(r'D:/NEURO/Hermes/data/hermes/memos-plugin/data/memos.db');print(c.execute(\"SELECT count(*) FROM traces_fts WHERE traces_fts MATCH ?\",('привет',)).fetchone()[0])"
   ```

6. **Tell the user to restart the session** (`/reset` or new chat) — only then do plugin + memory flags take effect.

## Pitfalls

- `hermes plugin list` (singular) is NOT a valid command — it's `hermes plugins list`. Wrong form dumps the CLI usage error.
- The `traces` table has NO `content` column (unlike naive expectation): user/agent text lives in `user_text` / `agent_text`, plus `summary`, `agent_thinking`, `tool_calls_json`.
- A live SQLite DB shows `-wal` / `-shm` sidecar files — their presence means the plugin is actively writing, not that it is enabled.
- Don't trust `memos_search` hitting zero results as evidence of an empty store; query the DB directly first.
- **Multi-word `memos_search` queries return zero hits by design** — FTS5 ANDs the terms (all must appear in one trace). "GitHub токен настройка" → 0, "GitHub" → hit. Search with 1–2 keywords, never full sentences.
- `capture.embedTraces: false` in plugin config (default in some installs) disables semantic/vector search — only exact-keyword FTS matches work. If the user expects "find by meaning", this flag is the culprit, not the plugin.
- Few traces (e.g. 27) right after a fresh activation is normal: traces are only written from the moment the plugin is enabled, and all rows share the activation date. Not data loss.
- `llm.model` empty + `provider: local_only` → `llm_filter.failed` warnings in daemon log; harmless while `algorithm.lightweightMemory.enabled: true` (LLM stages are skipped), but blocks reflection/crystallization into `policies`/`world_model`.
- If the user later complains the built-in `memory` tool fails ("Memory is not available"): same root causes — `memory_enabled: false` or plugin disabled. Both fixes above apply.

## Support files

- `scripts/inspect_memos_db.py` — row-count summary + last-N traces from the memos SQLite DB (run with any python3).
- Schema detail for tables/columns lives inside the script header comments.
