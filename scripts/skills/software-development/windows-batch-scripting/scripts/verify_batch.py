#!/usr/bin/env python3
"""verify_batch.py — верификация .bat-скриптов перед коммитом.

Проверяет для каждого указанного .bat:
  1. Все goto/call :label имеют существующие метки.
  2. Баланс скобок (с учётом экранированных ^( ^) и кавычек) == 0.
  3. Реальный прогон через `cmd /c` со stdin-автоответом (0 = выход из меню):
     exit-код и отсутствие маркеров синтаксических ошибок cmd.

Использование (из git-bash, пути Windows-формата):
  python "C:/path/verify_batch.py" "D:/repo/Start.bat" "D:/repo/scripts/Tools.bat" [--expected N:path ...]
  --expected N:path  — разрешить exit-код N для конкретного скрипта
                      (например, скрипт, требующий установленных компонентов,
                      корректно завершается с 1 на машине без установки).

Пример:
  python verify_batch.py "D:/Hermes/Start.bat" "D:/Hermes/scripts/InstallOrUpdate.bat" --expected 1:D:/Hermes/scripts/LaunchOptions.bat
"""
import subprocess, os, re, sys

SYNTAX_MARKERS = [
    b"was unexpected at this time",
    b"cannot find the batch label",
    b"is not recognized as an internal or external command",
    b"The syntax of the command is incorrect",
]

def check_crlf(path):
    """CRLF-проверка: orphan-LF (LF без CR) == 0. cmd ломается на LF-only .bat!"""
    with open(path, "rb") as f:
        d = f.read()
    orphan = 0
    for i in range(len(d) - 1):
        if d[i] == 0x0A and d[i - 1] != 0x0D:
            orphan += 1
    return orphan

def check_structure(path):
    """Возвращает (missing_labels, paren_balance)."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        lines = f.read().split("\n")
    labels = set()
    for ln in lines:
        m = re.match(r"\s*:(\w+)", ln)
        if m and not ln.strip().startswith("::"):
            labels.add(m.group(1))
    missing = []
    for i, ln in enumerate(lines, 1):
        for m in re.finditer(r"(?:goto|call)\s+:?(\w+)", ln, re.I):
            # внешние вызовы вида call "file.bat" / call "%SCRIPTS_DIR%\X.bat" пропускаем
            if '"' not in ln[:m.start()] and "\\" not in ln[m.start():m.end()]:
                if m.group(1) not in labels:
                    missing.append((i, m.group(1)))
    bal = 0
    for ln in lines:
        s = ln.replace("^(", "").replace("^)", "")
        s = re.sub(r'"[^"]*"', '""', s)
        s = re.sub(r"'[^']*'", "''", s)
        bal += s.count("(") - s.count(")")
    return missing, bal

def main():
    args = sys.argv[1:]
    scripts, expected = [], {}
    i = 0
    while i < len(args):
        if args[i] == "--expected":
            i += 1
            code, _, path = args[i].partition(":")
            expected[os.path.normpath(path)] = int(code)
        else:
            scripts.append(args[i])
        i += 1
    if not scripts:
        print("Нет скриптов для проверки. Смотри docstring.")
        return 2

    all_ok = True
    for rel in scripts:
        path = os.path.normpath(rel)
        missing, bal = check_structure(path)
        orphan = check_crlf(path)
        struct_ok = (len(missing) == 0 and bal == 0 and orphan == 0)
        try:
            p = subprocess.run(["cmd", "/c", path], input=b"0\n",
                               capture_output=True, timeout=40,
                               cwd=os.path.dirname(path) or ".")
            out = p.stdout + p.stderr
            err = [m for m in SYNTAX_MARKERS if m.lower() in out.lower()]
            syn_ok = len(err) == 0
            exp = expected.get(path)
            code_ok = (exp is None) or (p.returncode == exp)
            ok = struct_ok and syn_ok and code_ok
            all_ok = all_ok and ok
            print(f"[{'OK' if ok else 'FAIL'}] {path}")
            print(f"        exit={p.returncode} (ожид. {exp if exp is not None else 'любой'}), "
                  f"структура={'OK' if struct_ok else 'FAIL'}, синтаксис={'OK' if syn_ok else 'FAIL'}")
            if missing:
                print(f"        НЕТ МЕТОК: {missing[:5]}")
            if bal != 0:
                print(f"        ДИСБАЛАНС СКОБОК: {bal}")
            if err:
                print(f"        МАРКЕРЫ: {[m.decode('ascii', 'replace') for m in err]}")
        except subprocess.TimeoutExpired:
            all_ok = False
            print(f"[FAIL] {path}: TIMEOUT 40s (меню зависло на вводе?)")
    print("\nИТОГ:", "ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ" if all_ok else "ЕСТЬ ПРОБЛЕМЫ")
    return 0 if all_ok else 1

if __name__ == "__main__":
    sys.exit(main())
