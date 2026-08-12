---
name: autonomous-execution
description: "Run testing/verification tasks to completion autonomously."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [autonomy, testing, verification, tool-use, task-completion]
---

# Autonomous Execution

**The single rule: do NOT stop after answering. Keep going until the task is actually done.**

Conversational models (especially small local ones like Qwen3.6-35B-A3B / Gemma) tend to reply
"Понял / OK / Good" after one tool call and then wait for the user. That is a HALT — treat it as a failure mode.

## When to Use

Use when the user asks for testing, verification, diagnostics, stress tests, or measurements
("проверь", "протестируй", "разберись", "посмотри", "убедись", "замерь") — anything where the
result must be PROVEN with real tool output, not described. Also use for any multi-step task where
stopping early would leave the work half-done.

## Trigger

Use this skill when the user asks for:
- testing / verification / diagnostics / stress / measurement
- "проверь", "протестируй", "разберись", "посмотри", "убедись", "замерь"
- any multi-step task where the result must be PROVEN, not described

## Protocol (always run to completion)

1. **PLAN the steps** — write down 3-5 concrete tool calls needed to finish (not "just answer").
2. **EXECUTE step by step** — call tools, read outputs, adapt.
3. **VERIFY the result** — run the actual command/check; never claim success from a description.
4. **REPORT with evidence** — real numbers, real file paths, real HTTP codes.
5. **CONTINUE if not done** — if a step failed, fix and retry; if the answer is partial, dig deeper.
6. **Stop ONLY when**: the task is complete (verified), OR the user must decide something, OR an external blocker genuinely blocks progress (report it honestly).

## Anti-patterns (never do these)

- ✗ "Понял, сейчас сделаю" — then nothing. If you said you will, DO it in the same turn.
- ✗ One tool call, then a final answer — when 5 more are obviously needed.
- ✗ Describing what you WOULD do instead of doing it.
- ✗ Stopping after a confirmation ("Готово!") without showing evidence.

## Positive pattern

```
user:  протестируй поиск MemOS
agent: (1) curl health :18800 → 200
       (2) write test fact → POST /api/v1/diag/simulate-turn → ok
       (3) search it → hit, score 1.0
       (4) report: write 2ms, search 8ms, 1 hit — MEMORY WORKS
```
Note: 4 tool calls, one turn, evidence at the end. That is the standard.

## Notes for small models

- If you feel the urge to answer "Ок, понял" — that is the HALT. Override it: pick the NEXT tool call instead.
- The user will NOT push you — you must push yourself through the remaining steps.
- It is better to do 5 tool calls than to look "polite" with 1.
