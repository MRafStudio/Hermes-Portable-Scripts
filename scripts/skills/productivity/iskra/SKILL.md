---
name: iskra
description: Use when user types ИСКРА!. Trigger MemOS crystallization.
version: 1
author: hermes
license: MIT
metadata:
  hermes:
    tags: [memos, crystallization, trigger]
    related_skills: [memos-crystallization-debugging]
---

# ИСКРА! — мгновенная кристаллизация MemOS

## When to Use

Пользователь написал одиночное слово-команду (в любом регистре, с «!» или без): **искра** / **ИСКРА** / **искра!** / **ИСКРА!** — нужно немедленно спровоцировать завершение текущих эпизодов MemOS, чтобы запустилась цепочка reward → L2 (policy_generate/policy_evolve) → L3 (world_model_generate) → skills.

## Контекст

- MemOS daemon: `http://127.0.0.1:18800` (полигон, порт 18800)
- БД: `D:\NEURO\Hermes\data\hermes\memos-plugin\data\memos.db` (таблицы: episodes, policies, world_model, skills, api_logs)
- Штатный API: `GET /api/v1/episodes` → `{episodes: [...]}`, `DELETE /api/v1/episodes?episodeId=<id>` → финализация + reward
- Эпизоды НЕ финализируются при закрытии сессии: они живут до `mergeMaxGapMs` (2ч) или 30 ходов. DELETE — единственный мгновенный штатный триггер.

## Шаги

1. `GET /api/v1/episodes` (timeout 8s) → найти эпизоды со `status == "open"`.
2. Если open-эпизодов **нет** — проверить свежие следы кристаллизации в `api_logs` (последние 10 записей: `policy_generate`, `world_model_generate`, `skill_generate`) и счётчики БД (policies/world_model/skills). Сообщить пользователю, что всё уже закрыто/идет, с цифрами.
3. Для каждого open-эпизода: `DELETE /api/v1/episodes?episodeId=<id>` (timeout 25s).
   - HTTP 500 с `episode not found` — сирота после рестарта daemon, пропустить (закроется сам по stale-таймауту 4ч или при следующем рестарте daemon).
   - HTTP 200 → эпизод закрыт, reward пошёл в фоне.
4. Подождать **60–90 секунд** (reward: task-summary 20–40с + score + backprop → L2 → L3).
5. Проверить `api_logs` (новые записи: `policy_generate`, `world_model_generate`) и счётчики БД: `SELECT COUNT(*) FROM world_model`, `SELECT COUNT(*) FROM policies`, `SELECT COUNT(*) FROM skills`.
6. Отчитаться пользователю: сколько эпизодов закрыто, какие события прошли (policy/world_model), что родилось (титулы новых политик/моделей).

## Питфоллы

- **«Для этого чата» не работает**: домский Hermes не подключён к MemOS (memory.provider отключён) — эпизоды создаёт только полигонский агент. Скилл закрывает ВСЕ open-эпизоды полигона (обычно 1–2).
- Не рестартить daemon, не трогать конфиг, не патчить dist — только GET/DELETE.
- Таймауты: GET 8s, DELETE 25s, ожидание после 60–90с — не больше (правило пользователя).
- Ответ пользователю — по-русски, кратко, с цифрами.
