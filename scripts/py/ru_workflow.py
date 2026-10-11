#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# ru_workflow.py — полный цикл русификации Hermes Desktop по СХЕМЕ A.
#
# Схема A: база — апстримный ru.ts (сам развивается вместе с Hermes: переводы,
# плюрализация, модули), наш файл — компактный слой ru-layer.ts с тем, чего у
# апстрима нет. Старый подход (наш единый ru.ts поверх апстримного) стирал их
# переводы и не давал их обновлений.
#
#   [1/5] эталоны   i18n_sync_refs.py — en.ts + модули en_*.ts, апстримный ru.ts из git HEAD
#   [2/5] слой      i18n_build_layer.py --install — ru-layer.ts + ru.ts (апстрим + подключение)
#   [3/5] проверка  i18n_verify.py — структура, esbuild, живые ключи, установка
#   [4/5] сводка    i18n_status.py — покрытие и дыры (сколько осталось переводить)
#   [5/5] сборка    npm run build (тестовая; release не трогается)
#
# Коды выхода: 0 — цикл пройден | 1 — ошибка/не пройдена проверка | 2 — ошибка сборки

import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.dirname(HERE)
ROOT = os.path.dirname(SCRIPTS)
REPO = os.path.join(ROOT, "data", "hermes", "hermes-agent")
DESKTOP = os.path.join(REPO, "apps", "desktop")
TEMP = os.path.join(ROOT, "data", "temp")

_n = [0]


def head(title):
    _n[0] += 1
    print("")
    print("=== [%d/5] %s" % (_n[0], title))
    sys.stdout.flush()


def run_py(script, args):
    path = os.path.join(HERE, script)
    if not os.path.exists(path):
        print("  X  не найден %s" % script)
        return 1
    p = subprocess.run([sys.executable, path] + args)
    return p.returncode


def main():
    ap = argparse.ArgumentParser(description="Полный цикл русификации Hermes Desktop (схема A)")
    ap.add_argument("--skip-build", action="store_true", help="не запускать тестовую сборку Electron")
    args = ap.parse_args()

    print("")
    print("РУСИФИКАЦИЯ HERMES DESKTOP — цикл (схема A: апстрим-база + наш слой)")
    print("  корень: %s" % ROOT)

    if not os.path.isdir(DESKTOP):
        print("  X  не найден репозиторий Desktop: %s" % DESKTOP)
        return 1

    head("Эталоны (en.ts + модули en_*.ts; апстримный ru.ts из git HEAD)")
    if run_py("i18n_sync_refs.py", []) != 0:
        print("  X  не удалось синхронизировать эталоны")
        return 1

    head("Наш слой ru-layer.ts и установка ru.ts (апстрим + подключение слоя)")
    if run_py("i18n_build_layer.py", ["--install"]) != 0:
        print("  X  не удалось собрать/установить слой")
        return 1

    head("Проверка (структура, esbuild, живые ключи, установка)")
    if run_py("i18n_verify.py", []) != 0:
        print("  X  проверка не пройдена — сборку не запускаем")
        return 1

    head("Сводка покрытия")
    run_py("i18n_status.py", ["--holes", "10"])

    if args.skip_build:
        print("")
        print("ИТОГ: цикл пройден (тестовая сборка пропущена по --skip-build).")
        return 0

    head("Тестовая сборка Electron (npm run build)")
    if not os.path.isdir(os.path.join(DESKTOP, "node_modules")):
        print("  !  нет node_modules — сборка пропущена")
        print("")
        print("ИТОГ: цикл пройден, тестовая сборка пропущена.")
        return 0
    log = os.path.join(TEMP, "ru-workflow-build.log")
    os.makedirs(TEMP, exist_ok=True)
    with open(log, "w", encoding="utf-8", newline="") as f:
        p = subprocess.run("npm run build", cwd=DESKTOP, shell=True, stdout=f,
                           stderr=subprocess.STDOUT)
    if p.returncode != 0:
        print("  X  тестовая сборка не прошла (exit %d)" % p.returncode)
        with open(log, encoding="utf-8", errors="replace") as f:
            for line in f.read().splitlines()[-15:]:
                print("      " + line)
        print("      лог: %s" % log)
        return 2
    print("  +  сборка прошла: dist собран, рабочий release не тронут")
    print("")
    print("ИТОГ: цикл пройден — локали в репозитории, Electron компилируется.")
    print("      Дальше: боевая пересборка release (Tools.bat [5]).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
