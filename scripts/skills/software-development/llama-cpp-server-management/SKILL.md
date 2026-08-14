---
name: llama-cpp-server-management
description: "Use when managing llama.cpp server deployment."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [windows]
metadata:
  hermes:
    tags: [llama.cpp, llama-server, hermes, deployment, ports, gpu]
    related_skills: [hermes-agent, hermes-portable-maintenance]
---

# llama.cpp Server Management (Hermes Portable)

Deploy, run, and wire llama.cpp `llama-server` for Hermes Agent on Windows (dual C:/D: installs: дом + полигон on one machine).

## When to Use
- Installing/updating llama.cpp on a Hermes-Portable install (дом or полигон).
- Start.bat / Start-Llama-IfNeeded.bat behavior around ports and instances.
- Port conflicts (5505 busy), Hermes `providers.llama.base_url` / `auxiliary.vision.base_url` wiring, vision-via-llama tests.
- GPU memory questions (two instances of one model on 32GB).

## Firm rules (user-set, 2026-08-12)
- **Port 5505 — THE port for llama.cpp** (8080 is often taken by proxies/other apps; 5506 = emergency when 5505 is busy). ALL scripts, Hermes `providers.llama.base_url`, `auxiliary.vision.base_url` must use 5505/5506 — never 8080.
- **One model = ONE live instance.** 2×16.8GB > 32GB VRAM (RTX 5090): second instance offloads to RAM → 15-25 T/s. House (base) and polygon (test) must NOT run the model simultaneously.
- **`--alias llama/<model>` is REQUIRED** — Hermes sends the alias; without it the server (which registers the full .gguf path) returns model-not-found.
- Flags for 5090 (sm_120): `--mmproj` (not -mmproj), `--flash-attn 1`, `--port` (not -p), `-ngl 999`, `--parallel 1`. CUDA 13.3 required (12.4 does not support Blackwell). **НЕ использовать `--image-min-tokens`**: для Gemma-4-26B он роняет загрузку mmproj (`image_max_pixels 645120 < image_min_pixels 2359296` — llama-server exiting due to model loading error); проверено биссекцией 14.08 — флаг убран из всех скриптов.

## Start script port logic (Start-Llama-IfNeeded.bat)
1. `curl :5505/health` answers → use it (already running, one instance).
2. `curl :5506/health` answers → use it, set base_url to :5506.
3. `netstat` shows :5505 LISTENING but health silent (foreign app) → start own instance on :5506.
4. Port free → start base on :5505.
5. Always reconfigure `providers.llama.base_url` (and auxiliary.vision.base_url) to the ACTUAL port via `hermes config set`.

## Pitfalls
- `Start-llama.bat` lives in repo (`scripts/`) as ONE static script — NO copy in `data\llama` (removed 08.2026), NO generator. It computes `LLAMA_DIR=%ROOT_DIR%\data\llama` itself. All callers use `%SCRIPTS_DIR%\Start-llama.bat` (Start-Llama-IfNeeded, InstallOrUpdate-Models).
- Launch llama detached: `start "title" /min "%LLAMA_DIR%\llama-server.exe" ...` — otherwise closing Start.bat kills the server (same console group). No `pause` in the launch script (leaves an orphan window).
- Hermes desktop can't launch GUI apps from the service session (no screen) — llama-server (console) is fine, GUI apps are not.
- After `sed` on any .bat: normalize CRLF on DISK (sed writes LF → cmd breaks with "VERSION is not recognized"). See windows-gitbash-terminal.
