#!/usr/bin/env python3
"""verify_memos_installer.py — verify scripts/patch/install-memos.ps1 + memos-fix.ps1
of the Hermes-Portable-Scripts repo against the MemOS target config.

Usage: python verify_memos_installer.py [repo-root]   (default: D:/NEURO/Hermes)

Checks:
  A. install-memos.ps1 step-4 here-string YAML block carries the target config:
     embedTraces=true, llm.provider=local_only (no forced LLM), local embedding model,
     llmFilterEnabled=false, llmFilterMinCandidates=50, ftsTokenizer=trigram,
     lightweightMemory.enabled=true.
  B. memos-fix.ps1 PATCH rules, simulated on the live memos-plugin/config.yaml:
     embedTraces must flip to true, llm stays local_only.
  C. PowerShell interpolates ${RuntimeHome} inside the here-string (via -EncodedCommand,
     immune to bash quote mangling).
Exit 0 only when everything passes. Run this AFTER editing the installer scripts,
BEFORE committing. Temp-file policy: this script is a skill asset, not a repo artifact.

Known gotchas encoded here:
  * `apiKey: ***` is NOT valid strict YAML (`*` opens an alias) — mask before safe_load.
  * PowerShell here-strings: `@"` opener and `"@` closer each on their own line.
"""
import base64
import re
import subprocess
import sys
from pathlib import Path

import yaml

REPO = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"D:/NEURO/Hermes")
INSTALL = REPO / "scripts/patch/install-memos.ps1"
FIXER = REPO / "scripts/patch/memos-fix.ps1"
LIVE_CFG = REPO / "data/hermes/memos-plugin/config.yaml"

failures = []


def check(name: str, ok: bool, detail: str = "") -> None:
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {detail}" if detail else ""))
    if not ok:
        failures.append(name)


# ── A. installer YAML block ────────────────────────────────────────────────
text = INSTALL.read_text(encoding="utf-8")
blocks = re.findall(r'^[ \t]*@"\n(.*?)\n[ \t]*"@', text, re.S | re.M)
check("A0 config here-string found", bool(blocks))
if blocks:
    block = re.sub(r": \*+\s*$", ": masked", blocks[-1], flags=re.M)  # *** is a YAML alias token
    cfg = yaml.safe_load(block)
    alg, cap, ret = cfg["algorithm"], cfg["algorithm"]["capture"], cfg["algorithm"]["retrieval"]
    check("A1 embedTraces=true", cap["embedTraces"] is True, f"got {cap['embedTraces']!r}")
    check("A2 llm.provider=local_only", cfg["llm"]["provider"] == "local_only", f"got {cfg['llm']['provider']!r}")
    check("A3 local embedding model", "all-MiniLM-L6-v2" in cfg["embedding"]["model"], f"got {cfg['embedding']['model']!r}")
    check("A4 llmFilterEnabled=false", ret["llmFilterEnabled"] is False, f"got {ret['llmFilterEnabled']!r}")
    check("A5 llmFilterMinCandidates=50", ret["llmFilterMinCandidates"] == 50, f"got {ret['llmFilterMinCandidates']!r}")
    check("A6 ftsTokenizer=trigram", cfg["storage"]["ftsTokenizer"] == "trigram", f"got {cfg['storage']['ftsTokenizer']!r}")
    check("A7 lightweightMemory.enabled=true", alg["lightweightMemory"]["enabled"] is True, f"got {alg['lightweightMemory']['enabled']!r}")

# ── B. fixer PATCH rules on live config ───────────────────────────────────
fix = FIXER.read_text(encoding="utf-8")
check("B0 fixer targets embedTraces=true", "embedTraces = $true" in fix and "embedTraces = $false" not in fix)
if LIVE_CFG.exists():
    live = yaml.safe_load(LIVE_CFG.read_text(encoding="utf-8"))
    live_et = live["algorithm"]["capture"].get("embedTraces")
    live_llm = live["llm"]["provider"]
    patch = {}
    if live_llm != "local_only":
        patch["llm"] = {"provider": "local_only"}
    if live_et is not True:
        patch.setdefault("algorithm", {}).setdefault("capture", {})["embedTraces"] = True
    check("B1 fixer flips live embedTraces -> true", patch.get("algorithm", {}).get("capture", {}).get("embedTraces") is True,
          f"live={live_et!r} patch={patch.get('algorithm', {}).get('capture')!r}")
    check("B2 fixer keeps llm local_only", patch.get("llm", {}).get("provider", live_llm) == "local_only",
          f"live={live_llm!r}")
else:
    check("B1 live config available", False, "missing")

# ── C. PowerShell interpolation ────────────────────────────────────────────
ps = ("$RuntimeHome = 'C:\\FAKE\\data\\hermes\\memos-plugin'\n@\"\n" + blocks[-1] + "\n\"@\n")
enc = base64.b64encode(ps.encode("utf-16-le")).decode()
r = subprocess.run(["powershell", "-NoProfile", "-EncodedCommand", enc], capture_output=True, text=True, timeout=60)
rendered = r.stdout if r.returncode == 0 else r.stderr
check("C0 powershell renders here-string", r.returncode == 0, r.stderr[:200])
check("C1 ${RuntimeHome} interpolated", r"C:\FAKE\data\hermes\memos-plugin\models\all-MiniLM-L6-v2" in rendered)
check("C2 rendered config keeps embedTraces=true", "embedTraces: true" in rendered)

print()
if failures:
    print(f"RESULT: FAIL ({len(failures)}: {', '.join(failures)})")
    sys.exit(1)
print("RESULT: ALL PASS")
sys.exit(0)
