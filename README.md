# Hermes Desktop - Portable

## Описание

Hermes Portable — это скрипты портативной Windows установки для запуска агента Hermes от Nous Research с изолированным Python-окружением.
Возможна установка с локальным LLM-сервером KoboldCpp и автоматической настройкой под ваш GPU.
Оригинальный проект на [Hermes-Agent](https://github.com/nousresearch/hermes-agent)

## 🚀 Быстрый старт

1. Склонируйте этот репозиторий в `D:\Odysseus` например:
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
│   ├── CreateConfig.bat                    # Конструктор конфигурации скриптов
│   ├── DetectGPU.bat                       # Автоопределение GPU и VRAM
│   ├── Download-Electron.bat               # fallback загрузки Electron
│   ├── InstallOrUpdate.bat                 # Меню Установка/Обновление проекта
│   ├── InstallOrUpdate-Deps.bat            # fallback установки/обновления зависимостей
│   ├── InstallOrUpdate-Desktop.bat         # Установка/Обновление десктоп версии Hermes
│   ├── InstallOrUpdate-HF.bat              # Установка/Обновление hf для загрузки моделей
│   ├── InstallOrUpdate-Kobold.bat          # Установка/Обновление KoboldCpp и моделей
│   ├── InstallOrUpdate-Repo.bat            # fallback установки/обновления локального репозитория Hermes
│   ├── InstallOrUpdate-RU.bat              # Установка/Обновление RU локализации
│   ├── Model-Setup.bat                     # Установка моделей
│   ├── PatchConfigKobold.bat               # Патчер config.yaml для применения локальной LLM
│   ├── Rebuild-Desktop.bat                 # Отдельный скрипт быстрой пересборки Hermes
│   ├── Settings.bat                        # Минимальное управление настройками Kobold
│   ├── SmartPause.bat                      # Умная пауза
│   ├── Start-Hermes-Desktop.bat            # Запуск Hermes в desktop режиме
│   ├── Start-Hermes-Desktop-Console.bat    # Консоль запущенного Hermes
│   ├── Start-Kobold.bat                    # Управление KoboldCpp (start/stop/status)
│   ├── Tools.bat                           # Пользовательские инструменты
│   ├── patch/                              # Каталог с патчами
│   └── ru-locale/                          # Каталог с локализацией RU
├── kobold/                                 # KoboldCpp и модели (если установить)
│   ├── koboldcpp.exe
│   └── models/
│       ├── Qwen_*.gguf             # LLM модель
│       ├── mmproj-*.gguf           # Vision проектор
│       └── whisper/
│           └── ggml-medium.bin     # Whisper модель
└── data/                           # Каталог расположения Hermes
```

## ⚡ Автоопределение GPU

Скрипт `DetectGPU.bat` определяет:
- Тип GPU (NVIDIA / AMD / Intel)
- Модель и объём VRAM
- Оптимальные параметры KoboldCpp (context size, batch size, flash attention)

## 💻 Поддерживаемые GPU

| GPU | VRAM | Рекомендуемая модель |
|-----|------|----------------------|
| RTX 5090/5080 | 32GB | Qwen 3.6 27B Q5_K_M |
| RTX 4090/3090 | 24GB | Qwen 3.6 27B Q4_K_M |
| 16GB карты | 16GB | Qwen 2.5 VL 14B Q4_K_M |
| 8-12GB карты | 8-12GB | Qwen 2.5 VL 7B Q4_K_M |

## 📦 Установка

1. Установите **Git for Windows** и **Microsoft C++ Build Tools** (если ещё не установлены)
2. Запустите `Start.bat`
3. Выберите пункт **[1] Установка / Обновление компонентов**
4. Дождитесь установки всех компонентов системы
5. Если нужна локальная LLM выберите [7] Установка KoboldCpp
   Скрипт автоматически определит GPU и скачает подходящие модели

## ▶️ Запуск

1. Запустить `Start.bat`
2. Нажать Enter (или выбрать [3] для настройки)
3. Если в Config.ini включен Kobold то он будет запущен
5. Запустится приложение Hermes Agent

## ⚙️ Требования

- Windows 10/11 x64
- NVIDIA/AMD/Intel GPU с поддержкой Vulkan/CUDA/ROCm
- ~27GB свободного места (для полной установки)
- Интернет-соединение для первичной загрузки

## 📄 Лицензии

Составляющие проекта имеют свои лицензии:
- 🤖 Hermes: Nous Research
- 🎮 KoboldCpp: AGPL-3.0
- 📦 Скрипты: MIT (RafStudio)
