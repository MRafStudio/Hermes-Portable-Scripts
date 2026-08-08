# update_ini_auth.py — обновление AUTH_USER/AUTH_PASS в portable_start.ini.
# Аргументы: ini-путь, логин, пароль. Перезаписывает файл (CRLF сохраняет).
import sys
import os

if len(sys.argv) < 4:
    sys.exit(1)
ini, user, pwd = sys.argv[1], sys.argv[2], sys.argv[3]

data = open(ini, "rb").read()
crlf = data.count(b"\r\n") > 0
t = data.replace(b"\r\n", b"\n").decode("utf-8", errors="replace")

keep = []
for line in t.split("\n"):
    s = line.strip()
    if s.startswith("AUTH_USER=") or s.startswith("AUTH_PASS="):
        continue
    keep.append(line)

out = "\n".join(keep).rstrip("\n") + "\nAUTH_USER=" + user + "\nAUTH_PASS=" + pwd + "\n"
if crlf:
    out = out.replace("\n", "\r\n")
open(ini, "wb").write(out.encode("utf-8"))
print("OK")
