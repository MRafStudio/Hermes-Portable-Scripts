---
name: hermes-token-saving
description: "Экономия токенов в Hermes: proactive_prune, headroom."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes, tokens, compression, cost, headroom]
---

# Экономия токенов в Hermes

## Когда использовать
- Пользователь спрашивает про экономию токенов/денег на LLM в Hermes
- Нужно настроить сжатие контекста (`compression.*` в config.yaml)
- Обсуждается headroom (headroomlabs-ai/headroom) — компрессионный прокси между агентом и LLM

## Встроенные фичи Hermes (секция `compression:` в config.yaml)
- `enabled: true` — полное сжатие контекста (суммаризация середины). Параметры: `threshold: 0.5` (доля контекста), `target_ratio: 0.2`, `protect_last_n: 20`, `protect_first_n: 3`, `min_tail_user_messages: 1`
- **`proactive_prune_tokens: 0` — ВЫКЛЮЧЕНО по умолчанию.** Проактивная суммаризация старых tool-результатов (работает независимо от полного сжатия, `prune_tool_results_only`). Когда накопленный объём tool-результатов превышает порог (токены) — старые результаты заменяются саммари.
- `proactive_prune_min_result_chars: 8000` — минимальный размер результата, который стоит суммаризировать (floor 200)
- `proactive_prune_min_reclaim_tokens: 4096` — минимальная экономия токенов, чтобы коммит состоялся. Защита: каждый коммит переписывает уже виденные сообщения и **ломает prefix prompt-cache** — порог делает срабатывания редкими (как санкционированный cache-break)
- `micro_compact: false` — покатушечная микро-компакция каждый ход (rolling compaction). Ломает cache чаще; для DeepSeek (дешёвый prefix-кэш) приемлемо, для дорогих провайдеров — осторожно

### Включение (команды, а не ручная правка yaml!)
```bash
hermes config set compression.proactive_prune_tokens 2048
hermes config set compression.micro_compact true
```
Откат: `hermes config set ... 0` / `false`. Конфиг применяется при старте сессии (новые сессии — сразу).

### ВАЖНО про окружение (Hermes Portable)
Перед запуском `hermes` из внешнего терминала: `export HERMES_HOME="C:\NEURO\Hermes\data\hermes"` (и HOME=data\home). Без HERMES_HOME CLI пишет в `~/.hermes` — создаётся мусорный каталог, настройка не применяется.

## Headroom (headroomlabs-ai/headroom)
- Что: локальный прокси, сжимает tool-выводы/JSON/код/логи **до** отправки в LLM; обратимо (CCR — оригиналы в локальном кэше, модель может запросить). Плюс режет выходные токены (`HEADROOM_OUTPUT_SHAPER=1`: verbosity steering + effort routing)
- Цифры (их бенчи): 60–95% на JSON, 15–20% на кодинг-агентах, точность не падает
- Совместимость: OpenAI/Anthropic/Gemini-роуты, форвард на любой upstream: `headroom proxy --openai-api-url https://api.deepseek.com --port 8787` (upstream base БЕЗ /v1; ключ прокидывается прозрачно)
- `--mode cache` (default) — не ломает provider prefix-cache (идеально для DeepSeek). `--mode token` — максимум сжатия, переписывает прошлые ходы
- Подключение Hermes: `hermes config set model.base_url http://127.0.0.1:8787/v1`
- Риск: прокси — обязательный фоновый процесс; если лёг — Hermes без связи

### Установка на Windows (ПОДВОДНЫЙ КАМЕНЬ)
- На PyPI **нет Windows wheels** — pip/uv упадут в сборку Rust-расширения (нужен MSVC + rustup)
- **НО**: в GitHub releases лежит готовый wheel: `headroom_ai-<ver>-cp310-abi3-win_amd64.whl` (abi3 = любой Python 3.10+). Проверить актуальную версию: `curl -s https://api.github.com/repos/headroomlabs-ai/headroom/releases/latest | grep tag_name`
```bash
uv tool install --python 3.13 "headroom-ai[proxy]" --from https://github.com/headroomlabs-ai/headroom/releases/download/v<ver>/headroom_ai-<ver>-cp310-abi3-win_amd64.whl
```
- Проверка: `headroom doctor`, `headroom perf`, `curl http://127.0.0.1:8787/health`

## Дисциплина экономии (уже в арсенале — соблюдать!)
- Батчинг независимых tool-вызовов в один блок (параллельно)
- `delegate_task` для тяжёлого контекста: субагент переваривает, родителю — только саммари
- `session_search` вместо пересказа прошлого контекста
- `read_file` с offset/limit вместо полных чтений
- НЕ выдумывать цифры экономии — давать оценочно и честно

## Питфоллы
- docs.headroom-docs.vercel.app не отдаётся git-curl на Win10 1607 (TLS, exit 35) — использовать raw.githubusercontent.com или `curl -k`
- `search_files` (ripgrep) может падать на путях C:\NEURO (os error 3) — обходить через bash `grep -rn --include="*.py" --exclude-dir={.git,...}`
