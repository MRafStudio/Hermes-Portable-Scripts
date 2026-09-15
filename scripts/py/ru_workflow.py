#!/usr/bin/env python3
# ru_workflow.py — полный цикл русификации Hermes Desktop (RU-WORKFLOW.md, шаги 1-7).
# Боевая пересборка release СЮДА НЕ ВХОДИТ: её спрашивает Tools.bat [10] в конце.
#
#   [1/7] эталоны          en.ts + constants.ts из репозитория -> scripts/en-locale
#   [2/7] зеркало ru.ts    i18n_mirror.py (полнота + порядок, 1:1 построчно)
#   [3/7] зеркало констант i18n_mirror_constants.py
#   [4/7] регистрация языка (languages.ts / catalog.ts)
#   [5/7] проверка         i18n_verify.py (структура + esbuild + порядок + константы)
#   [6/7] копирование в репозиторий (src/i18n, src/app/settings)
#   [7/7] тестовая сборка Electron (npm run build; release не трогается)
#
# Коды выхода: 0 — цикл пройден | 1 — ошибка/нужен перевод | 2 — ошибка сборки

import argparse
import hashlib
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)
ROOT = os.path.dirname(SCRIPTS)
EN_DIR = os.path.join(SCRIPTS, "en-locale")
RU_DIR = os.path.join(SCRIPTS, "ru-locale")
REPO = os.path.join(ROOT, "data", "hermes", "hermes-agent")
DESKTOP = os.path.join(REPO, "apps", "desktop")
I18N = os.path.join(DESKTOP, "src", "i18n")
SETTINGS = os.path.join(DESKTOP, "src", "app", "settings")
TEMP = os.path.join(ROOT, "data", "temp")

EN_TS = os.path.join(EN_DIR, "en.ts")
EN_CONST = os.path.join(EN_DIR, "en-constants.ts")
RU_TS = os.path.join(RU_DIR, "ru.ts")
RU_CONST = os.path.join(RU_DIR, "ru-constants.ts")

_n = [0]


def head(title):
    _n[0] += 1
    print("")
    print("=== [%d/7] %s" % (_n[0], title))
    sys.stdout.flush()


def ok(msg):
    print("  +  " + msg)
    sys.stdout.flush()


def warn(msg):
    print("  !  " + msg)
    sys.stdout.flush()


def err(msg):
    print("  X  " + msg)
    sys.stdout.flush()


def sha(path):
    try:
        with open(path, "rb") as f:
            return hashlib.sha256(f.read()).hexdigest()
    except OSError:
        return ""


def sync_file(src, dst, label):
    """Копирует эталон в scripts/*-locale, если содержимое отличается."""
    if not os.path.exists(src):
        warn("%s: нет в репозитории (%s)" % (label, src))
        return False
    if os.path.exists(dst) and sha(src) == sha(dst):
        ok("%s: эталон актуален" % label)
        return True
    shutil_copy(src, dst)
    ok("%s: эталон обновлён (%d байт)" % (label, os.path.getsize(dst)))
    return True


def shutil_copy(src, dst):
    import shutil
    shutil.copy2(src, dst)


def run_py(script, args):
    path = os.path.join(HERE, script)
    if not os.path.exists(path):
        err("не найден %s" % script)
        return 1
    cmd = [sys.executable, path] + args
    p = subprocess.run(cmd)
    return p.returncode


def read_text(path):
    try:
        with open(path, encoding="utf-8", newline="") as f:
            return f.read()
    except OSError:
        return ""


def main():
    ap = argparse.ArgumentParser(description="Полный цикл русификации Hermes Desktop")
    ap.add_argument("--skip-build", action="store_true", help="не запускать тестовую сборку Electron")
    args = ap.parse_args()

    print("")
    print("РУСИФИКАЦИЯ HERMES DESKTOP — полный цикл (RU-WORKFLOW.md)")
    print("  корень: %s" % ROOT)

    if not os.path.isdir(DESKTOP):
        err("не найден репозиторий Desktop: %s" % DESKTOP)
        return 1

    # ---------- 1) эталоны ----------
    head("Эталоны из репозитория Hermes (en.ts + constants.ts)")
    en_repo = os.path.join(I18N, "en.ts")
    if not os.path.exists(en_repo):
        err("в репозитории нет en.ts — сначала InstallOrUpdate-RU.bat")
        return 1
    sync_file(en_repo, EN_TS, "en.ts")
    sync_file(os.path.join(SETTINGS, "constants.ts"), EN_CONST, "en-constants.ts (эталон подписей полей)")

    # ---------- 2) зеркало ru.ts ----------
    head("Зеркало ru.ts (набор ключей и порядок как в en.ts)")
    rc = run_py("i18n_mirror.py", ["--en", EN_TS, "--ru", RU_TS])
    if rc != 0:
        err("не удалось построить зеркало ru.ts")
        return 1

    # ---------- 3) зеркало констант ----------
    head("Зеркало ru-constants.ts (подписи и описания полей)")
    rc = run_py("i18n_mirror_constants.py", ["--en", EN_CONST, "--ru", RU_CONST])
    if rc != 0:
        err("не удалось построить зеркало констант")
        return 1

    # ---------- 4) регистрация языка ----------
    head("Регистрация русского языка в Desktop")
    cat = read_text(os.path.join(I18N, "catalog.ts"))
    lang = read_text(os.path.join(I18N, "languages.ts"))
    have_cat = ("'./ru'" in cat) and re.search(r"^[ \t]*ru\b", cat, re.M) is not None
    have_lang = "id: 'ru'" in lang
    if have_cat and have_lang:
        ok("ru зарегистрирован (catalog.ts + languages.ts)")
    else:
        warn("регистрация ru неполная: catalog=%s, languages=%s" % (have_cat, have_lang))
        warn("русский не появится в UI: проверьте src/i18n/catalog.ts и languages.ts")

    # ---------- 5) проверка ----------
    head("Проверка русификации (структура, esbuild, порядок, константы)")
    rc = run_py("i18n_verify.py", ["--en", EN_TS, "--ru", RU_TS, "--ru-const", RU_CONST])
    if rc != 0:
        err("проверка не пройдена — правьте переводы и запускайте цикл заново")
        return 1

    # ---------- 6) копирование в репозиторий ----------
    head("Копирование файлов перевода в репозиторий Hermes")
    for src, dst, label in (
        (RU_TS, os.path.join(I18N, "ru.ts"), "ru.ts -> apps/desktop/src/i18n"),
        (RU_CONST, os.path.join(SETTINGS, "ru-constants.ts"), "ru-constants.ts -> apps/desktop/src/app/settings"),
    ):
        if not os.path.exists(src):
            err("нет файла перевода: %s" % src)
            return 1
        same = os.path.exists(dst) and sha(src) == sha(dst)
        shutil_copy(src, dst)
        ok("%s%s" % (label, " (без изменений)" if same else " (%d байт)" % os.path.getsize(dst)))

    if args.skip_build:
        print("")
        print("ИТОГ: цикл пройден (тестовая сборка пропущена по --skip-build).")
        return 0

    # ---------- 7) тестовая сборка ----------
    head("Тестовая сборка Electron (npm run build)")
    if not os.path.isdir(os.path.join(DESKTOP, "node_modules")):
        warn("нет node_modules — сборка пропущена (нужна установка зависимостей)")
        print("")
        print("ИТОГ: цикл пройден, тестовая сборка пропущена.")
        return 0
    log = os.path.join(TEMP, "ru-workflow-build.log")
    os.makedirs(TEMP, exist_ok=True)
    with open(log, "w", encoding="utf-8", newline="") as f:
        p = subprocess.run("npm run build", cwd=DESKTOP, shell=True, stdout=f, stderr=subprocess.STDOUT)
    if p.returncode != 0:
        err("тестовая сборка не прошла (exit %d)" % p.returncode)
        tail = read_text(log).splitlines()[-15:]
        for line in tail:
            print("      " + line)
        print("      лог: %s" % log)
        return 2
    ok("сборка прошла: dist собран, рабочий release не тронут")

    print("")
    print("ИТОГ: цикл пройден — локали в репозитории, Electron компилируется.")
    print("      Дальше: боевая пересборка release (бэкап + сборка + перезапуск).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
