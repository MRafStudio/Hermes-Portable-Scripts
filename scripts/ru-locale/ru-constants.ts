// Russian translations for field labels and descriptions.
// Used by ru.ts instead of the English defaults from constants.ts.

// Russian translations for field labels and descriptions.
// Used by ru.ts instead of the English defaults from constants.ts.

export const RU_FIELD_LABELS: Record<string, string> = {
  model: 'Модель по умолчанию',
  modelContextLength: 'Окно контекста',
  fallbackProviders: 'Резервные модели',
  toolsets: 'Включённые наборы инструментов',
  timezone: 'Часовой пояс',
  display: {
    personality: 'Личность',
    showReasoning: 'Блоки рассуждений'
  },
  agent: {
    maxTurns: 'Макс. шагов агента',
    imageInputMode: 'Вложения изображений',
    apiMaxRetries: 'Повторы API',
    serviceTier: 'Уровень сервиса',
    toolUseEnforcement: 'Принудительное использование инструментов'
  },
  terminal: {
    cwd: 'Рабочая директория',
    backend: 'Бэкенд выполнения',
    timeout: 'Тайм-аут команды',
    persistentShell: 'Постоянная оболочка',
    envPassthrough: 'Передача переменных окружения',
    dockerImage: 'Образ Docker',
    singularityImage: 'Образ Singularity',
    modalImage: 'Образ Modal',
    daytonaImage: 'Образ Daytona'
  },
  fileReadMaxChars: 'Лимит чтения файла',
  toolOutput: {
    maxBytes: 'Лимит вывода терминала',
    maxLines: 'Лимит страницы файла',
    maxLineLength: 'Лимит длины строки'
  },
  codeExecution: {
    mode: 'Режим выполнения кода'
  },
  approvals: {
    mode: 'Режим подтверждений',
    timeout: 'Тайм-аут подтверждения',
    mcpReloadConfirm: 'Подтверждать перезагрузку MCP'
  },
  commandAllowlist: 'Белый список команд',
  security: {
    redactSecrets: 'Скрывать секреты',
    allowPrivateUrls: 'Разрешить приватные URL'
  },
  browser: {
    allowPrivateUrls: 'Приватные URL в браузере',
    autoLocalForPrivateUrls: 'Локальный браузер для приватных URL'
  },
  checkpoints: {
    enabled: 'Контрольные точки файлов',
    maxSnapshots: 'Лимит контрольных точек'
  },
  voice: {
    recordKey: 'Горячая клавиша голоса',
    maxRecordingSeconds: 'Макс. длина записи',
    autoTts: 'Вывод ответов голосом'
  },
  stt: {
    enabled: 'Распознавание речи',
    echoTranscripts: 'Дублировать транскрипты',
    provider: 'Провайдер распознавания речи',
    local: {
      model: 'Локальная модель транскрипции',
      language: 'Язык транскрипции'
    },
    openai: {
      model: 'Модель OpenAI STT'
    },
    groq: {
      model: 'Модель Groq STT'
    },
    mistral: {
      model: 'Модель Mistral STT'
    },
    elevenlabs: {
      modelId: 'Модель ElevenLabs STT',
      languageCode: 'Язык ElevenLabs',
      tagAudioEvents: 'Тегировать аудио-события',
      diarize: 'Диаризация спикеров'
    }
  },
  tts: {
    provider: 'Провайдер синтеза речи',
    edge: {
      voice: 'Голос Edge'
    },
    openai: {
      model: 'Модель OpenAI TTS',
      voice: 'Голос OpenAI'
    },
    elevenlabs: {
      voiceId: 'Голос ElevenLabs',
      modelId: 'Модель ElevenLabs'
    },
    xai: {
      voiceId: 'Голос xAI (Grok)',
      language: 'Язык xAI'
    },
    minimax: {
      model: 'Модель MiniMax TTS',
      voiceId: 'Голос MiniMax'
    },
    mistral: {
      model: 'Модель Mistral TTS',
      voiceId: 'Голос Mistral'
    },
    gemini: {
      model: 'Модель Gemini TTS',
      voice: 'Голос Gemini'
    },
    neutts: {
      model: 'Модель NeuTTS',
      device: 'Устройство NeuTTS'
    },
    kittentts: {
      model: 'Модель KittenTTS',
      voice: 'Голос KittenTTS'
    },
    piper: {
      voice: 'Голос Piper'
    }
  },
  memory: {
    memoryEnabled: 'Постоянная память',
    userProfileEnabled: 'Профиль пользователя',
    memoryCharLimit: 'Бюджет памяти',
    userCharLimit: 'Бюджет профиля',
    provider: 'Провайдер памяти'
  },
  context: {
    engine: 'Движок контекста'
  },
  compression: {
    enabled: 'Авто-сжатие',
    threshold: 'Порог сжатия',
    targetRatio: 'Цель сжатия',
    protectLastN: 'Защищённые последние сообщения'
  },
  delegation: {
    model: 'Модель подагента',
    provider: 'Провайдер подагента',
    maxIterations: 'Лимит шагов подагента',
    maxConcurrentChildren: 'Параллельные подагенты',
    childTimeoutSeconds: 'Тайм-аут подагента',
    reasoningEffort: 'Усилие рассуждения подагента'
  },
  updates: {
    nonInteractiveLocalChanges: 'Локальные изменения при обновлении из приложения'
  }
};

export const RU_FIELD_DESCRIPTIONS: Record<string, string> = {
  model: 'Используется для новых чатов, если вы не выберете другую модель в композере.',
  modelContextLength: 'Оставьте 0, чтобы использовать обнаруженное окно контекста выбранной модели.',
  fallbackProviders: 'Резервные записи провайдер:модель для попытки, если основная модель не работает.',
  display: {
    personality: 'Стиль ассистента по умолчанию для новых сессий.',
    showReasoning: 'Показывать секции рассуждений, когда бэкенд их предоставляет.'
  },
  timezone: 'Используется, когда Hermes нужен контекст локального времени. Пустое значение использует системный часовой пояс.',
  agent: {
    imageInputMode: 'Управляет тем, как изображения-вложения отправляются в модель.',
    maxTurns: 'Верхняя граница шагов вызова инструментов перед остановкой выполнения Hermes.'
  },
  terminal: {
    cwd: 'Папка проекта по умолчанию для работы инструментов и терминала.',
    persistentShell: 'Сохранять состояние оболочки между командами, если бэкенд это поддерживает.',
    envPassthrough: 'Переменные среды для передачи в выполнение инструментов.',
    dockerImage: 'Образ контейнера, используемый при бэкенде выполнения Docker.',
    singularityImage: 'Образ, используемый при бэкенде выполнения Singularity.',
    modalImage: 'Образ, используемый при бэкенде выполнения Modal.',
    daytonaImage: 'Образ, используемый при бэкенде выполнения Daytona.'
  },
  codeExecution: {
    mode: 'Насколько строго выполнение кода ограничивается текущим проектом.'
  },
  fileReadMaxChars: 'Максимальное количество символов, которое Hermes может прочитать из одного запроса файла.',
  approvals: {
    mode: 'Как Hermes обрабатывает команды, требующие явного подтверждения.',
    timeout: 'Как долго ожидать подтверждения перед таймаутом.'
  },
  security: {
    redactSecrets: 'Скрывать обнаруженные секреты из контента, видимого модели, когда возможно.'
  },
  checkpoints: {
    enabled: 'Создавать снимки отката перед редактированием файлов.'
  },
  memory: {
    memoryEnabled: 'Сохранять устойчивые воспоминания, которые могут помочь будущим сессиям.',
    userProfileEnabled: 'Поддерживать компактный профиль предпочтений пользователя.'
  },
  context: {
    engine: 'Стратегия управления длинными разговорами вблизи лимита контекста.'
  },
  compression: {
    enabled: 'Суммировать старый контекст, когда разговоры становятся большими.'
  },
  voice: {
    autoTts: 'Автоматически озвучивать ответы ассистента.'
  },
  tts: {
    xai: {
      voiceId: 'ID голоса xAI (например, eve) или пользовательский ID голоса.',
      language: 'Код языка речи, например en.'
    },
    neutts: {
      device: 'Локальное устройство инференса для NeuTTS.'
    }
  },
  stt: {
    enabled: 'Включить локальное или провайдерское распознавание речи.',
    echoTranscripts: 'Публиковать сырые 🎙️ транскрипты голосовых сообщений обратно в чат.',
    elevenlabs: {
      languageCode: 'Опциональный код языка ISO-639-3. Пустое значение позволяет ElevenLabs автоматически определять.'
    }
  },
  updates: {
    nonInteractiveLocalChanges:
      'Когда Hermes обновляется из приложения (без терминального промпта), сохранять локальные правки исходников (stash) или отбросить их (discard). Терминальные обновления всегда спрашивают.'
  }
};