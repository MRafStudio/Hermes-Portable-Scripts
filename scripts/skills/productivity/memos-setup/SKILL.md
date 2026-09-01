---
name: memos-setup
description: "Use when настраиваешь MemOS под Hermes: эмбеддинг, LLM кристаллизации, активация памяти."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [memos, memory, memtensor, plugin, embedding, llm, crystallization, config, setup]
    related_skills: [memos-memory-diagnosis, memos-crystallization-debugging, hermes-memory-providers, hermes-agent]
---

# MemOS Setup (проверенная настройка под Hermes)

Полная, проверенная на практике конфигурация MemOS-плагина (memtensor, Reflect2Evolve V7, v2.0.15)
под Hermes на Windows. Все пункты — из живого боевого прогона; ошибки ниже реально ловились.

## Когда использовать

- Пользователь ставит/чинит MemOS как память Hermes (`memory.provider=memtensor`).
- Память установлена, но `memos_search` пуст, кристаллизация не идёт, skills/policies = 0.
- Daemon на :18800 не поднимается или падает.
- В логах `embedding.*.http.non_ok` / `provider.failed` / `llm_unavailable: HTTP 401`.

## Ключевые пути (Windows)

| Что | Где |
|---|---|
| Плагин | `%HERMES_HOME%\memos-plugin` (= `data\hermes\memos-plugin`) |
| Конфиг | `%MEMOS_HOME%\config.yaml` |
| БД | `%MEMOS_HOME%\data\memos.db` |
| Модель эмбеддера | `%MEMOS_HOME%\models\all-MiniLM-L6-v2` |
| Логи | `%MEMOS_HOME%\logs\` (`memos.log`, `llm.jsonl`, `error.log`, `daemon-start.log`) |
| Daemon (viewer) | `http://127.0.0.1:18800` |
| Скрипты | `%ROOT_DIR%\scripts\` — `InstallOrUpdate-Memos.bat`, `ps1\install-memos.ps1`, `ps1\memos-fix.ps1`, `ps1\sync-memos-llm.ps1` |

`%ROOT_DIR%` = корень установки Hermes (родитель `scripts\`), `%HERMES_HOME% = %ROOT_DIR%\data\hermes`.

## 1. Эмбеддинг — ПРАВИЛЬНЫЕ настройки (главный грабли!)

**`provider: local` + модель `all-MiniLM-L6-v2` (dim 384).** Это единственный рабочий вариант
без внешних API.

```yaml
embedding:
  provider: local
  apiKey: ""
  model: "D:\NEURO\Hermes\data\hermes\memos-plugin\models\all-MiniLM-L6-v2"
  fallbackToHost: false
```

⚠️ **НЕ использовать `provider: openai_compatible` для эмбеддинга** — если endpoint не отдаёт
эмбеддинги (например, llama-server без `--embedding`), получаем тысячи ошибок
`embedding.openai_compatible http.non_ok` + `provider.failed` в `daemon-start.log`, и память
**молча не работает** (трейсы пишутся без векторов). Признак: в логе 700+ таких строк.

## 2. LLM для кристаллизации — локальная llama, не DeepSeek

**КРИТИЧНО: Qwen3.6 35B — reasoning-модель!** Если llama-server запущен с думанием
(`ReasoningMode: auto` в профиле форка), весь вывод уходит в `reasoning_content`,
а `content` ПУСТОЙ (`content_len=0`). MemOS получает пустоту → ставит
`source=heuristic, trigger=implicit_fallback` вместо настоящего LLM-reward →
кристаллизация МЁРТВАЯ, policies/skills не растут.

**Симптомы:**
- `/api/v1/health`: `llm.lastOkAt: null`, хотя embedder/bridge работают
- `llm.jsonl` пустой, `memos.log` без LLM-вызовов
- В БД: эпизоды закрыты (finalized), но reward с `source=heuristic`
- Проверка: `curl -X POST 127.0.0.1:8101/v1/chat/completions` с простым вопросом —
  если `content` пуст, а `reasoning_content` заполнен → думание включено

**Решение (на стороне форка, НЕ MemOS):**
1. Профиль модели в БД форка (`model_launch_profiles.settings_json`):
   `"ReasoningMode": "auto"` → `"ReasoningMode": "off"` — llama-server стартует с
   `--reasoning off`, content заполняется нормально.
2. Проверка: `chat_template_kwargs: {"enable_thinking": false}` в запросе работает,
   а `reasoning: {"enabled": false}` (формат MemOS/OpenRouter) — **НЕ работает**
   на llama-server (игнорируется). Поэтому конфиг MemOS бесполезен — правится служба.

**Правильная конфигурация llm в config.yaml MemOS:**
```yaml
llm:
  provider: openai_compatible
  endpoint: "http://127.0.0.1:8101/v1"
  apiKey: "<из HERMES_CUSTOM_LLAMA_API_KEY>"
  model: "Qwen3.6 35B A3B UD IQ4 NL"
  fallbackToHost: false
  timeoutMs: 180000
```

Кристаллизация (L1 scoring/reward, L2-индукция политик, L3 world models, skills, feedback)
идёт через единый `llm`-клиент. По умолчанию скрипты тянут DeepSeek — **это необязательно**,
локальная llama справляется.

```yaml
llm:
  provider: openai_compatible
  endpoint: "http://127.0.0.1:8101/v1"          # локальный llama-server (порт из настроек, autoLoadGatewayPort)
  apiKey: "<ключ из HERMES_CUSTOM_LLAMA_API_KEY>"
  model: "Qwen3.6 35B A3B UD IQ4 NL"            # model.default из конфига Hermes
  fallbackToHost: false
  timeoutMs: 180000                             # НЕ уменьшать: длинные batch-рефлексии рвутся на 45-60с
```

- `skillEvolver` наследует `llm` (`inherited: true`) — отдельно настраивать не нужно.
- У локальной llama-server **есть** API-ключ (`HERMES_CUSTOM_LLAMA_API_KEY`) — его надо прописать,
  пустая строка даёт 401 (в health: `llm_unavailable: HTTP 401`).
- Правильный источник: `sync-memos-llm.ps1` — вызывается из `Start-Llama-IfNeeded.bat` (сценарии А/Б2)
  и пишет в MemOS активную LLM Hermes (provider=llama → openai_compatible(endpoint=model.base_url,
  model=model.default); provider=<external> → свой endpoint+ключ; provider=пусто → тихий выход).
- `InstallOrUpdate-Memos.bat` сам sync-memos-llm НЕ вызывает — только install/fix. Это нормально:
  LLM-параметры добивает Start-Llama-IfNeeded.bat при первом запуске Hermes.

## 3. Кристаллизация — обязательные флаги

```yaml
algorithm:
  lightweightMemory:
    enabled: false          # true = скипаются L2/L3/skills → кристаллизация мертва
  capture:
    embedTraces: true
  retrieval:
    llmFilterEnabled: false # фильтр запросов LLM — не нужен, экономит вызовы
```

- Кристаллизация **автоматическая фоновая** (раз в ~3 часа), ручных endpoint'ов
  `/api/v1/crystallize`, `/api/v1/sync`, `/api/v1/reflect` **НЕТ** (404) — не искать их.
- Признак работы: в `logs\llm.jsonl` появляются записи (пустой файл = LLM не звался вообще).
- После первого запуска skills/policies могут быть пустыми часами — это нормально, ждём цикл.

## 4. Активация памяти в Hermes

```bash
hermes config set memory.provider memtensor
# проверить:
hermes config get memory.provider   # → memtensor
hermes config get memory.memory_enabled  # → True
```

⚠️ **Баг install-memos.ps1**: при UPDATE (когда `package.json` уже есть) активация скипается,
если `memory.provider` ещё не `memtensor`:

```powershell
if ($curProvider -notmatch "memtensor") { $wantActivate = $false }
```

Скрипт пишет "MemOS installed but DISABLED... Enable later with: hermes config set memory.provider memtensor"
и НЕ включает память. Свежая установка (нет package.json) — активирует, повторный запуск — нет.
**Фикс**: при UPDATE активировать тоже (или вручную выполнить `hermes config set memory.provider memtensor`).

## 5. Баги writer'а плагина (config.yaml)

- **`apiKey: ***`** (голая маскировка writer'а) — **невалидный YAML** ("Unresolved alias: **"),
  daemon падает при старте. Чинить НАПРЯМУЮ в файле ДО старта daemon:
  `apiKey: ***` → `apiKey: ""` (или реальный ключ). memos-fix.ps1 шаг 2a уже делает это.
- API PATCH `/api/v1/config` маскирует ключ — **не слать apiKey через PATCH**, писать в файл после.
- `embedding.fallbackToHost` — неизвестный ключ для 2.0.15 (warning при старте, не критично).

## 6. Daemon (viewer) на :18800

- Запуск: `node node_modules/tsx/dist/cli.mjs bridge.cts --daemon --agent=hermes`
  **из `%MEMOS_HOME%`**, через `Start-Process` (memos-fix.ps1) или background-процесс —
  НЕ в foreground: команда живёт вечно и упрётся в таймаут терминала.
- Проверка: `GET http://127.0.0.1:18800/api/v1/health` → `{"ok":true, ..., "bridge":{"status":"connected"}}`.
- `bridge.status: connected` = Python-адаптер Hermes подключён. `disconnected` со stale heartbeat —
  обычно не критично: клиент работает автономно через stdio.
- Daemon нужен для работы (HTTP API, через него идут `memos_search` и пр.) — это НЕ лишний процесс.

## 7. Диагностика (быстрая)

```bash
curl -s http://127.0.0.1:18800/api/v1/health          # llm/embedder/bridge статусы
curl -s -X POST http://127.0.0.1:18800/api/v1/embeddings/rebuild -H "Content-Type: application/json" -d '{}'
curl -s http://127.0.0.1:18800/api/v1/policies        # политики (результат L2)
curl -s http://127.0.0.1:18800/api/v1/skills          # навыки (результат кристаллизации)
```

- `/api/v1/embeddings/rebuild` возвращает `statsBefore/After` (totalSlots, ready, missing, dimMismatch).
  Все `ready: N` + `missing: 0` = эмбеддинги в порядке.
- `llm.available: true` + `lastError: null` в health = LLM для кристаллизации настроен.
- Смотреть `logs\daemon-start.log` (что было при старте) и `logs\llm.jsonl` (зовётся ли LLM).

## 8. Типовые сценарии и фиксы

| Симптом | Причина | Фикс |
|---|---|---|
| `HTTP 401 from openai_compatible` в health | apiKey пустой/маскирован | прописать ключ llama (HERMES_CUSTOM_LLAMA_API_KEY) в config.yaml |
| 798× `embedding.*.http.non_ok` в логе | embedding.provider=openai_compatible | сменить на `provider: local` + all-MiniLM |
| daemon падает, "Unresolved alias: **" | `apiKey: ***` в config.yaml | заменить на `""`/ключ до старта |
| skills/policies пустые, llm.jsonl пуст | lightweightMemory=true | `algorithm.lightweightMemory.enabled: false` |
| "MemOS installed but DISABLED" | баг install-memos.ps1 (UPDATE) | `hermes config set memory.provider memtensor` вручную |
| 0 трейзов в БД | не было ходов | трейзы пишутся на turn.end — просто поработать |

## Полезные ссылки

- `hermes-memory-providers` (references: memos-local-plugin, memos-daemon-lifecycle, memos-llm-sync)
- `memos-memory-diagnosis` — глубокая диагностика БД (inspect_memos_db.py)
- `memos-crystallization-debugging` — когда кристаллизация пуста несмотря на живой LLM
