# MSYS backslash stripping — разбор инцидента (2026-08-12)

## Симптом

- `ls -l D:\NEURO\Hermes\data\home\Projects` → `ls: cannot access 'D:NEUROHermesdatahomeProjects': No such file or directory`
- `rm -rf D:\NEURO\Hermes\data\home\Projects/*` → exit 0, но каталог **не очищен** (файлы остались).
- Пользователь подтверждает: каталог существует, но «куча файлов так и осталась».
- `pwd` → `/d/NEURO/Hermes/data/home` (MSYS-стиль работает).

## Корень причины

1. В git-bash (MSYS) обратный слеш `\` — **escape-символ**, а не разделитель пути.
   `D:\NEURO\Hermes\data\home` → bash съедает слеши → `D:NEUROHermesdatahome`.
   Строка без кавычек/с `\\` в двойных кавычках теряет слеши ещё до передачи в команду.
2. `rm -rf` с флагом `-f` на **несуществующем** пути не ругается и возвращает 0 —
   «успех», который ничего не сделал. Одного exit code недостаточно.

## Почему команда «успешно» не удалила

`rm -rf -f <несуществующий-путь>/*` → bash не нашёл glob-совпадений, передал
литеральный путь, `rm -f` проигнорировал отсутствие файла → exit 0.

## Рабочее решение

```bash
find /d/NEURO/Hermes/data/home/Projects -mindepth 1 -delete && ls -la /d/NEURO/Hermes/data/home/Projects
```

- `find -delete` чистит содержимое включая скрытые файлы (glob `*` их не ловит),
  сам каталог остаётся.
- Обязательная проверка `ls -la` — единственный надёжный признак очистки.

## Правильные формы пути в git-bash

| Форма | Пример | Статус |
|---|---|---|
| Обратные слеши без кавычек | `D:\NEURO\...` | ❌ слеши съедаются |
| Обратные слеши в `\\` (двойные кавычки) | `"D:\\NEURO\\..."` | ❌ тоже рискует |
| Прямые слеши | `D:/NEURO/Hermes/data/home/Projects` | ✅ |
| MSYS-стиль | `/d/NEURO/Hermes/data/home/Projects` | ✅ |
| Одинарные кавычки вокруг Windows-пути | `'D:\NEURO\Hermes\data\home\Projects'` | ✅ |
