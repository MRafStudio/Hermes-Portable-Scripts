---
name: v2raytun-failover
description: "Use when v2RayTun VPN fails - test configs, switch."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [windows]
metadata:
  cpus: any
  memory: any
  storage: any
  network:
    - proxy
---

# v2RayTun Failover — проверка и переключение серверов

## When to Use

- Интернет через v2RayTun не работает (или IP не меняется через прокси).
- Нужно быстро найти живой сервер из подписки и переключиться на него.

## Конфигурация (где что лежит)

- Приложение: `C:\Program Files (x86)\v2RayTun\v2RayTun.exe`
- Настройки: `%APPDATA%\v2RayTun.net\v2RayTun\shared_preferences.json` (JSON!)
- Конфиги: `flutter.config_<id>` (JSON-строка: `server`, `server_port`, `remarks`, `singBoxOutbound`)
- Список: `flutter.configurations` (JSON-массив ID)
- **Активная: `flutter.selected_config` (ID!)** ← правим её!
- Ядро (sing-box): порты `127.0.0.1:10808` (SOCKS), `127.0.0.1:10809` (HTTP)

## Проверка «работает ли VPN»

```bash
# 1. Прокси отвечает?
curl -s --max-time 8 -x http://127.0.0.1:10809 https://api.ipify.org
# 2. Сравнить с прямым IP!
curl -s --max-time 5 https://api.ipify.org
# ОДИНАКОВЫЙ IP = VPN НЕ туннелит (сервер мёртв / DIRECT!) — нужен failover!
```

## Скрипт проверки

```bash
python scripts/check_v2raytun.py          # список серверов + TCP-статус
python scripts/check_v2raytun.py --select <id>   # переключить активный
```

Скрипт: (1) парсит все конфиги (remarks + server:port); (2) TCP-тест каждого (3с);
(3) показывает живой/мёртвый; (4) `--select` — правит `flutter.selected_config`
(с бэкапом + предупреждением закрыть v2RayTun!).

## Переключение (вручную, если скрипт недоступен)

1. **Закрыть v2RayTun** (иначе при закрытии перезапишет файл из памяти!)
2. Бэкап: `copy shared_preferences.json shared_preferences.json.bak`
3. В файле: `"flutter.selected_config" = "<id живого сервера>"`
4. Запустить v2RayTun → дождаться ядра (10809 слушает!) → проверить IP через прокси!

## Pitfalls

- **НЕ править shared_preferences.json при работающем v2RayTun** — затрутся при закрытии!
- Текущий сервер может «отвечать» (прокси жив), но IP = прямой — туннель НЕ работает — failover нужен!
- TCP-ок ≠ туннель-ок: после переключения ОБЯЗАТЕЛЬНО проверить IP через прокси!
- HTTP API v2RayTun (порт :52117) — не отвечает на GET/WS — не использовать для управления.
