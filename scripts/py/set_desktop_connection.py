# set_desktop_connection.py — обновление connection.json (Desktop) по portable_start.ini.
#   mode='remote' (если URL не локальный) / 'local' — profile/profiles не трогаем.
#
# Аргументы:
#   sys.argv[1]    — путь к каталогу userData (основной)
#   sys.argv[2]    — REMOTE_URL из portable_start.ini (может быть пустым)
#   sys.argv[3]    — REMOTE_HOST из portable_start.ini (для проверки локальности)
#   sys.argv[4:]   — дополнительные userData-каталоги (страховка: Electron/Chromium
#                    на Windows берёт userData из %USERPROFILE%\AppData\Roaming\<app>,
#                    игнорируя переменную APPDATA — пишем в оба места)
#
# Локальный URL: 127.0.0.1, localhost, ::1 или адрес одного из локальных адаптеров
# (Get-NetIPAddress на стороне .bat передаётся через REMOTE_HOST; здесь дополнительно
# сверяемся с socket-интерфейсами).
import json, os, socket, sys, urllib.error, urllib.request


def is_local_host(host):
    """127.0.0.1 / localhost / ::1 или адрес локального адаптера."""
    h = (host or "").strip().lower()
    if h in ("", "localhost"):
        return True
    if h.startswith("127.") or h == "::1":
        return True
    # Сверка с реальными адресами локальных интерфейсов
    try:
        for info in socket.getaddrinfo(socket.gethostname(), None):
            ip = info[4][0]
            if ip and ip == h:
                return True
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            if info[4][0] == h:
                return True
    except Exception:
        pass
    return False


def gateway_is_serving(url, timeout=3.0):
    """True, если по адресу отвечает живой дашборд Hermes.

    200/401/403 означают, что порт держит именно gateway (401 — его штатный
    ответ без токена). Сетевая ошибка — порт свободен, поднимаем свой backend.
    """
    base = (url or "").rstrip("/")
    if not base:
        return False
    try:
        urllib.request.urlopen(base + "/api/profiles", timeout=timeout)
        return True
    except urllib.error.HTTPError as e:
        return e.code in (401, 403)
    except Exception:
        return False


def build_config(cfg_path, remote_url, remote_host):
    config = {"mode": "local", "remote": {}, "profiles": {}}
    if os.path.exists(cfg_path):
        try:
            with open(cfg_path, "r", encoding="utf-8") as f:
                parsed = json.load(f)
            if isinstance(parsed, dict):
                config = parsed
        except Exception:
            pass

    # Локальность: если host не передан — судим по URL; иначе по host.
    host_to_check = remote_host if remote_host else remote_url.split("//")[-1].split(":")[0] if "//" in remote_url else remote_url
    is_local = is_local_host(host_to_check)
    if remote_url and is_local and gateway_is_serving(remote_url):
        # Локальный адрес уже держит запущенная служба: свой backend Desktop
        # поднять не сможет (порт занят, а чужой токен даёт 401), поэтому
        # подключаемся к службе как к внешнему gateway — по токену на loopback
        # (публичный бинд токен не принимает, см. комментарий .bat).
        config["mode"] = "remote"
        remote_cfg = config.setdefault("remote", {})
        remote_cfg["url"] = remote_url
        remote_cfg["authMode"] = "token"
        session_token = os.environ.get("HERMES_DASHBOARD_SESSION_TOKEN", "").strip()
        if session_token:
            remote_cfg["token"] = {"value": session_token}
        elif not isinstance(remote_cfg.get("token"), dict):
            remote_cfg["token"] = {"value": ""}
    elif not is_local and remote_url:
        config["mode"] = "remote"
        config.setdefault("remote", {})
        config["remote"]["url"] = remote_url
        # Удалённое подключение — ТОЛЬКО пароль (oauth, Sign in):
        # публичный бинд не принимает ?token= (4401) — токен работает только на loopback
        config["remote"]["authMode"] = "oauth"
    else:
        config["mode"] = "local"
        # remote.url чистим (не локальный режим) — остальное (token/authMode) не трогаем
        if isinstance(config.get("remote"), dict):
            config["remote"].pop("url", None)
            if not config["remote"]:
                config["remote"] = {}
    return config


def write_registry(user_data, config):
    """Синхронизирует connections.json (v2) с выбранным режимом подключения.

    Desktop с версии 0.23 читает реестр подключений (version=2), а legacy
    connection.json остаётся только для старых сборок. Запись
    portable-gateway — наша; остальные подключения пользователя не трогаем.
    """
    reg_id = "portable-gateway"
    reg_label = "Hermes Gateway (portable)"
    path = os.path.join(user_data, "connections.json")
    registry = {
        "version": 2,
        "primary": "local",
        "launchMode": "primary",
        "lastUsed": "local",
        "connections": [{"id": "local", "kind": "local", "label": "This device"}],
    }
    if os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8-sig") as f:
                loaded = json.load(f)
            if isinstance(loaded, dict) and isinstance(loaded.get("connections"), list):
                registry = loaded
        except Exception:
            pass

    connections = [c for c in registry.get("connections", []) if isinstance(c, dict)]
    remote_cfg = config.get("remote") or {}
    if config.get("mode") == "remote" and remote_cfg.get("url"):
        token = remote_cfg.get("token")
        if isinstance(token, dict):
            token = token.get("value") or ""
        entry = {
            "id": reg_id,
            "kind": "remote",
            "label": reg_label,
            "url": remote_cfg["url"],
            "authMode": "token",
        }
        if token:
            # Desktop хранит секреты объектом {encoding, value}; строку
            # decryptDesktopSecret() отбрасывает (typeof secret !== object).
            entry["token"] = {"encoding": "plain", "value": str(token)}
        connections = [c for c in connections if c.get("id") != reg_id]
        connections.insert(0, entry)
        registry["primary"] = reg_id
        registry["lastUsed"] = reg_id
    else:
        connections = [c for c in connections if c.get("id") != reg_id]
        if not any(c.get("id") == "local" for c in connections):
            connections.insert(0, {"id": "local", "kind": "local", "label": "This device"})
        if registry.get("primary") == reg_id:
            registry["primary"] = "local"
            registry["lastUsed"] = "local"

    registry["version"] = 2
    registry.setdefault("launchMode", "primary")
    registry["connections"] = connections
    with open(path, "w", encoding="utf-8") as f:
        json.dump(registry, f, ensure_ascii=False, indent=2)


def write_config(user_data, config):
    """Пишет конфиг в userData-каталог (создавая его при необходимости)."""
    os.makedirs(user_data, exist_ok=True)
    cfg_path = os.path.join(user_data, "connection.json")
    with open(cfg_path, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)
    write_registry(user_data, config)


def main():
    if len(sys.argv) < 3:
        print("usage: set_desktop_connection.py <userData_dir> <REMOTE_URL> [REMOTE_HOST] [extra_userData_dir ...]")
        return 2
    user_data = sys.argv[1]
    remote_url = (sys.argv[2] or "").strip()
    remote_host = (sys.argv[3] if len(sys.argv) > 3 else "") or ""
    extra_dirs = [a for a in sys.argv[4:] if a and a.strip()]

    # Конфиг строим по основному каталогу (если там уже есть сохранённый remote/token — не теряем)
    config = build_config(os.path.join(user_data, "connection.json"), remote_url, remote_host)

    # Пишем во ВСЕ userData-каталоги (основной + страховочные)
    for ud in [user_data] + extra_dirs:
        try:
            write_config(ud, config)
        except Exception as e:
            print("warn: cannot write %s: %s" % (ud, e), file=sys.stderr)

    print("mode=%s url=%s" % (config["mode"], config.get("remote", {}).get("url", "")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
