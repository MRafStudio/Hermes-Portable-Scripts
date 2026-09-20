---
name: hermes-portable-maintenance
description: "Use when wiping/reinstalling portable Hermes: backup."
version: 1.1.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [hermes, portable, backup, reinstall, windows, gitignore, installer, uv, npm]
    related_skills: [memos-memory-management, hermes-agent]
---

# Hermes Portable Maintenance (Hermes-Portable-Scripts)

Maintenance of the portable Hermes installation on the user's machine: repo layout, wipe-readiness, backups before a full reinstall ("снос полигона"), and diagnosing the installer's silent failures.

## When to use
- User will wipe / reinstall `D:\NEURO\Hermes` ("сношу полигон") or test install scripts from scratch
- User asks what will be lost, or wants a backup before reinstall
- Need to locate a portable script (install/fix/patch) inside the repo
- Checking that the repo is ready to be cloned fresh (all scripts committed & pushed)
- An update log says `[OK] Installation Complete!` while stages reported `[!] ... failed`

## Repo layout (portable install — important quirks)
- `D:\NEURO\Hermes` is the git repo `Hermes-Portable-Scripts` (origin: `https://github.com/MRafStudio/Hermes-Portable-Scripts`), branch `main`. **This repo is the only durable layer.**
- **`data/` is the entire `$HERMES_HOME` and is fully `.gitignore`d** — nothing inside survives a wipe; `git clone` does NOT restore it.
- `scripts/*.bat` — user-facing launchers/installers (`Start.bat`, `InstallOrUpdate*.bat`, `Start-Llama-IfNeeded.bat`, `Rebuild-Desktop.bat`).
- `scripts/ps1/*.ps1` — ALL PowerShell here: installer/utility (`hermes_install_portable.ps1`, `install_ffmpeg.ps1`, `install_rg.ps1`), patches (`patch_types.ps1`, `patch_languages.ps1`, `patch_hermes_mime.ps1`, `patch_catalog.ps1`, `patch_install_ps1.ps1`) and MemOS activation (`install-memos.ps1`, `memos-fix.ps1`, `sync-memos-llm.ps1`). There is no `scripts/ps/` or `scripts/patch/` directory — do not go looking there.
- `scripts/skills/` — **durable source of the user's own skills.** The installer copies it with `robocopy "%SCRIPTS_DIR%\skills" "%HERMES_HOME%\skills" /E /XC /XN /XO`; `/XO` = only-newer overwrites, so edits made in `data/hermes/skills/` survive until the repo copy is newer. **A skill that must survive a wipe has to live here.** (Bundled upstream skills are a separate, re-synced set.)
- `scripts/ru-locale/`, `scripts/en-locale/` — RU localization payload applied after the repo reset, which is why every build stamp says `dirty: true`.
- `data/hermes/hermes-agent/` — the **upstream** clone (NousResearch/hermes-agent). Anything edited here is wiped by the wrapper's `git reset --hard origin/main` on the next update.
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

## Diagnosing update-log flaws (verified root causes, reproduced on this host)
An update can print `[OK] Installation Complete!` while three stages fail silently:

| Symptom in log | Root cause | Fix |
|---|---|---|
| `Resolving despite existing lockfile due to removal of global exclude newer` → `error: The lockfile at uv.lock needs to be updated, but --locked was provided` → `[!] uv.lock sync failed ... falling back to PyPI resolve` | upstream `scripts/install.ps1` → `Initialize-ManagedPythonEnvironment` exports `$env:UV_NO_CONFIG = "1"` and never clears it. The later `uv sync --extra all --locked` then ignores `pyproject.toml`'s `[tool.uv] exclude-newer`, uv treats the cutoff as removed and must re-resolve, and `--locked` refuses. The SHA256 hash-verified tier therefore NEVER runs; the fallback installs newest-from-PyPI without the 14-day quarantine (~51 packages drift off the lock) | `scripts/ps1/patch_install_ps1.ps1` removes the leaking line — every `uv python` call already passes `--no-config` explicitly |
| `[!] Browser tools npm install failed -- exit code` (code EMPTY) / same for TUI | Two bugs at once: (1) repo `.npmrc` sets `engine-strict=true` and `package.json` engines forbid npm 11.10–11.16, while global Node 24.x ships npm 11.16.0 → hard `EBADENGINE`, exit 1; (2) `_Invoke-NativeWithTimeout` reads `.ExitCode` off `Start-Process -PassThru`, which is `$NULL` on Windows PowerShell 5.1 → codes read empty, `-eq 0` never matches, so the Playwright-Chromium step (`if ($browserNpmOk)`) is skipped forever | put a compatible npm first on PATH — the working 12.0.2 lives in the *portable* APPDATA (`%APPDATA%\npm` = `data\appdata\npm`), NOT in `C:\Users\<u>\AppData\Roaming\npm` (that one may not exist) |
| `[!] Computer Use driver install failed: The Wait-Job cmdlet cannot finish working, because one or more jobs are blocked waiting for user interaction` | the upstream cua installer self-elevates while registering autostart (`Start-Process -Verb RunAs` → UAC), which can never be answered inside `Start-Job`, so the job blocks | run it synchronously with a timeout; and clean the stale `C:\...\Cua\cua-driver\bin` PATH entry — it shadows the fresh driver (old 0.20.0 vs new 0.28.2) |

Read-only checks that tell them apart:
```bash
cd "$HERMES_HOME/hermes-agent"
uv sync --extra all --locked --dry-run                 # "Resolved ... in 3ms" = the lock itself is fine
UV_NO_CONFIG=1 uv sync --extra all --locked --dry-run  # reproduces the "removal of global exclude newer" line
grep -n 'UV_NO_CONFIG' scripts/install.ps1             # 4-space line leaks; the 8-space one cleans up after itself
npm --version                                          # what .npmrc's engine-strict will judge
cat .npmrc                                             # engine-strict=true; engines window lives in package.json
```
Do not trust: the printed "npm debug log" is the *probe's* (`npm config get cache`), not the failing install's; each failed npm run leaves `data/temp/hermes-npm-*.log` (cleanup only runs on the success branch); `вњ…` in output is UTF-8 read as cp866.

## Pitfalls
- NEVER read or print the contents of `.env` / `auth.json` — list names/sizes only (user's secrets).
- The portable repo is the git repo itself: don't go looking for a nested repo — `git status` at `D:\NEURO\Hermes` root is the one that matters.
- `sessions/` may show 0 files while `state.db` holds history — don't conclude "no sessions" from the dir alone.
- The MemOS activation scripts live in `scripts/ps1/` (`install-memos.ps1`, `memos-fix.ps1`), not in a `patch/` directory.
- Fix placement: durable fixes go in the portable layer (`scripts/ps1/*.ps1` called from a `scripts/*.bat`); anything inside `data/hermes/hermes-agent` is reset on every update. Patchers must be idempotent and must re-parse the patched file (rollback on syntax error).
- A bare `uv sync --extra all --locked` on an existing venv PRUNES lazily-installed extras: the desktop stage eager-installs `.[wake,voice]` (numpy, faster-whisper, ctranslate2, onnxruntime, av, edge-tts), so a lock-exact resync needs `--extra all --extra wake --extra voice` — or those features disappear.
- Don't read venv staleness from file mtimes: uv hardlinks from its cache, so files keep the cache blob's mtime, not the install time.
- `.bat`/`.ps1` must stay CRLF; `write_file` writes LF, so convert after editing and re-verify.

## Related
- `memos-memory-management` — MemOS plugin activation, verification, DB maintenance.
- `hermes-agent` (bundled) — general Hermes config & CLI reference.
