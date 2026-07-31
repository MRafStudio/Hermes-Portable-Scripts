# Hermes Desktop - Portable

## Описание

Hermes Portable — это скрипты портативной Windows установки для запуска агента Hermes от Nous Research с изолированным Python-окружением.
Hermes работает с облачными LLM-провайдерами (OpenRouter, Anthropic, OpenAI, DeepSeek и др.) — локальный LLM-сервер не требуется.
Оригинальный проект на [Hermes-Agent](https://github.com/nousresearch/hermes-agent)

## 🚀 Быстрый старт

1. Склонируйте этот репозиторий, например:
```text
     cd D:/
     git clone https://github.com/MRafStudio/Hermes-Portable-Scripts.git Hermes
     cd Hermes
```

## 📁 Структура проекта

```
Hermes/
├── Start.bat                               # Главное меню
├── scripts/                                # Скрипты управления
│   ├── Download-Electron.bat               # fallback загрузки Electron
│   ├── InstallOrUpdate.bat                 # Меню Установка/Обновление проекта
│   ├── InstallOrUpdate-Deps.bat            # fallback установки/обновления зависимостей
│   ├── InstallOrUpdate-Desktop.bat         # Установка/Обновление десктоп версии Hermes
│   ├── InstallOrUpdate-NodeJS.bat          # Установка/Обновление Node.js
│   ├── InstallOrUpdate-Python.bat          # Установка/Обновление Python
│   ├── InstallOrUpdate-UV.bat              # Установка/Обновление uv
│   ├── InstallOrUpdate-Repo.bat            # fallback установки/обновления локального репозитория Hermes
│   ├── InstallOrUpdate-RU.bat              # Установка/Обновление RU локализации
│   ├── LaunchOptions.bat                   # Варианты запуска Hermes (CLI, gateway и др.)
│   ├── Rebuild-Desktop.bat                 # Отдельный скрипт быстрой пересборки Hermes
│   ├── SmartPause.bat                      # Умная пауза
│   ├── Start-Hermes-Desktop.bat            # Запуск Hermes в desktop режиме
│   ├── Start-Hermes-Desktop-Console.bat    # Консоль запущенного Hermes
│   ├── Tools.bat                           # Пользовательские инструменты
│   ├── bin/                                # Вспомогательные бинарники (uv.exe)
│   ├── patch/                              # Каталог с патчами
│   ├── en-locale/                          # Каталог с локализацией EN
│   └── ru-locale/                          # Каталог с локализацией RU
└── data/                           # Каталог расположения Hermes (создаётся при установке)
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

## ⚙️ Требования

- Windows 10/11 x64
- ~10GB свободного места (для полной установки)
- Интернет-соединение для первичной загрузки и работы с облачными LLM

## 📄 Лицензии

Составляющие проекта имеют свои лицензии:
- 🤖 Hermes: Nous Research
- 📦 Скрипты: MIT (RafStudio)
