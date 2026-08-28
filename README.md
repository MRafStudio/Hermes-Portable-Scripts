# Hermes Desktop - Portable

## Описание

Hermes Portable — это скрипты портативной Windows установки для запуска агента Hermes от Nous Research с изолированным Python-окружением.

- Hermes работает с облачными LLM-провайдерами (DeepSeek, OpenRouter, Anthropic, OpenAI и др.) и/или локальным LLM-сервером (Llama)
- **HeadRoom** — встроенный прокси сжатия контекста: экономит до 15–60% токенов, не меняя ответы
- Все данные и окружение изолированы в каталоге `data\` — ничего не пишется в систему
- Оригинальный проект: [Hermes-Agent](https://github.com/nousresearch/hermes-agent)

## 🚀 Быстрый старт

1. Склонируйте этот репозиторий, например:
```text
     cd D:/
     git clone https://github.com/MRafStudio/Hermes-Portable-Scripts.git Hermes
     cd Hermes
```

2. Запустите `Start.bat` и выберите **[1] Установка / Обновление компонентов**
3. Настройте LLM-провайдера: главное меню -> **[5] Варианты запуска** -> `Hermes setup`
4. По желанию: Расширения и плагины -> **[3] HeadRoom** — включить экономию токенов

## 📁 Структура проекта

```text
Hermes/
├── Start.bat                               # Главное меню (центр запуска)
├── scripts/
│   ├── InstallOrUpdate.bat                 # Меню Установка/Обновление проекта
│   ├── InstallOrUpdate-Plugins.bat         # Меню Расширения и плагины
│   ├── InstallOrUpdate-HeadRoom.bat        # HeadRoom: прокси сжатия контекста
│   ├── InstallOrUpdate-Memos.bat           # MemOS: память агента
│   ├── InstallOrUpdate-Models.bat          # Llama: загрузка и назначение моделей
│   ├── InstallOrUpdate-Web.bat             # Hermes Web (dashboard)
│   ├── InstallOrUpdate-Desktop.bat         # Desktop версия Hermes
│   ├── InstallOrUpdate-NodeJS.bat          # Node.js
│   ├── InstallOrUpdate-Python.bat          # Python
│   ├── InstallOrUpdate-UV.bat              # uv (пакетный менеджер)
│   ├── InstallOrUpdate-Repo.bat            # Локальный репозиторий hermes-agent
│   ├── InstallOrUpdate-RU.bat              # RU локализация
│   ├── InstallOrUpdate-Deps.bat            # fallback установки зависимостей
│   ├── Backup-Now.bat                      # Бэкап перед изменениями
│   ├── Install-Hermes-Service.bat          # Hermes как служба Windows
│   ├── Remove-Hermes-Service.bat           # Удаление службы
│   ├── Restart-Hermes-Service.bat          # Перезапуск службы
│   ├── Open-Firewall-Port.bat              # Проброс портов
│   ├── LaunchOptions.bat                   # Варианты запуска (CLI, gateway и др.)
│   ├── Start-Hermes-Desktop.bat            # Запуск Hermes Desktop
│   ├── Start-Hermes-Desktop-Console.bat    # Консоль запущенного Hermes
│   ├── Start-Hermes-Web.bat                # Запуск Hermes Web
│   ├── Start-Llama-IfNeeded.bat            # Единая точка настройки LLM
│   ├── Rebuild-Desktop.bat                 # Пересборка Desktop
│   ├── SmartPause.bat                      # Умная пауза
│   ├── Tools.bat                           # Пользовательские инструменты
│   ├── bin/                                # Вспомогательные бинарники (uv.exe)
│   ├── ps1/                                # PowerShell-скрипты (fix-user_env и др.)
│   ├── py/                                 # Python-утилиты (headroom_stats и др.)
│   ├── patch/                              # Патчи
│   ├── profiles/                           # Профили
│   ├── roles/                              # Роли для config.yaml
│   ├── skills/                             # Навыки
│   ├── en-locale/                          # Локализация EN
│   └── ru-locale/                          # Локализация RU
└── data/                                   # Данные (создаётся при установке)
```

## 📦 Установка

1. Установите **Git for Windows** (если ещё не установлен)
2. Запустите `Start.bat`
3. Выберите пункт **[1] Установка / Обновление компонентов**
4. Дождитесь установки всех компонентов системы
5. Настройте LLM-провайдера: главное меню -> **[5] Варианты запуска** -> `Hermes setup`

## ▶️ Запуск

1. Запустить `Start.bat`
2. Нажать Enter (быстрый запуск Desktop App) или выбрать пункт меню
3. Запустится приложение Hermes Agent

## 🧩 Расширения и плагины

Меню **Расширения и плагины** (`InstallOrUpdate-Plugins.bat`):

| Пункт | Расширение | Назначение |
|---|---|---|
| [1] | **LlamaCppWindowsManager** | Локальный LLM-сервер (llama.cpp), модели, служба |
| [2] | **MemOS** | Память агента: L1/L2/L3, гибридный поиск, viewer :18800 |
| [3] | **HeadRoom** | Прокси сжатия контекста — экономия токенов |

### HeadRoom — прокси сжатия контекста

[HeadRoom](https://github.com/headroomlabs-ai/headroom) — локальный прокси между Hermes и LLM-провайдером. Сжимает tool-выводы, JSON, логи **до** отправки в модель: 60–95% на JSON, 15–20% на кодинг-сессиях. Сжатие обратимое — оригиналы хранятся в локальном кэше.

```
Hermes Desktop → 127.0.0.1:8787 (HeadRoom) → api.deepseek.com
```

- Установка: `InstallOrUpdate-HeadRoom.bat` -> **[1] Установить/Обновить** (ставит всё в `data\HeadRoom`, службу Windows с автозапуском, подключает Hermes)
- Служба `Headroom`: порт **8787**, режим `cache` (не ломает prefix-cache провайдера)
- **[6] Подключить/Отключить прокси** — тумблер `model.base_url` (старый адрес сохраняется в `saved_base_url.txt` и восстанавливается при отключении/удалении службы)
- **[4] Статус и экономия** — сводка: запросы, сэкономленные токены, деньги
- Подробная статистика: `http://127.0.0.1:8787/stats-history` (в браузере)
- После установки или переключения тумблера **перезапустите Hermes Desktop**, чтобы изменения применились

## ⚙️ Требования

- Windows 10/11 x64
- ~10GB свободного места (для полной установки)
- Интернет-соединение для первичной загрузки и работы с облачными LLM

## 📄 Лицензии

Составляющие проекта имеют свои лицензии:
- 🤖 Hermes: Nous Research
- 📦 Скрипты: MIT (RafStudio)
- 🧩 HeadRoom: OSS (headroomlabs-ai)
