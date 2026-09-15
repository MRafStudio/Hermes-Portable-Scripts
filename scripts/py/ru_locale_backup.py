#!/usr/bin/env python3
# ru_locale_backup.py — бэкап и откат рабочего состояния русификации Hermes.
#
# Зачем: Rebuild-Desktop.bat ПЕРЕД сборкой удаляет release (rmdir /s /q release).
# Если npm run pack упадёт — рабочей сборки не остаётся. Поэтому перед сборкой
# делаем бэкап: файлы локализации (копия) + готовая сборка (мгновенное переименование).
#
# Команды:
#   backup [--files-only] [--quiet]  — сделать бэкап (файлы + сборка)
#   restore [--quiet]                — откатить к последнему бэкапу
#   status [--quiet]                 — состояние бэкапа
#
# Каталоги бэкапа (внутри data\, вне git):
#   data\backup\ru-locale\        — файлы локализации + manifest.json
#   data\backup\desktop-release\  — переименованная рабочая сборка (release)
import argparse
import json
import os
import shutil
import sys
import time

# Корень portable-установки: .../scripts/py/ru_locale_backup.py -> .../
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
DATA = os.path.join(ROOT, "data")
SCRIPTS = os.path.join(ROOT, "scripts")
REPO = os.path.join(DATA, "hermes", "hermes-agent")
DESKTOP = os.path.join(REPO, "apps", "desktop")

BACKUP_FILES = os.path.join(DATA, "backup", "ru-locale")
BACKUP_BUILD = os.path.join(DATA, "backup", "desktop-release")
MANIFEST = os.path.join(BACKUP_FILES, "manifest.json")

# what: (исходный путь в проекте, имя файла в бэкапе)
TARGETS = [
    ("ru-locale/ru.ts", os.path.join(SCRIPTS, "ru-locale", "ru.ts")),
    ("ru-locale/ru-constants.ts", os.path.join(SCRIPTS, "ru-locale", "ru-constants.ts")),
    ("i18n/ru.ts", os.path.join(DESKTOP, "src", "i18n", "ru.ts")),
    ("i18n/languages.ts", os.path.join(DESKTOP, "src", "i18n", "languages.ts")),
    ("i18n/catalog.ts", os.path.join(DESKTOP, "src", "i18n", "catalog.ts")),
    ("i18n/types.ts", os.path.join(DESKTOP, "src", "i18n", "types.ts")),
    ("settings/ru-constants.ts", os.path.join(DESKTOP, "src", "app", "settings", "ru-constants.ts")),
]

RELEASE = os.path.join(DESKTOP, "release")
CR, LF = chr(13), chr(10)


def flat_name(rel):
    return rel.replace("/", "__")


def log(quiet, msg):
    if not quiet:
        print(msg)


def do_backup(args):
    os.makedirs(BACKUP_FILES, exist_ok=True)
    saved = []
    for rel, src_path in TARGETS:
        if not os.path.exists(src_path):
            log(args.quiet, "  .   нет файла (пропуск): %s" % src_path)
            continue
        dst = os.path.join(BACKUP_FILES, flat_name(rel))
        shutil.copyfile(src_path, dst)
        saved.append({"rel": rel, "src": src_path, "dst": dst, "size": os.path.getsize(dst)})

    build_backed = False
    if not args.files_only:
        if os.path.isdir(RELEASE):
            if os.path.isdir(BACKUP_BUILD):
                shutil.rmtree(BACKUP_BUILD, ignore_errors=True)
            try:
                os.rename(RELEASE, BACKUP_BUILD)
                build_backed = True
                log(args.quiet, "  +   Сборка сохранена: %s" % BACKUP_BUILD)
            except OSError as exc:
                log(args.quiet, "  !   НЕ удалось сохранить сборку (Hermes запущен?): %s" % exc)
                log(args.quiet, "      Закройте Hermes Desktop и повторите — иначе при сбое сборки откат невозможен.")
        else:
            log(args.quiet, "  .   Сборка release не найдена — нечего сохранять.")

    manifest = {
        "created": time.strftime("%Y-%m-%d %H:%M:%S"),
        "epoch": int(time.time()),
        "files": saved,
        "build_backed": build_backed,
        "build_backup": BACKUP_BUILD if build_backed else "",
        "release": RELEASE,
    }
    with open(MANIFEST, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    log(args.quiet, "  +   Бэкап готов: %d файлов%s" %
        (len(saved), ", сборка сохранена" if build_backed else ", БЕЗ сборки"))
    return 0 if (build_backed or args.files_only) else 2


def do_restore(args):
    if not os.path.exists(MANIFEST):
        log(args.quiet, "  [ОШИБКА] Бэкап не найден: %s" % MANIFEST)
        return 1
    with open(MANIFEST, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    restored = 0
    for item in manifest.get("files", []):
        dst = item.get("dst")
        src = item.get("src")
        if not dst or not os.path.exists(dst):
            continue
        os.makedirs(os.path.dirname(src), exist_ok=True)
        shutil.copyfile(dst, src)
        restored += 1
        log(args.quiet, "  +   Восстановлен: %s" % src)

    build_restored = False
    if manifest.get("build_backed") and os.path.isdir(BACKUP_BUILD):
        if os.path.isdir(RELEASE):
            shutil.rmtree(RELEASE, ignore_errors=True)
        try:
            os.rename(BACKUP_BUILD, RELEASE)
            build_restored = True
            log(args.quiet, "  +   Сборка восстановлена: %s" % RELEASE)
        except OSError as exc:
            log(args.quiet, "  !   НЕ удалось восстановить сборку: %s" % exc)
    elif not manifest.get("build_backed"):
        log(args.quiet, "  .   В бэкапе нет сборки — восстановлены только файлы локализации.")
        log(args.quiet, "      Чтобы применить их, запустите пересборку Desktop.")

    log(args.quiet, "  +   Откат выполнен: %d файлов%s" %
        (restored, ", сборка возвращена" if build_restored else ""))
    return 0 if restored else 1


def do_status(args):
    if not os.path.exists(MANIFEST):
        log(args.quiet, "  .   Бэкапа нет (%s)" % MANIFEST)
        return 1
    with open(MANIFEST, "r", encoding="utf-8") as f:
        manifest = json.load(f)
    log(args.quiet, "  Бэкап от: %s" % manifest.get("created", "?"))
    log(args.quiet, "  Файлов:   %d" % len(manifest.get("files", [])))
    log(args.quiet, "  Сборка:   %s" % ("сохранена" if manifest.get("build_backed") else "нет"))
    log(args.quiet, "  Каталог:  %s" % BACKUP_FILES)
    return 0


def main():
    ap = argparse.ArgumentParser(description="Бэкап/откат русификации Hermes")
    ap.add_argument("command", choices=["backup", "restore", "status"])
    ap.add_argument("--files-only", action="store_true", help="не трогать сборку (только файлы)")
    ap.add_argument("--quiet", action="store_true", help="меньше вывода")
    args = ap.parse_args()

    if args.command == "backup":
        return do_backup(args)
    if args.command == "restore":
        return do_restore(args)
    return do_status(args)


if __name__ == "__main__":
    sys.exit(main())
