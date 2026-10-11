#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# i18n_sync_refs.py — синхронизация ЭТАЛОНОВ локализации из репозитория Hermes.
#
# ЭТАЛОНЫ (scripts/):
#   en-locale/    en.ts + ВСЕ модули en_*.ts + en-constants.ts (settings/constants.ts)
#   upstream-locale/  ru.ts (апстримный) + ru_*.ts — база схемы A (наш слой вычитает их переводы)
#
# Зачем: с версии ~1.0 апстрим разбил словарь на модули (en_app_tour.ts, en_boot.ts, ...),
# и главный en.ts подключает их как `boot: enBoot.boot` / `...enNotices`. Если копировать
# только en.ts, инструменты не видят ~500 ключей и показывают ложные «дыры».
#
# Использование:
#   python scripts/py/i18n_sync_refs.py [--quiet]
import argparse
import glob
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)
ROOT = os.path.dirname(SCRIPTS)
REPO = os.path.join(ROOT, "data", "hermes", "hermes-agent")
I18N = os.path.join(REPO, "apps", "desktop", "src", "i18n")
SETTINGS = os.path.join(REPO, "apps", "desktop", "src", "app", "settings")
EN_DIR = os.path.join(SCRIPTS, "en-locale")
UP_DIR = os.path.join(SCRIPTS, "upstream-locale")


def copy(src, dst, log):
    if not os.path.exists(src):
        log.append(("нет", os.path.basename(src), src))
        return False
    same = os.path.exists(dst) and os.path.getsize(src) == os.path.getsize(dst)
    shutil.copy2(src, dst)
    log.append(("=" if same else "+", os.path.basename(dst), dst))
    return True


def git_show_to(rel, dst, log):
    """Пишет файл из git HEAD (апстримное состояние) в dst.

    Апстримный ru.ts обязательно берём из git: в рабочем дереве на его месте
    лежит НАШ файл (его подменяет InstallOrUpdate-RU.bat), и по рабочему дереву
    база схемы A получилась бы нашей же."""
    p = subprocess.run(["git", "-C", REPO, "show", "HEAD:" + rel],
                       capture_output=True)
    if p.returncode != 0:
        log.append(("нет", os.path.basename(rel), "git show HEAD:%s" % rel))
        return False
    old = open(dst, "rb").read() if os.path.exists(dst) else None
    same = old == p.stdout
    with open(dst, "wb") as f:
        f.write(p.stdout)
    log.append(("=" if same else "+", os.path.basename(dst), dst))
    return True


def main():
    ap = argparse.ArgumentParser(description="Синхронизация эталонов локализации из репозитория Hermes")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args()

    for d in (EN_DIR, UP_DIR):
        os.makedirs(d, exist_ok=True)

    if not os.path.isdir(I18N):
        print("[ОШИБКА] не найден %s" % I18N)
        return 1

    # --- чистим старые модули (могли исчезнуть в новой версии) ---
    old_en = {os.path.basename(p) for p in glob.glob(os.path.join(EN_DIR, "en_*.ts"))}
    old_up = {os.path.basename(p) for p in glob.glob(os.path.join(UP_DIR, "ru_*.ts"))}
    for p in glob.glob(os.path.join(EN_DIR, "en_*.ts")) + glob.glob(os.path.join(UP_DIR, "ru_*.ts")):
        os.remove(p)

    log = []
    # --- en.ts + модули ---
    copy(os.path.join(I18N, "en.ts"), os.path.join(EN_DIR, "en.ts"), log)
    copied_en = set()
    for p in sorted(glob.glob(os.path.join(I18N, "en_*.ts"))):
        copied_en.add(os.path.basename(p))
        copy(p, os.path.join(EN_DIR, os.path.basename(p)), log)
    # --- эталон констант ---
    copy(os.path.join(SETTINGS, "constants.ts"), os.path.join(EN_DIR, "en-constants.ts"), log)
    # --- апстримный ru (база схемы A) — строго из git HEAD ---
    git_show_to("apps/desktop/src/i18n/ru.ts", os.path.join(UP_DIR, "ru.ts"), log)
    copied_up = set()
    for name in sorted(os.path.basename(p) for p in glob.glob(os.path.join(I18N, "ru_*.ts"))):
        copied_up.add(name)
        git_show_to("apps/desktop/src/i18n/" + name, os.path.join(UP_DIR, name), log)
    removed = sorted((old_en - copied_en) | (old_up - copied_up))

    if not args.quiet:
        for mark, name, path in log:
            if mark == "нет":
                print("  !  нет файла: %s" % path)
            elif mark == "+":
                print("  +  обновлён: %s" % name)
            else:
                print("  =  без изменений: %s" % name)
        if removed:
            print("  -  устаревшие модули убраны: %s" % ", ".join(sorted(removed)))
        print("  ИТОГ: эталонов %d (en-locale + upstream-locale)" % len(log))
    return 0


if __name__ == "__main__":
    sys.exit(main())
