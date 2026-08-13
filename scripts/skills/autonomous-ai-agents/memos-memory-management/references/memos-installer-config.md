# MemOS installer config — target state & editing recipe

Repo: Hermes-Portable-Scripts (`D:\NEURO\Hermes`, origin github.com/MRafStudio/Hermes-Portable-Scripts).
MemOS installer files: `scripts/ps1/install-memos.ps1` (fresh install) + `scripts/ps1/memos-fix.ps1`
(fallback fixer, PATCHes live config via viewer API). Both must agree on the target config.

## Target config.yaml block (written by install-memos.ps1 step 4 at NEW installs)

```yaml
version: 1
viewer:
  port: 18800
embedding:
  provider: local
  apiKey: ***
  model: ${RuntimeHome}\models\all-MiniLM-L6-v2   # PS-interpolated at write time
llm:
  provider: local_only                            # NO forced LLM (user hard rule)
  endpoint: ""
  apiKey: ***
  model: ""
storage:
  ftsTokenizer: trigram
algorithm:
  lightweightMemory:
    enabled: true
  capture:
    embedTraces: true                             # semantic search ON per trace
  retrieval:
    llmFilterEnabled: false
    llmFilterMinCandidates: 50
hub:
  enabled: false
  address: ""
  teamToken: ""
telemetry:
  enabled: false
logging:
  level: info
  detailedView: false
```

Schema facts (dist/core/config/schema.js): `embedTraces` default is `true` (fixer had forced it
to `false` before 2026-08 — that killed semantic recall); `endpoint` defaults to `""`; supported
`llm.provider`: `local_only | openai_compatible | anthropic | gemini | bedrock | host`.

## Viewer API cheat sheet (port 18800, agent=hermes)

| Endpoint | Use |
|---|---|
| `GET /api/v1/health` | ok/version/uptime/llm status (JSON) |
| `GET /api/v1/memory/search?q=<pct-encoded>&agent=hermes&top=N` | keyword search; also POST variant with JSON `{query, agent, topK}` |
| `GET /api/v1/memory/trace?id=tr_...` | single trace |
| `GET/PATCH /api/v1/config` | read / merge-patch plugin config (fixer uses this) |
| `POST /api/v1/embeddings/rebuild` | mass backfill embeddings for traces written while `embedTraces=false` |

curl pitfall: raw Cyrillic in the query string silently returns empty — percent-encode
(`%D0%BF...`) or POST JSON. Multi-word `memos_search` is FTS5-ANDed → 0 hits; use one keyword.

## Editing workflow (validated 2026-08, commit 9af2584)

1. Edit `install-memos.ps1` step-4 here-string AND the matching PATCH rules in `memos-fix.ps1`
   (they must not contradict — fixer re-aligns live config to the same target).
2. Syntax-check both: `powershell -NoProfile -Command "$null=[scriptblock]::Create((Get-Content -Raw '<file>')); 'OK'"`
3. Run `python <skill>/scripts/verify_memos_installer.py <repo-root>` → expect ALL PASS, exit 0.
4. Commit with identity `Hermes Agent <agent@hermes.local>` (user repo has no git identity), push.
5. Never leave verification artifacts in the repo (`data/` is gitignored; temp scripts go to
   `D:\NEURO\Hermes\data\temp\hermes-verify-*.py` and are deleted after the run).

## Gotchas when verifying the PS1 YAML block

- PowerShell here-string: `@"` opener and `"@` closer each on its OWN line; extract with
  `re.findall(r'^[ \t]*@"\n(.*?)\n[ \t]*"@', text, re.S | re.M)` and take `blocks[-1]`.
- `apiKey: ***` is NOT strict YAML — `*` opens an alias → `yaml.safe_load` raises
  ScannerError. Mask first: `re.sub(r": \*+\s*$", ": masked", block, flags=re.M)`.
- To prove `${RuntimeHome}` interpolates, render the block in real PowerShell via
  `-EncodedCommand` (base64 UTF-16LE) — avoids bash quote mangling on Windows/git-bash.
- User preference: config changes ship via the installer scripts (commit+push), NOT by
  hand-editing the live `memos-plugin/config.yaml`. Do not apply target config to a running
  install unless the user explicitly asks.
