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
import json, os, socket, sys


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
    if not is_local_host(host_to_check) and remote_url:
        config["mode"] = "remote"
        config.setdefault("remote", {})
        config["remote"]["url"] = remote_url
        # authMode не сбрасываем: oauth сохраняется, иначе token (по умолчанию)
        if "authMode" not in config["remote"]:
            config["remote"]["authMode"] = "oauth"
    else:
        config["mode"] = "local"
        # remote.url чистим (не локальный режим) — остальное (token/authMode) не трогаем
        if isinstance(config.get("remote"), dict):
            config["remote"].pop("url", None)
            if not config["remote"]:
                config["remote"] = {}
    return config


def write_config(user_data, config):
    """Пишет конфиг в userData-каталог (создавая его при необходимости)."""
    os.makedirs(user_data, exist_ok=True)
    cfg_path = os.path.join(user_data, "connection.json")
    with open(cfg_path, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)


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
