---
name: memos-tool-id-formats
description: "Use when calling MemOS memory tools — correct ID formats."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [memos, memory, id-formats, timeline, search]
---

# MemOS Tool ID Formats

## When to Use

- Task involves MemOS memory tools: `memos_search`, `memos_get`, `memos_timeline`.
- A memory tool returned empty results and you suspect the wrong ID was passed.

MemOS uses **two ID namespaces** — passing the wrong one silently returns empty results:

| Tool | Accepts | Format | Example |
|---|---|---|---|
| `memos_search` | — | returns hits with `refId` | `tr_4hpk7jhekqdv` |
| `memos_get` | **TRACE id only** — `ep_*` ВСЕГДА `found:false` (баг/ограничение 12.08!) | `tr_*` | `memos_get(id="tr_...", kind="trace")` |
| `memos_timeline` | **EPISODE id only** | `ep_*` | `memos_timeline(episodeId="ep_011c84gdkfkx")` |

## The classic bug

`memos_search` hits carry `refId` = **trace** id (`tr_...`). Passing `tr_...` into
`memos_timeline` (which expects `ep_...`) returns `{"traces": []}` — silently empty.
This is NOT a MemOS bug — it's the wrong ID namespace.

## Correct flow (timeline)

1. `memos_get(id="<tr_...>", kind="trace")` → read `episode_id` from the trace body.
2. `memos_timeline(episodeId="<ep_...>")` → real events.

## General rule

Always check the tool contract: `tr_*` = trace, `ep_*` = episode. If a memory tool
returns empty, verify the ID prefix before assuming the tool is broken.
