# -*- coding: utf-8 -*-
# test_ps1_patchers.py — проверка трёх патчеров patch_*.ps1:
#  1) нормализует сами .ps1 (UTF-8 BOM + CRLF) — PS 5.1 иначе портит кириллицу
#  2) делает "состаренные" копии types.ts / languages.ts / catalog.ts (как апстрим без ru)
#  3) прогоняет патчеры на копиях (должны вставить ru) — и на оригиналах (должны сказать already)
#  4) сверяет пропатченные копии с оригиналами (должны совпасть) + esbuild-синтаксис
import os
import re
import shutil
import subprocess
import sys

ROOT = "D:/NEURO/Hermes"
PSDIR = os.path.join(ROOT, "scripts", "ps1")
I18N = os.path.join(ROOT, "data", "hermes", "hermes-agent", "apps", "desktop", "src", "i18n")
TMP = os.path.join(ROOT, "data", "temp", "ps1test")
ESBUILD = os.path.join(ROOT, "data", "hermes", "hermes-agent", "node_modules",
                       "@esbuild", "win32-x64", "esbuild.exe")
CR, LF, BY = chr(13), chr(10), chr(92)
NL = CR + LF
BOM = chr(0xEF) + chr(0xBB) + chr(0xBF)

failures = []


def say(msg):
    print(msg)
    sys.stdout.flush()


# ---------- 1) нормализация .ps1 ----------
say("=== 1) нормализация .ps1 (BOM + CRLF) ===")
for name in ("patch_types.ps1", "patch_languages.ps1", "patch_catalog.ps1"):
    p = os.path.join(PSDIR, name)
    with open(p, "rb") as f:
        raw = f.read()
    while raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    body = raw.decode("utf-8").lstrip("\ufeff").replace(CR + LF, LF).replace(CR, LF).replace(LF, NL)
    with open(p, "wb") as f:
        f.write(b"\xef\xbb\xbf" + body.encode("utf-8"))
    say("  + %s: BOM + CRLF (%d байт)" % (name, 3 + len(body.encode("utf-8"))))

# ---------- 2) состаренные копии ----------
say("")
say("=== 2) состаренные копии (как апстрим без ru) ===")
if os.path.isdir(TMP):
    shutil.rmtree(TMP)
os.makedirs(TMP)


def read(p):
    with open(p, encoding="utf-8", newline="") as f:
        return f.read()


def write(p, s):
    with open(p, "w", encoding="utf-8", newline="") as f:
        f.write(s)


# types.ts: убрать " | 'ru'" из union
t = read(os.path.join(I18N, "types.ts"))
t_old = re.sub(r" \| 'ru'", "", t, count=1)
if t_old == t:
    failures.append("types.ts: не найден ' | 'ru'' для состаривания")
write(os.path.join(TMP, "types.ts"), t_old)

# languages.ts: убрать блок ru в LOCALE_OPTIONS и ru-алиасы
l = read(os.path.join(I18N, "languages.ts"))
l_old = l
i = l_old.find("    id: 'ru',")
if i < 0:
    failures.append("languages.ts: не найден блок id: 'ru' для состаривания")
else:
    start = l_old.rfind("  {", 0, i)
    end = l_old.find("  }", i)
    if end < 0:
        failures.append("languages.ts: не найден конец блока ru")
    else:
        end += 3
        if l_old[end:end + 1] == ",":
            end += 1
        if l_old[start - 2:start] == NL:
            start -= 2
        l_old = l_old[:start] + l_old[end:]
j = l_old.find("  ru: 'ru',")
if j < 0:
    failures.append("languages.ts: не найден блок ru-алиасов для состаривания")
else:
    k = l_old.find("руский: 'ru'", j)
    if k < 0:
        failures.append("languages.ts: не найден конец ru-алиасов")
    else:
        k += len("руский: 'ru'")
        if l_old[k:k + 1] == ",":
            k += 1
        if l_old[k:k + 2] == NL:
            k += 2
        if l_old[j - 2:j] == NL:
            j -= 2
        l_old = l_old[:j] + l_old[k:]
if "id: 'ru'" in l_old or "руский" in l_old:
    failures.append("languages.ts: не удалось состарить (ru остался)")
# как в апстриме: перед '] as const' и перед закрывающей '}' блока алиасов пустых строк нет
l_old = re.sub(r"\r?\n\r?\n(\] as const)", "\r\n\\1", l_old)
l_old = re.sub(r"\r?\n\r?\n(\}\r?\n\r?\nexport function isLocale)", "\r\n\\1", l_old)
write(os.path.join(TMP, "languages.ts"), l_old)

# catalog.ts: убрать импорт и элемент (учитываем и LF, и CRLF)
c = read(os.path.join(I18N, "catalog.ts"))
c_old = c.replace("import { ru } from './ru'" + NL, "").replace("import { ru } from './ru'" + LF, "")
c_old = c_old.replace(NL + "  ru" + NL, NL, 1).replace(LF + "  ru" + LF, LF, 1)
c_old = c_old.replace("," + NL + "}", NL + "}", 1).replace("," + LF + "}", LF + "}", 1)
if "ru" in c_old and "./ru" in c_old:
    failures.append("catalog.ts: не удалось состарить (import ru остался)")
write(os.path.join(TMP, "catalog.ts"), c_old)
say("  + копии созданы: %s" % ", ".join(sorted(os.listdir(TMP))))

# ---------- 3) прогон патчеров ----------
say("")
say("=== 3) патчеры на состаренных копиях (ожидаем exit 0 = вставил) ===")
pairs = [("patch_types.ps1", "types.ts"), ("patch_languages.ps1", "languages.ts"),
         ("patch_catalog.ps1", "catalog.ts")]
for script, target in pairs:
    cmd = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
           os.path.join(PSDIR, script).replace("/", BY), "-FilePath",
           os.path.join(TMP, target).replace("/", BY)]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = (r.stdout or "").strip() + " " + (r.stderr or "").strip()
    say("  %-22s exit=%d  %s" % (script, r.returncode, out[:110]))
    if r.returncode != 0:
        failures.append("%s на состаренной копии вернул %d (ожидался 0)" % (script, r.returncode))

say("")
say("=== 3b) патчеры на оригиналах (ожидаем exit 1 = already) ===")
for script, target in pairs:
    cmd = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
           os.path.join(PSDIR, script).replace("/", BY), "-FilePath",
           os.path.join(I18N, target).replace("/", BY)]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    out = (r.stdout or "").strip() + " " + (r.stderr or "").strip()
    say("  %-22s exit=%d  %s" % (script, r.returncode, out[:110]))
    if r.returncode != 1:
        failures.append("%s на оригинале вернул %d (ожидался 1 = already)" % (script, r.returncode))

# ---------- 4) сверка с оригиналами + esbuild ----------
say("")
say("=== 4) пропатченные копии против оригиналов ===")
for target in ("types.ts", "languages.ts", "catalog.ts"):
    a = read(os.path.join(TMP, target))
    b = read(os.path.join(I18N, target))
    a_n = a.replace(CR + LF, LF)
    b_n = b.replace(CR + LF, LF)
    same = a_n == b_n
    say("  %-14s %s" % (target, "совпадает с оригиналом" if same else "ОТЛИЧАЕТСЯ"))
    if not same:
        # точное место первого расхождения с байтовым контекстом
        n = min(len(a_n), len(b_n))
        d0 = next((x for x in range(n) if a_n[x] != b_n[x]), n)
        lo = max(0, d0 - 60)
        say("      первое расхождение на символе %d:" % d0)
        say("      оригинал: %s" % repr(b_n[lo:d0 + 60]))
        say("      патч    : %s" % repr(a_n[lo:d0 + 60]))
        import difflib
        d = list(difflib.unified_diff(b_n.split(LF), a_n.split(LF), "оригинал", "патч", n=1))
        for line in d[:10]:
            say("      " + line.rstrip())
        failures.append("%s: результат патча не совпал с оригиналом" % target)
    r = subprocess.run([ESBUILD, os.path.join(TMP, target).replace("/", BY),
                        "--outfile=" + os.path.join(TMP, target + ".js").replace("/", BY)],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    say("  %-14s esbuild: %s" % (target, "OK" if r.returncode == 0 else "ОШИБКА " + (r.stderr or "")[:200]))
    if r.returncode != 0:
        failures.append("%s: esbuild упал" % target)

say("")
if failures:
    say("ИТОГ: ПРОВАЛОВ %d" % len(failures))
    for f in failures:
        say("  x " + f)
    sys.exit(1)
say("ИТОГ: все проверки пройдены — патчеры идемпотентны и вставляют в стиле апстрима")
sys.exit(0)
