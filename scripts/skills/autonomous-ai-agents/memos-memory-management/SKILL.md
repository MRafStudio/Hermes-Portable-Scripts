---
name: memos-memory-management
description: "Use when MemOS memory is broken, disabled, or needs work."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [memos, memtensor, memory, hermes, plugin, sqlite, troubleshooting]
    related_skills: [hermes-agent]
---

# MemOS (memtensor) Memory Management

Manage, activate, troubleshoot, and maintain the MemOS local memory plugin for Hermes Agent (plugin `memtensor`, a.k.a. memos-local-plugin / MemOS Local — Reflect2Evolve V7).

## When to use
- `memory` tool returns "Memory is not available. It may be disabled in config or this environment."
- `memos_search` / `memos_*` tools return empty or fail
- `hermes plugins list` shows `memtensor` as `not enabled`
- User asks "does memory work?" or wants MemOS cleaned/maintained
- Installing or updating MemOS via a portable installer (e.g. Hermes-Portable-Scripts)

## Architecture — two SEPARATE memory systems (do not confuse)
1. **MemOS / memtensor plugin** — Node.js bridge + SQLite DB at `$HERMES_HOME/memos-plugin/data/memos.db`, viewer at `http://127.0.0.1:18800`. Exposes its own tools: `memos_search`, `memos_get`, `memos_timeline`, `memos_environment`, `memos_skill_list`, `memos_skill_get`. Writes L1/L2/L3 traces automatically every turn.
2. **`memory` tool** — Hermes' built-in file-backed memory: `$HERMES_HOME/memories/USER.md` + `MEMORY.md` (compact user profile / notes). It is NOT the same store as MemOS and does not cross-write into memos.db. "Entry added" from `memory` tool does NOT mean the fact is searchable via `memos_search`.

## Activation sequence (idempotent, official CLI only)
NEVER hand-edit `config.yaml` (user's hard rule). Use:
```powershell
hermes plugins enable memtensor                       # activate plugin
hermes config set memory.provider memtensor           # memory provider
hermes config set memory.memory_enabled true
hermes config set memory.user_profile_enabled true
```
Idempotent status checks:
```powershell
hermes plugins list --json   # parse JSON, check name=memtensor, status=enabled
hermes config get memory.memory_enabled               # expect "true"
# faster: `hermes config get memory` prints the whole block at once
# (memory_enabled, user_profile_enabled, provider, char limits)
```

## Critical caveats
- **Plugin takes effect on the NEXT session.** After `plugins enable`, the current session still reports "Memory is not available" and `memory` tool falls back to file memory. Tell the user to `/reset` or restart the chat.
- `memory_enabled=false` + `user_profile_enabled=false` is the DEFAULT Hermes config — installers often forget to flip them. Symptom: `memory` tool fails while memos.db is actively being written.
- The portable installer (Hermes-Portable-Scripts `install-memos.ps1`) historically set only `memory.provider` — it did NOT enable the plugin or the memory flags. After any MemOS install, verify all three: plugin enabled, memory_enabled=true, user_profile_enabled=true. The fix belongs in the installer itself (`plugins enable` + `config set` with idempotent checks via `plugins list --json`).
- `capture.embedTraces: false` in `memos-plugin/config.yaml` (default in some installs) → keyword-only search, no semantic/vector recall. Flip to `true` if the user expects "find by meaning"; also confirm `llm.model` is set (empty model = `llm_filter.failed` warnings; harmless in lightweight mode, blocks crystallization into policies/world_model).

## Multi-modal reality check: images do NOT go into local MemOS
- Local plugin (SQLite, Hermes) stores TEXT ONLY — user/agent messages, tool traces (L1), and crystallized L2/L3 when LLM is enabled. Image files, attachments, screenshots are NEVER stored in memos.db. `memos_search` (FTS5) can therefore never return or restore a picture — only text that happened to mention it.
- Cloud / self-hosted MemOS (Neo4j+Qdrant) is different: `src/memos/mem_reader/read_multi_modal/image_parser.py` handles `image_url` content parts — stores the URL in `SourceMessage.image_info` and (fine mode) runs LLM image analysis. Still stores URL/description, not the pixel file.
- Where user screenshots DO live: Hermes desktop composer images at `D:\NEURO\Hermes\data\home\AppData\Roaming\Hermes\composer-images\composer_*.png` (path seen in the user's `@image:` attachment). To "restore what was on that screenshot": read the file from disk with `vision_analyze`, or open it in the browser (`file:///` + `browser_vision`) and share via MEDIA:<path> — NOT via memos_search.
- `browser_vision` screenshot fallback also lands on disk: `$HERMES_HOME/cache/screenshots/browser_screenshot_*.png` — shareable via MEDIA even when the vision LLM fails.
- Vision-model descriptions are NOT trustworthy for UI identification: a weak/fallback vision model once described the Hermes desktop session list as "Discord" (user: "в Discord мы не лазили"). When identifying an app/UI from a screenshot, cross-check against known context (file path, composer-images, app the user actually uses) before asserting.

## Search & crystallization gotchas (learned on 2026-08)
- `memos_search` with MULTI-WORD queries returns 0 hits even when each word exists in traces — FTS5 AND semantics (all words in one doc). Use 1-2 key words, not phrases. Not a bug.
- `capture.embedTraces: false` (set by old memos-fix.ps1) → keyword/FTS search still works, but vector (semantic) search over traces is empty. Target config: `embedTraces: true` + local all-MiniLM-L6-v2. Old traces written while false get embeddings via `POST /api/v1/embeddings/rebuild`.
- Crystallization (policies/world_model/skills tables = 0) is EXPECTED with `llm.provider: local_only` — LLM-dependent stages (reflection, L2 induce, skill crystallize) are skipped. User's hard rule: do NOT force an LLM provider into memos-plugin/config.yaml. If user later wants crystallization: set provider via viewer :18800 Config (openai_compatible + external endpoint like deepseek, or `host` = LLM through Hermes itself via host.llm.complete, no keys needed). Local kobold is too slow for this.
- Supported `llm.provider` values: `local_only | openai_compatible | anthropic | gemini | bedrock | host`. `host` requires the Python adapter to have registered `host.llm.complete` on the bridge (done at Hermes session start); daemon/viewer process alone has NO host bridge → LLM client is nulled (harmless: capture/search keep working).
- install-memos.ps1 / memos-fix.ps1 (scripts/patch/) target config: embedTraces=true, llm=local_only, llmFilterEnabled=false, llmFilterMinCandidates=50, embedding.model=local all-MiniLM-L6-v2, lightweightMemory=true.
- MemOS config changes belong in the INSTALLER scripts, NOT applied live: user insists fixes ship via scripts/patch/install-memos.ps1 + memos-fix.ps1 (commit + push to Hermes-Portable-Scripts), never by hand-patching the running memos-plugin/config.yaml ("это нужно чтобы производилось в процессе установки MemOS! А не вот сейчас"). If the live install diverges, that's fine — it realigns on the next install/fix run.
- Hard user rule: NEVER force an llm.provider into memos-plugin config for crystallization ("Насильно llm не надо впихивать для кристаллизации!!!"). Keep `local_only`; if the user later wants L2/L3 crystallization, THEY enable it themselves via viewer Config. Local kobold is too slow to suggest for this.
- Quick viewer-API checks (no memos_search tool needed): `GET /api/v1/health` (JSON: ok/version/llm status), `GET /api/v1/memory/search?q=<percent-encoded>&agent=hermes&top=5` (hits), `GET/PATCH /api/v1/config` (fixer uses PATCH for settings), `POST /api/v1/embeddings/rebuild` (mass backfill of embeddings for old traces). curl pitfall: RAW Cyrillic in the query string returns an empty body — percent-encode it or use POST with a JSON body.
- Editing install-memos.ps1 / memos-fix.ps1: verify with `scripts/verify_memos_installer.py <repo-root>` (PASS/FAIL, exit 0) and see `references/memos-installer-config.md` for the target config block, here-string extraction regex, and the `apiKey: ***` YAML-alias gotcha.

## Verification
- `memos_search` with a known fact → expect a trace hit. Use ONE keyword — multi-word queries are FTS-ANDed and return zero hits even when each word exists separately.
- `curl http://127.0.0.1:18800/` → HTTP 200 (bridge alive). Search via viewer API: `curl -s "http://127.0.0.1:18800/api/v1/memory/search?q=<percent-encoded>&agent=hermes&top=5"` — Cyrillic MUST be percent-encoded (raw UTF-8 in query string silently yields zero hits).
- `memory` tool add → "Entry added".
- After fixing repo scripts: write a throwaway verification script under `D:\NEURO\Hermes\data\temp` named `hermes-verify-*.py`, run it (print PASS/FAIL per check + exit code), then DELETE it and confirm `git status` is clean. Never leave verification artifacts in the repo.

## DB maintenance
See `references/memos-db-maintenance.md` for the memos.db schema (traces table, TEXT ids, NOT NULL columns), junk-trace cleanup SQL, and manual trace insertion recipe.

## Pitfalls
- **MemOS 2.0.27 requires `transformers`** — `from memos import MOS` fails with `ModuleNotFoundError: No module named 'transformers'` if the package is not installed. Before running any MemOS Python code, ensure the project venv has `transformers` (and other dependencies) installed via `poetry install` or `pip install transformers`.
- **MemOS API is independent of Python install** — you can verify MemOS functionality via HTTP calls to the FastAPI service (`http://<host>:<port>/docs`) without installing Python dependencies. Useful for quick health checks.
- **MemOS stores only TEXT traces** — images/files are not saved. Cloud/self-hosted MemOS via ImageParser stores only URL + LLM description, not the file itself.
- **MemOS CoT (PRO_MODE)**: complex queries are decomposed into sub-questions via LLM, searched in parallel (`ContextThreadPoolExecutor`, up to 10 workers), then synthesized. Falls back to standard chat if LLM response is not valid JSON.
- `traces.id` is TEXT (`tr_...`), NOT an auto-increment integer. `SELECT MAX(id)` returns a string (lexical, meaningless).
- Manual trace INSERT fails with NOT NULL constraint errors unless you supply ALL required columns: id, episode_id, session_id, ts, user_text, agent_text, tool_calls_json, value, alpha, priority, tags_json, error_signatures_json, turn_id, schema_version.
- SQLite deletes are rolled back unless `con.commit()` runs — a failed INSERT after DELETEs silently undoes the deletes.
- MSYS/git-bash mangles `/d/...` args passed to python — use `D:/...` or backslash Windows paths.
- `memos_search` empty ≠ broken memory: it often means the plugin was disabled (no crystallization) while traces were still being written.
- **SQLite access via `python -c` on Windows fails with "unable to open database file"** — the Hermes venv's python.exe cannot open `memos.db` directly. Use `execute_code` tool (which runs in a proper sandbox) or `python` from the venv with `D:/...` forward-slash paths. Never use `python3` on Windows (not installed).
- **Diagnosing MemOS health**: the DB file exists and is accessible, but the HTTP viewer API on port 18800 may return "Not Found" (404) instead of health — this is normal for some MemOS versions. The real health indicator is: (1) `memos_search` returns hits, (2) traces are being written (check `traces` table row count), (3) FTS index is populated. If all three, MemOS is working even if the viewer API is unreachable.
- **API logs table schema**: `api_logs` has columns `called_at` (not `timestamp`), `success` (INTEGER 0/1), `duration_ms`, `tool_name`, `input_json`, `output_json`. Use `called_at` for ordering, not `timestamp`.
- Before wiping/reinstalling Hermes-Portable (`D:\NEURO\Hermes`): `data/` is gitignored, so `memos.db`, `.env` (API keys), `auth.json`, `state.db`, `memories/` and `data/kobold/` (≈39 GB models) are ALL lost with the wipe — back them up first. Full checklist: skill `hermes-portable-maintenance`.

## Related
- `hermes-agent` (bundled) — Hermes config & CLI reference.
- `hermes-portable-maintenance` — wipe-readiness check & backup checklist for the portable install (data/ is gitignored).
