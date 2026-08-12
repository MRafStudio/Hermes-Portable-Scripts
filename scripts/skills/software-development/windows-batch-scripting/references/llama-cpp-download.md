# llama.cpp download: переименованные ассеты (2026-08)

## Проблема
`releases/latest/download/llama-bin-win-cuda-13.3-x64.zip` → **404**.
llama.cpp переименовал ассеты: теперь имя содержит НОМЕР БИЛДА —
`llama-b10375-bin-win-cuda-13.3-x64.zip` (для cudart префикс другой: `cudart-llama-bin-...` — номер НЕ содержит).

## Решение (в репо: scripts/py/llama_latest_asset.py)
Получать имя ассета из GitHub API `releases/latest` и собирать URL динамически:
- python-скрипт: `json.load(urllib.request.urlopen(.../releases/latest))` → фильтр
  `name.startswith('llama-') and 'cuda-13.3-x64' in name` → печать имени (пусто при ошибке);
- .bat: `for /f "delims=" %%a in ('""%PY%" "%SCRIPTS_DIR%\py\llama_latest_asset.py""') do set "LLAMA_ASSET=%%a"`
  (ДВОЙНЫЕ кавычки — cmd /c паттерн!);
- URL: `https://github.com/ggml-org/llama.cpp/releases/latest/download/%LLAMA_ASSET%`.

Проверка актуальных имён: GitHub API (tag_name + assets) — не полагаться на старые имена.

## Прокси-фоллбэк (правило пользователя, 2026-08)
НЕ гнать ВЕСЬ трафик через прокси (медленно!): 90% скриптов ходят напрямую.
Фоллбэк — ТОЛЬКО для падающей загрузки, только для этой попытки:
```
curl -L --noproxy "*" -o file.zip URL >nul 2>&1        ← прямая попытка
if errorlevel 1 ( curl -L -x http://127.0.0.1:10809 -o file.zip URL >nul 2>&1 )  ← фоллбэк
```
Следующий запуск установщика — снова прямая попытка (прокси не запоминается).
Реализовано: InstallOrUpdate-Llama.bat (движок + cudart), Download-Electron.bat.
