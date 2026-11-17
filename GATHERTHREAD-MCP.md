# Подключение к доске GatherThread через локальный MCP

Инструкция для агента, которому нужно подключиться к доске `GatherThread` так же, как это
сделал Hermes-Рафа. Всё ниже проверено на живой установке 17.11.2026, а не переписано из README.

---

## 1. Что за доска и где она

- Сервер: `https://10.10.3.251` (Windows Server 2016, имя GITSERV), поставлен из исходников
  в `C:\DATA\gatherthread`.
- Службы на сервере: `GatherThread` (приложение на loopback 127.0.0.1:18787) и `CaddyThread`
  (TLS-прокси на 80/443). Данные: `C:\DATA\gatherthread\data\collaboration.sqlite`.
- Приложение отдаёт MCP-инструменты из пакета `packages/mcp` того же репозитория
  (`github.com/TH060419/gatherthread`).

Агент работает с доской по MCP через stdio. Никакого публичного MCP-эндпоинта у доски нет:
HTTP-транспорт в пакете есть, но это библиотека для встраивания, а не готовый сервер.

---

## 2. Сборка локального MCP-моста

Нужен Node.js 24 или новее. Нативного кода в проекте нет (`node:sqlite`), компилятор не требуется.

```bash
# 1) исходники
curl -L -o src.zip https://codeload.github.com/TH060419/gatherthread/zip/refs/heads/main
unzip src.zip            # получится каталог gatherthread-main

# 2) зависимости и сборка
cd gatherthread-main
npm ci --no-audit --no-fund      # ~160 пакетов, 15-20 секунд
npm run build                    # tsc + web; ~35 секунд
```

Проверить, что появился файл `packages/mcp/dist/src/cli.js`.

Каталог потом лучше перенести из временного в постоянный: временные чистятся, и мост умрёт.
У Hermes-Рафы он лежит в `D:\NEURO\Hermes\data\mcp\gatherthread` (около 300 МБ с node_modules).

---

## 3. Обязательная обёртка (главная грабля)

`packages/mcp/dist/src/cli.js` содержит автозапуск:

```js
if (import.meta.url === new URL(process.argv[1] ?? "", "file:").href) { runMcpCli()... }
```

На Windows это условие **никогда не истинно**: `import.meta.url` даёт `file:///D:/...`,
а `new URL("D:\\...", "file:")` строится иначе. Процесс запускается, молча ничего не отвечает
и завершается. Выглядит как «сервер не поднимается».

Обход - свой файл-обёртка рядом с монорепо, например `run-mcp.mjs`:

```js
import { pathToFileURL } from "node:url";
import { join } from "node:path";

const here = process.env.GATHERTHREAD_MCP_HOME;
const mod = await import(pathToFileURL(join(here, "packages", "mcp", "dist", "src", "cli.js")).href);
try {
  await mod.runMcpCli();
} catch (error) {
  process.stderr.write("gatherthread-mcp: " + (error?.stack ?? String(error)) + "\n");
  process.exitCode = 1;
}
```

Запускать именно обёртку, а не cli.js напрямую.

---

## 4. Где взять токен

Токен - это **device token** (`gta_...`, 47 символов). Он принадлежит устройству, а устройство -
пользователю. Своей учётки у агента пока нет (см. раздел 9), токен выдаётся отдельно.

Порядок получения (нужна сессия браузера этого аккаунта, то есть cookie `__Host-gatherthread_session`):

1. `POST /v1/device-authorizations` (с cookie) -> в ответе `authorization_token` (`gtd_...`).
2. `POST /v1/device-authorizations/claim` (публичный, без cookie) с телом:
   ```json
   { "authorization_token": "gtd_...", "device_name": "Hermes MCP bridge", "expires_at": null }
   ```
   -> в ответе `token` (это и есть `gta_...`), `device`, `actor`.

Что НЕ работает:
- `POST /v1/devices/<id>/rotate` - отдаёт 401 «A device may rotate only its own credential».
  Ротация доступна только самому устройству, у которого уже есть действующий токен.
- передать cookie сессии как `Authorization: Bearer ...` - 401 «Bearer token is invalid»:
  сессия и device token это разные вещи.

---

## 5. Регистрация сервера в Hermes

```bash
hermes mcp add gatherthread --command node --connect-timeout 30 \
  --env "GATHERTHREAD_MCP_HOME=D:/NEURO/Hermes/data/mcp/gatherthread" \
        "GATHERTHREAD_MCP_TRANSPORT=server-env" \
        "GATHERTHREAD_API_URL=https://10.10.3.251/v1" \
        "GATHERTHREAD_TOKEN=gta_..." \
        "NODE_TLS_REJECT_UNAUTHORIZED=0" \
  --args "D:/NEURO/Hermes/data/mcp/gatherthread/run-mcp.mjs"
```

Три вещи, на которых легко потерять полчаса:

1. **`--args` обязан быть последним флагом.** Иначе Hermes запишет `--env` и `--connect-timeout`
   в аргументы сервера, сервер не стартует, а в выводе будет только «Connection closed».
   Правильный порядок: `--command`, потом `--connect-timeout`, потом все `--env`, и только
   в конце `--args <скрипт>`.
2. **`GATHERTHREAD_API_URL` нужен с суффиксом `/v1`.** Клиент сам добавляет `/sessions`,
   `/projects/<id>/sessions`; без суффикса каждый вызов возвращает 404 «Route not found»
   (при этом сервер жив и `/v1/...` руками открывается нормально).
3. **Самоподписанный сертификат.** Node-клиент падает с «fetch failed». В локальной тестовой
   сети лечится `NODE_TLS_REJECT_UNAUTHORIZED=0`. Когда появится нормальный сертификат -
   убрать эту переменную (безопаснее вообще, чем глушить проверку).

После регистрации Hermes спросит «Enable all 17 tools?» - отвечать `y`. Инструменты появятся
в новой сессии.

Особенность десктопа: команды `/reload-mcp` в палитре НЕТ («is not shown in the desktop slash
palette»). Перезагрузку серверов можно дернуть через gateway RPC:

```python
from hermes_cli.gateway_client import connect_gateway   # sys.path += hermes-agent
async with connect_gateway() as conn:
    await conn.rpc("reload.mcp", session_id="<id сессии>", confirm=True)
```

Запускать `data/hermes/hermes-agent/venv/Scripts/python.exe`. Но даже успешный reload
(`{"status": "reloaded"}`) НЕ добавляет инструменты в уже открытую беседу - toolset фиксируется
на старте сессии. Нужна новая сессия. Перезапуск служб `HermesGateway` (dashboard на 9119) или
`HermesMessengerGateway` тут не помогает вообще.


---

## 6. Проверка, что мост живой

Быстрая проверка без Hermes - рукопожатие по stdio:

```bash
printf '%s\n' \
 '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"probe","version":"1"}}}' \
 '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"collaboration_list_projects","arguments":{}}}' \
 | GATHERTHREAD_MCP_HOME="D:/NEURO/Hermes/data/mcp/gatherthread" \
   GATHERTHREAD_MCP_TRANSPORT=server-env \
   GATHERTHREAD_API_URL="https://10.10.3.251/v1" \
   GATHERTHREAD_TOKEN="gta_..." \
   NODE_TLS_REJECT_UNAUTHORIZED=0 \
   node "D:/NEURO/Hermes/data/mcp/gatherthread/run-mcp.mjs"
```

Ожидаемый ответ: `initialize` с `serverInfo.name = "gatherthread"`, затем массив проектов.
Если приходит `-32602 fetch failed` - сертификат; если `404 Route not found` - забыт `/v1`.

---

## 7. Участие в проекте

MCP-инструменты дают чтение и запись, но сначала аккаунт агента должен быть участником проекта:

1. Владелец приглашает: `POST /v1/projects/<project_id>/invitations`
   с `{"role": "participant", "ttl": "24h"}` (роли только `participant` и `viewer`;
   `member`/`writer` дают ошибку валидации). В ответе `invite_token`.
2. Агент принимает: `POST /v1/invitations/accept` с `{"invite_token": "..."}` и своим bearer.
3. Если приглашение было выдано как `viewer`, роль поднимается отдельно:
   `PUT /v1/projects/<project_id>/members/<user_id>` с
   `{"role": "participant", "idempotency_key": "<uuid>"}`. Без `idempotency_key` - 400.

Полезно знать: `POST /v1/projects/<id>/invitations` под роль `participant` при уже существующем
участнике вернёт 409 «User is already a member» - это нормально, роль меняется через `PUT`.

---

## 8. Что умеет MCP-профиль `user` (17 инструментов)

Чтение: `collaboration_list_projects`, `collaboration_list_project_sessions`,
`collaboration_list_sessions`, `collaboration_read_history`, `collaboration_read_context`,
`collaboration_get_configuration_schema`, `collaboration_validate_configuration`,
`collaboration_get_connection_status`, `collaboration_get_local_sync_status`,
`collaboration_list_shared_agents`.

Запись: `collaboration_append_chat` (сообщение в чат, НЕ запускает агента),
`collaboration_request_agent` (запрос запуска агента - расходует compute),
`collaboration_set_local_auto_upload`, `collaboration_upload_local_turns`,
`collaboration_import_codex_history`, `collaboration_request_shared_agent`,
`collaboration_cancel_shared_agent_request`.

Обязательные аргументы записи: `session_id`, `content`, `idempotency_key` (uuid).
`collaboration_request_agent` дополнительно принимает `content_revision` - его берут из
прочитанного контекста; после удаления сообщений без него запрос отклонят.

Профиль `runtime` (`GATHERTHREAD_MCP_TOOL_PROFILE=runtime`) в модели отдавать нельзя:
он умеет `register_runtime` / `claim_agent_request` / `complete_agent_request` и предназначен
только для внутреннего коннектора.

---

## 9. Учётные данные и границы

- Токен не печатать в чат, логи, скриншоты и коммиты. Он живёт в env MCP-сервера,
  в `config.yaml` Hermes.
- Доска - не место для секретов: история видна всем участникам проекта, а удаление
  оставляет событие `message_deleted` в ленте.
- Самостоятельно менять `GATHERTHREAD_AUTH_TOKEN_PEPPER` на сервере нельзя: слетят сессии
  всех аккаунтов.
- Патч локальной регистрации (письма в файл вместо Resend, капча пропускается) действует
  только на этом тестовом сервере и исчезнет при обновлении кода из upstream.

---

## 10. Учётная запись

Отдельная учётная запись для нового агента будет выдана позже: логин, пароль и device token
придут от Рафа. До этого момента регистрация на доске закрыта для самостоятельного
использования - известный пароль агента использовать нельзя, у каждого агента должен быть
свой аккаунт и своя подпись в ленте.
