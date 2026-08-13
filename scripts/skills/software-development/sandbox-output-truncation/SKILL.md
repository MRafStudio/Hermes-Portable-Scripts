---
name: sandbox-output-truncation
description: Use when output seems truncated. Verify via file/hex.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  tags: [debugging, sandbox, powershell, output, truncation]
  related_skills: [windows-scripting, windows-batch-scripting, systematic-debugging]
---

# Обрезание вывода консоли sandbox (ложные «баги»)

## When to Use

- Вывод команд в sandbox выглядит обрезанным (потеряны хвосты строк, `]`, кавычки).
- Результаты тестов противоречат друг другу (Match True / Replace «не работает»).
- Один и тот же код «то работает, то нет» при неизменных входных данных.

## Симптом

- Вывод `print()` / `subprocess` capture в sandbox **обрезается** на определённой подстроке — например, на `***`.
- Результаты тестов **противоречат** друг другу: `[regex]::Match` находит, а `[regex]::Replace` «не заменяет»; тот же код то работает, то нет.
- Строки в выводе теряют хвост (закрывающие `]`, `"`, куски текста) — при этом сами данные целы.

## Реальный случай (2026-08, Hermes Portable)

Отладка `memos-fix.ps1`: regex замены `apiKey: ***` на `apiKey: "sk-..."` «не срабатывал» в 7+ прогонах PS-тестов. Match — True, Replace — «без изменений». Потрачено ~40 минут на поиск «бага .NET regex в PS 5.1». Правда: **regex работал с первого раза** — python-`print` sandbox обрезал вывод на подстроке `***`, и видимый текст `apiKey: ***` был усечённой версией реального `apiKey: "sk-TEST..."`.

## Процедура диагностики (когда вывод противоречив)

1. **Не доверяй print/console-выводу** — дампни результат в файл и прочитай файл:
   - PS: `[System.IO.File]::WriteAllText($out, $data, (New-Object System.Text.UTF8Encoding $false))`
   - Python: `open(path,'w',encoding='utf-8').write(data)`
2. **Смотри байты/hex** — невидимые отличия видны только так:
   - `repr(line)` / `line.hex()` — если текст выглядит одинаково, а hex разный — данные разные.
3. **diff оригинал vs результат** — покажет, чем реально отличаются файлы (BOM, пробелы, хвосты).
4. Только после hex/diff-подтверждения делай вывод о «баге».

## Pitfalls

- `***` в выводимой строке — классический триггер обрезания в этом окружении. Строки с `***` в print выглядят усечёнными ВСЕГДА.
- Кириллица в PS-выводе через `subprocess text=True` — кодировка консоли PS 5.1 (cp866/OEM) vs utf-8: выводи `repr()` сырых байт (`capture_output=True` без text, потом `r.stdout.decode(..., errors='replace')`).
- Не «чини» рабочий код из-за обрезанного вывода — сначала проверь канал вывода (файл/hex).

## Верификация фикса

- После правки PS/проверки regex: записать результат во временный файл, прочитать его из python, проверить hex целевой строки и валидность (pyyaml для YAML, node для JSON).
- Удалить временные файлы после проверки.
