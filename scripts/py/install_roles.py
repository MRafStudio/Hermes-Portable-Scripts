# install_roles.py — инжекция ролей (scripts\roles\*.yaml) в config.yaml через hermes config set
# Вызов: python install_roles.py [--root <ROOT_DIR>] [--profile <имя>]
# Логика: для каждого файла roles\<имя>.yaml: если agent.personalities.<имя> ОТСУТСТВУЕТ в config.yaml — установить.
# ВАЖНО: config.yaml НЕЛЬЗЯ править напрямую (ручной парсинг/запись YAML ломает конфиг) -
# только штатные hermes config get/set/unset!
# Перед ПЕРВЫМ изменением config.yaml создаётся бэкап в <HERMES_HOME>\.backup\ГГГГ.ММ.ДД ЧЧ-ММ.yaml
# (всегда можно откатить).
import os, subprocess, sys, glob, shutil, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
args = sys.argv[1:]
if "--root" in args:
    ROOT = args[args.index("--root") + 1]
PROFILE = None
if "--profile" in args:
    PROFILE = args[args.index("--profile") + 1]

ROLES_DIR = os.path.join(ROOT, "scripts", "roles")
HERMES_HOME = os.path.join(ROOT, "data", "hermes")
HERMES_BIN = os.path.join(HERMES_HOME, "hermes-agent", "venv", "Scripts", "hermes.exe")
BACKUP_DIR = os.path.join(HERMES_HOME, ".backup")

backup_done = False


def backup_config():
    """Бэкап config.yaml в .backup перед первым изменением (точка отката)."""
    global backup_done
    if backup_done:
        return
    backup_done = True
    cfg = os.path.join(HERMES_HOME, "config.yaml")
    if not os.path.isfile(cfg):
        return
    try:
        os.makedirs(BACKUP_DIR, exist_ok=True)
        name = datetime.datetime.now().strftime("%Y.%m.%d %H-%M") + ".yaml"
        dst = os.path.join(BACKUP_DIR, name)
        if os.path.isfile(dst):
            name = datetime.datetime.now().strftime("%Y.%m.%d %H-%M-%S") + ".yaml"
            dst = os.path.join(BACKUP_DIR, name)
        shutil.copy2(cfg, dst)
        print(f"[roles] бэкап config.yaml -> .backup\\{name}")
    except Exception as e:
        print(f"[roles] ВНИМАНИЕ: бэкап config.yaml не создан: {e}")


def hermes(args):
    cmd = [HERMES_BIN]
    if PROFILE:
        cmd += ["-p", PROFILE]
    cmd += args
    env = dict(os.environ)
    env["HERMES_HOME"] = HERMES_HOME
    try:
        r = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8",
                           errors="replace", timeout=60)
        return (r.stdout or "").strip(), r.returncode
    except Exception as e:
        return str(e), -1


def main():
    if not os.path.isfile(HERMES_BIN):
        print(f"[roles] hermes.exe не найден: {HERMES_BIN}")
        return 1
    if not os.path.isdir(ROLES_DIR):
        print(f"[roles] каталог ролей не найден: {ROLES_DIR}")
        return 1
    files = sorted(glob.glob(os.path.join(ROLES_DIR, "*.yaml")))
    if not files:
        print("[roles] файлов ролей (*.yaml) нет")
        return 0
    added, skipped, err = 0, 0, 0
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]
        text = open(f, encoding="utf-8").read().strip()
        out, rc = hermes(["config", "get", f"agent.personalities.{name}"])
        if out and out not in ("null", "None"):
            print(f"[roles] {name}: уже есть — пропущено")
            skipped += 1
            continue
        backup_config()  # бэкап ПЕРЕД первым изменением конфига
        out2, rc2 = hermes(["config", "set", f"agent.personalities.{name}", text])
        if rc2 == 0:
            print(f"[roles] {name}: ИНЖЕКТИРОВАНА в config.yaml")
            added += 1
        else:
            print(f"[roles] {name}: ОШИБКА set (rc={rc2}): {out2[:200]}")
            err += 1
    print(f"[roles] итог: добавлено={added}, пропущено={skipped}, ошибок={err}")
    return 1 if err else 0


if __name__ == "__main__":
    sys.exit(main())
