# set_desktop_token.py — запись токена удалённого доступа (dashboard session token)
# в connection.json Desktop (режим remote, authMode=token) + проверка подключения.
#
# Аргументы:
#   sys.argv[1]    — путь к каталогу userData (основной)
#   sys.argv[2]    — REMOTE_URL из portable_start.ini
#   sys.argv[3]    — REMOTE_HOST (для проверки локальности)
#   sys.argv[4]    — TOKEN (dashboard session token с сервера; пусто = только статус)
#   sys.argv[5:]   — дополнительные userData-каталоги (страховка: Electron/Chromium
#                    на Windows берёт userData из %USERPROFILE%\AppData\Roaming\<app>,
#                    игнорируя переменную APPDATA — пишем в оба места)
#
# После записи проверяет защищённый эндпоинт /api/version с заголовком
# X-Hermes-Session-Token (тот же механизм, что у Desktop) и печатает вердикт.
#
# Локальный URL: 127.0.0.1, localhost, ::1 или адрес одного из локальных адаптеров.
import json
import os
import sys
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from set_desktop_connection import is_local_host  # noqa: E402


def build_config(cfg_path, remote_url, remote_host, token):
    """Читает текущий connection.json и возвращает конфиг с применённым токеном."""
    config = {"mode": "local", "remote": {}, "profiles": {}}
    if os.path.exists(cfg_path):
        try:
            with open(cfg_path, "r", encoding="utf-8") as f:
                parsed = json.load(f)
            if isinstance(parsed, dict):
                config = parsed
        except Exception:
            pass

    host_to_check = remote_host if remote_host else remote_url.split("//")[-1].split(":")[0] if "//" in remote_url else remote_url

    if not is_local_host(host_to_check) and remote_url and token:
        config["mode"] = "remote"
        config.setdefault("remote", {})
        config["remote"]["url"] = remote_url
        config["remote"]["authMode"] = "token"
        # plain value (без encoding): decryptDesktopSecret вернёт его как есть
        config["remote"]["token"] = {"value": token}
    else:
        config["mode"] = "local"
        if isinstance(config.get("remote"), dict):
            config["remote"].pop("url", None)
            config["remote"].pop("token", None)
            if not config["remote"]:
                config["remote"] = {}
    return config


def write_config(user_data, config):
    os.makedirs(user_data, exist_ok=True)
    cfg_path = os.path.join(user_data, "connection.json")
    with open(cfg_path, "w", encoding="utf-8") as f:
        json.dump(config, f, ensure_ascii=False, indent=2)


def check_remote(base_url, token, timeout=8):
    """GET {base}/api/version с X-Hermes-Session-Token (защищённый эндпоинт).
    /api/health и /api/status публичны — по ним токен не проверить.
    Возвращает (verdict, code)."""
    url = base_url.rstrip("/") + "/api/version"
    req = urllib.request.Request(url, headers={"X-Hermes-Session-Token": token})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return "OK", r.status
    except urllib.error.HTTPError as e:
        return "HTTP_%d" % e.code, e.code
    except Exception:
        return "UNREACHABLE", 0


def main():
    if len(sys.argv) < 5:
        print("usage: set_desktop_token.py <userData_dir> <REMOTE_URL> <REMOTE_HOST> <TOKEN> [extra_userData_dir ...]")
        return 2
    user_data = sys.argv[1]
    remote_url = (sys.argv[2] or "").strip()
    remote_host = (sys.argv[3] if len(sys.argv) > 3 else "") or ""
    token = (sys.argv[4] or "").strip()
    extra_dirs = [a for a in sys.argv[5:] if a and a.strip()]

    # Без токена — только статус текущего конфига (чтение файла, без изменений)
    if not token:
        cfg = {"mode": "local", "remote": {}, "profiles": {}}
        p = os.path.join(user_data, "connection.json")
        if os.path.exists(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    parsed = json.load(f)
                if isinstance(parsed, dict):
                    cfg = parsed
            except Exception:
                pass
        rem = cfg.get("remote") or {}
        tk = rem.get("token") or {}
        print("mode=%s url=%s token=%s" % (cfg.get("mode"), rem.get("url", ""), "set" if tk.get("value") else "none"))
        return 0

    config = build_config(os.path.join(user_data, "connection.json"), remote_url, remote_host, token)

    for ud in [user_data] + extra_dirs:
        try:
            write_config(ud, config)
        except Exception as e:
            print("warn: cannot write %s: %s" % (ud, e), file=sys.stderr)

    print("mode=%s url=%s token=%s" % (config["mode"], config.get("remote", {}).get("url", ""), "set" if config.get("remote", {}).get("token") else "none"))

    # Проверка подключения (только для remote)
    if config.get("mode") == "remote" and config.get("remote", {}).get("url"):
        verdict, code = check_remote(config["remote"]["url"], token)
        if verdict == "OK":
            print("check: OK — сервер принял токен (HTTP 200)")
        elif verdict == "HTTP_401" or verdict == "HTTP_403":
            print("check: FAIL — сервер отклонил токен (%s). Токен читается сервером при старте — перезапустите сервер после смены dashboard.token." % verdict.replace("HTTP_", ""))
        elif verdict.startswith("HTTP_"):
            print("check: WARN — сервер ответил %s (endpoint /api/status). Похоже, это не Hermes dashboard или включена доп. авторизация." % verdict.replace("HTTP_", ""))
        else:
            print("check: FAIL — сервер недоступен (%s:%s). Проверьте, что сервер запущен и адрес корректен." % (remote_host, config["remote"]["url"].rsplit(":", 1)[-1] if ":" in config["remote"]["url"] else "?"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
