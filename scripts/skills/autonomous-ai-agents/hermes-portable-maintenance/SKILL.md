---
name: hermes-portable-maintenance
description: "Use when wiping/reinstalling portable Hermes: backup."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [hermes, portable, backup, reinstall, windows, gitignore]
    related_skills: [memos-memory-management, hermes-agent]
---

# Hermes Portable Maintenance (Hermes-Portable-Scripts)

Maintenance of the portable Hermes installation on the user's machine: understanding the repo layout, checking wipe-readiness, and backing up before a full reinstall ("снос полигона").

## When to use
- User says they will wipe / reinstall `D:\NEURO\Hermes` ("сношу полигон") or test install scripts from scratch
- User asks what will be lost, or wants a backup before reinstall
- Need to locate a portable script (install/fix/patch) inside the repo
- Checking that the repo is ready to be cloned fresh (all scripts committed & pushed)

## Repo layout (portable install — important quirks)
- `D:\NEURO\Hermes` is the git repo `Hermes-Portable-Scripts` (origin: `https://github.com/MRafStudio/Hermes-Portable-Scripts`), branch `main`.
- **`data/` is the entire `$HERMES_HOME` and is fully `.gitignore`d** — nothing inside survives a wipe; `git clone` does NOT restore it.
- `scripts/*.bat` — user-facing launchers/installers (`Start.bat`, `InstallOrUpdate*.bat`, `Start-Llama-IfNeeded.bat`).
- `scripts/ps1/*.ps1` — installer/utility PowerShell (`hermes_install_portable.ps1`, `install_ffmpeg.ps1`, `patch_*.ps1`).
- **`scripts/ps1/*.ps1` — patch/activation scripts** (e.g. `install-memos.ps1`, `memos-fix.ps1`). Do NOT search only `scripts/ps1/` when looking for a ps1.
- `data/llm/models/` — shared GGUF model files (≈40 GB on this machine).

## Wipe-readiness check (run before telling the user "you're good to wipe")
```bash
cd /d/NEURO/Hermes
git status -sb                          # expect "## main...origin/main", clean tree
git log --oneline -5                    # last commits include the scripts in question
git ls-files | grep -i <script-name>    # confirm the script is actually tracked
```

## Backup checklist before full wipe (all inside gitignored `data/`)
| Path | Why it matters |
|---|---|
| `data/hermes/.env` | **All API keys** — without it providers won't work after reinstall |
| `data/hermes/auth.json` | OAuth tokens |
| `data/hermes/config.yaml` | Settings (scripts recreate a default, your tweaks are lost) |
| `data/hermes/memories/` | `USER.md` / `MEMORY.md` user profile |
| `data/hermes/state.db` | Session history (used by session_search) |
| `data/hermes/memos-plugin/data/memos.db` | MemOS memory (traces, policies) |
| `data/llm/models/` | 40 GB of models — do not delete, rename to `*.bak` instead of re-downloading |

## Procedure
1. Run the wipe-readiness check above; report clean state + last commits.
2. Show the backup table; ask the user where to back up (or propose renaming `data/llm` to `D:\NEURO\llm-models.bak`).
3. Copy `.env`, `auth.json`, `memories/`, `state.db`, `memos.db` to the chosen destination; verify sizes match (`ls -la` both sides).
4. Only after backup: user wipes; next step is `git clone <origin>` + run `InstallOrUpdate*.bat` scripts — they recreate structure and config, but NOT keys/models.

## Pitfalls
- NEVER read or print the contents of `.env` / `auth.json` — list names/sizes only (user's secrets).
- The portable repo is the git repo itself: don't go looking for a nested repo — `git status` at `D:\NEURO\Hermes` root is the one that matters.
- `sessions/` may show 0 files while `state.db` holds history — don't conclude "no sessions" from the dir alone.
- The MemOS activation scripts live in `scripts/ps1/`, not `scripts/ps1/`.

## Related
- `memos-memory-management` — MemOS plugin activation, verification, DB maintenance.
- `hermes-agent` (bundled) — general Hermes config & CLI reference.
