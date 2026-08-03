# scripts\patch\config_set.py
# Устанавливает значение в config.yaml через ШТАТНЫЙ модуль hermes_cli.config
# (set_config_value: точечная запись по dotted-пути, merge не затирает чужие
# секции; атомарная запись; бэкап битого YAML). Замена ручных patch_*.ps1.
# Аргументы: <REPO_DIR> <key.dot.path> <value>
# REPO_DIR нужен для импорта hermes_cli (каталог hermes-agent).
import sys

if len(sys.argv) < 4:
    sys.exit(1)

sys.path.insert(0, sys.argv[1])

from hermes_cli.config import set_config_value

set_config_value(sys.argv[2], sys.argv[3])
