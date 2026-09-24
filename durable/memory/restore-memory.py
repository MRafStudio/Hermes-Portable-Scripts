#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""restore-memory — если штатная память Hermes пропала (обновление/сброс),
вернуть её из durable.  Запуск:  python restore-memory.py
"""
import os, shutil, sys

H     = r"D:\NEURO\Hermes"
MEM   = os.path.join(H, "data", "hermes", "memories")
BK    = os.path.join(H, "durable", "memory", "backup-memories")

def main():
    os.makedirs(MEM, exist_ok=True)
    act = []
    for f in ("MEMORY.md", "USER.md"):
        src = os.path.join(BK, f)
        dst = os.path.join(MEM, f)
        if not os.path.exists(src):
            continue
        if (not os.path.exists(dst)) or os.path.getsize(dst) < os.path.getsize(src) * 0.5:
            shutil.copy2(src, dst)
            act.append("восстановлен " + f)
        else:
            act.append(f + " на месте (" + str(os.path.getsize(dst)) + " б)")
    # свежий бэкап обратно
    for f in ("MEMORY.md", "USER.md"):
        src = os.path.join(MEM, f)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(BK, f))
    print(" | ".join(act) if act else "нечего делать")

if __name__ == "__main__":
    main()
