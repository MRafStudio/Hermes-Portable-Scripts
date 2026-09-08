# scripts\py\vk_plugin_config.py — установка/проверка VK WorkSpace плагина
# Команды:
#   python vk_plugin_config.py enable  <config.yaml>   # включить плагин в plugins.enabled
#   python vk_plugin_config.py disable <config.yaml>   # выключить (убрать из plugins.enabled)
#   python vk_plugin_config.py enabled <config.yaml>   # exit 0 если включён, 1 если нет
#   python vk_plugin_config.py set-token <token> <api_url> <env_path>
#                                                        # записать VK_WORKSPACE_BOT_TOKEN в .env
#   python vk_plugin_config.py check-token <token> <api_url>
#                                                        # проверить токен через /self/get (exit 0 = ок)
#
# Правит ТОЛЬКО plugins.enabled и .env-токен. Остальные настройки — руками в .env.
import json
import sys
import urllib.parse
import urllib.request

PLUGIN_NAME = "vk-workspace-platform"
ENABLED_MARKER = "    - " + PLUGIN_NAME
DEFAULT_API_URL = "https://myteam.mail.ru/bot/v1"


def _read(path: str) -> str:
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def _write(path: str, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


# ---------- plugins.enabled ----------

def enable(path: str) -> bool:
    text = _read(path)
    if ENABLED_MARKER in text:
        return False
    marker = "  enabled:\n"
    if marker not in text:
        if "plugins:" not in text:
            raise RuntimeError("config.yaml: не найден блок 'plugins:' — правка вручную")
        text = text.replace("plugins:", "plugins:\n  enabled:\n" + ENABLED_MARKER + "\n", 1)
    else:
        text = text.replace(marker, marker + ENABLED_MARKER + "\n", 1)
    _write(path, text)
    return True


def disable(path: str) -> bool:
    text = _read(path)
    if ENABLED_MARKER not in text:
        return False
    text = text.replace(ENABLED_MARKER + "\n", "")
    _write(path, text)
    return True


def is_enabled(path: str) -> bool:
    return ENABLED_MARKER in _read(path)


# ---------- токен ----------

def set_token(token: str, api_url: str, env_path: str) -> None:
    """Записать/заменить VK_WORKSPACE_BOT_TOKEN и VK_WORKSPACE_API_URL в .env."""
    if not token:
        raise RuntimeError("пустой токен")
    text = ""
    try:
        text = _read(env_path)
    except FileNotFoundError:
        text = ""
    if text and not text.endswith("\n"):
        text += "\n"
    # заменяем существующие строки, либо добавляем
    def _upsert(block: str, key: str, value: str) -> str:
        prefix = key + "="
        changed = False
        out_lines = []
        for line in block.split("\n"):
            if line.strip().startswith(prefix) or line.strip().startswith("#" + prefix):
                out_lines.append(prefix + value)
                changed = True
            else:
                out_lines.append(line)
        block = "\n".join(out_lines)
        if not changed:
            block = block.rstrip("\n") + "\n" + prefix + value
        return block

    text = _upsert(text, "VK_WORKSPACE_BOT_TOKEN", token)
    if api_url:
        text = _upsert(text, "VK_WORKSPACE_API_URL", api_url.rstrip("/"))
    _write(env_path, text)


def read_env_token(env_path: str) -> str:
    """Прочитать VK_WORKSPACE_BOT_TOKEN из .env (значение после первого '=')."""
    try:
        for line in _read(env_path).splitlines():
            line = line.rstrip("\r")
            if line.startswith("VK_WORKSPACE_BOT_TOKEN="):
                return line.split("=", 1)[1].strip()
    except FileNotFoundError:
        pass
    return ""


def check_token(token: str, api_url: str) -> dict:
    """Проверить токен через /self/get. Возвращает dict из ответа; кидает исключение при ошибке."""
    base = (api_url or DEFAULT_API_URL).rstrip("/")
    url = f"{base}/self/get?token={urllib.parse.quote(token)}"
    with urllib.request.urlopen(url, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))


def ensure_token(new_token: str, api_url: str, env_path: str) -> int:
    """Эффективный токен: new_token, если непустой; иначе из .env. Проверяет через API.
    Если пришёл новый и он валиден — записывает в .env. Exit 0 = ок, 1 = ошибка."""
    effective = (new_token or "").strip()
    if not effective:
        effective = read_env_token(env_path)
    if not effective:
        print("NO_TOKEN: ни введённый токен, ни токен в .env не найдены", file=sys.stderr)
        return 1
    try:
        data = check_token(effective, api_url)
    except Exception as e:
        print(f"network/parse error: {e}", file=sys.stderr)
        return 1
    if not data.get("ok"):
        print("TOKEN_BAD " + str(data.get("description") or data), file=sys.stderr)
        return 1
    info = json.dumps({k: data.get(k) for k in ("nick", "userId", "firstName")}, ensure_ascii=False)
    if (new_token or "").strip():
        set_token(effective, api_url, env_path)
        print("TOKEN_OK_NEW " + info)
    else:
        print("TOKEN_OK " + info)
    return 0


def check_received(agent_log: str, platform: str = "vk_workspace", tail_lines: int = 800) -> int:
    """Сколько входящих сообщений platform поймано в хвосте agent.log (для проверки приёма)."""
    try:
        with open(agent_log, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except FileNotFoundError:
        return 0
    count = 0
    for line in lines[-tail_lines:]:
        if "inbound message:" in line and f"platform={platform}" in line:
            count += 1
    return count


def main() -> int:
    args = sys.argv[1:]
    if not args:
        print("usage: vk_plugin_config.py enable|disable|enabled|set-token|check-token ...", file=sys.stderr)
        return 2
    action = args[0]
    try:
        if action == "enable":
            print("enabled" if enable(args[1]) else "already-enabled")
            return 0
        if action == "disable":
            print("disabled" if disable(args[1]) else "already-disabled")
            return 0
        if action == "enabled":
            return 0 if is_enabled(args[1]) else 1
        if action == "set-token":
            token, api_url, env_path = args[1], args[2], args[3]
            set_token(token, api_url, env_path)
            print("token-set")
            return 0
        if action == "check-token":
            token, api_url = args[1], args[2]
            data = check_token(token, api_url)
            if data.get("ok"):
                print("TOKEN_OK " + json.dumps({k: data.get(k) for k in ("nick", "userId", "firstName")}, ensure_ascii=False))
                return 0
            print("TOKEN_BAD " + str(data.get("description") or data), file=sys.stderr)
            return 1
        if action == "received":
            agent_log = args[1]
            platform = args[2] if len(args) > 2 else "vk_workspace"
            print(str(check_received(agent_log, platform)))
            return 0
        if action == "ensure-token":
            # ensure-token <new_token> <api_url> <env_path>  (new_token может быть пустым = взять из .env)
            new_token = args[1]
            api_url = args[2]
            env_path = args[3]
            return ensure_token(new_token, api_url, env_path)
        if action == "read-env-token":
            env_path = args[1]
            t = read_env_token(env_path)
            print(t)
            return 0 if t else 1
        print(f"unknown action: {action}", file=sys.stderr)
        return 2
    except FileNotFoundError:
        print("file not found", file=sys.stderr)
        return 1
    except RuntimeError as e:
        print(str(e), file=sys.stderr)
        return 1
    except Exception as e:  # urllib/сеть
        print(f"network/parse error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
