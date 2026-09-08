# AGENTS.md — Hermes-Portable-Scripts (инструкции для агента)

Портативная установка Hermes Agent + вспомогательные службы (HeadRoom, Llama,
Messenger Gateway) через `.bat`-скрипты в `scripts\`.

## Критичные правила (наступали на грабли — НЕ повторять!)

### .bat и кодировки (Windows)
- Любой `.bat`/`.cmd`/`.iss` — СТРОГО CRLF. `write_file` пишет LF → после правки
  `.bat` ОБЯЗАТЕЛЬНО нормализовать CRLF (python: `d.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n')`).
  Иначе cmd ломается ('... is not recognized').
- НЕ редактировать `.bat` через `patch`, если внутри строки есть Windows-пути с
  `\a`, `\r`, `\n` (в `\app`, `\release`, `\resources`): patch-механизм может
  интерпретировать их как управляющие символы и порвать путь на несколько строк.
  Для таких правок — переписывать блок целиком через отдельный python-скрипт
  (raw-строки) и проверять результат построчно.

### Службы через NSSM (установка/удаление/запуск)
- **После `nssm install` ОБЯЗАТЕЛЬНО `nssm start "<имя>"`** — иначе служба стоит
  `Automatic`, но стартует ТОЛЬКО при загрузке Windows, а «сейчас» не поднимется.
  (Реальный косяк: HermesMessengerGateway установилась, но не запустилась сразу.)
- **При удалении: СНАЧАЛА `nssm stop "<имя>"`, ПОТОМ `nssm remove`**. Некорректно
  сносить работающую службу без остановки.
- **Имена служб с пробелами/скобками** (`HermesGateway (D:_NEURO_Hermes)`) могут
  падать в `nssm start` / `Start-Service` с «OpenService: 2 / не найдена», хотя
  `Get-Service` их видит. Надёжный пуск из не-админского контекста:
  `powershell -NoProfile -Command "Start-Process powershell -Verb RunAs ... Start-Service '<имя>'"`.
- Hermes-службы ставятся/снимаются/перезапускаются ПАРАМИ (один инстанс = 2 службы):
  - `HermesGateway (%ROOT_DIR:\=_%)` — dashboard (`hermes dashboard --host --port --skip-build`)
  - `HermesMessengerGateway (%ROOT_DIR:\=_%)` — единый шлюз ВСЕХ платформ-мессенджеров
    (`hermes gateway run --replace`). VK/Telegram/ntfy — это плагины, gateway видит их сам
    из конфига, НЕ «зашиваются» в службу. Обе `SERVICE_AUTO_START`, тот же изолированный env.
- Файлы, управляющие службами: `Install-Hermes-Service.bat`, `Remove-Hermes-Service.bat`,
  `Restart-Hermes-Service.bat`. Установка службы = `InstallOrUpdate.bat → [4]`.

### Изолированное окружение служб
Службам Hermes задаётся изолированный env (иначе не найдут свои данные):
`HERMES_HOME`, `HOME`, `USERPROFILE`, `APPDATA`, `LOCALAPPDATA`, `MEMOS_HOME`,
`TEMP`, `PYTHONIOENCODING=utf-8`. AppDirectory = `%HERMES_HOME%`.

### web_dist (dashboard-служба)
`hermes dashboard` ищет web UI ТОЛЬКО в `hermes-agent\hermes_cli\web_dist\index.html`.
При запущенной Desktop-сборке его нет → НЕ падать с ошибкой, а копировать готовый
dist из `apps\desktop\release\win-unpacked\resources\app.asar.unpacked\dist\`
в `hermes_cli\web_dist\`. Обе проверки (ранняя и в установке) должны это делать.

### VK WorkSpace плагин
- Репозиторий плагина: `MRafStudio/hermes-vk-workspace` (клон для разработки на диске E:,
  НО установка идёт С GitHub, не с E:!). Скрипт `InstallOrUpdate-VkWorkspace.bat` качает
  zip codeload (`/zip/refs/heads/main`), распаковывает `plugin\` (3 файла: adapter.py,
  plugin.yaml, __init__.py) в `data\hermes\plugins\vk_workspace\`, запрашивает и проверяет
  токен бота (через `self/get`), включает плагин, предлагает приватность (allowlist).
- Службу шлюза этот скрипт НЕ трогает — она живёт вместе со службой Hermes.
