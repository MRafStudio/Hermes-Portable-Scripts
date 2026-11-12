# NODE-TOOLCHAIN.md — Node.js / npm / pnpm в Hermes Portable

Правила выбора и обновления Node.js, npm и pnpm. Дополняет `AGENTS.md` (там только про скрипты
и русификацию, чтобы не раздувать основной свод).

## Кто что создаёт

- Портативные `data\hermes\tools\node-*` и `data\hermes\tools\pnpm-*` ставит **родной `install.ps1`
  Hermes** (через свой `pm`, каталог `<HermesHome>\tools`). Наши скрипты их только **выбирают**.
- Наши скрипты создают портативный Node **только** как крайний вариант: `InstallOrUpdate-NodeJS.bat`
  кладёт zip-распаковку в `<HERMES_HOME>\node`.

## Приоритет Node.js (`scripts\Find-Node-Toolchain.bat`)

1. **Глобальный** Node (Program Files + реестр HKLM/HKCU) - если его major >= 26 → используем его,
   портативный не навязываем (`IS_GLOBAL_NODE=1`);
2. портативный `tools\node-*` - версия выбирается **численно** (26.12.1 новее 26.7.0, хотя строкой
   меньше);
3. локальный `<HERMES_HOME>\node`;
4. глобальный **устаревший** - берётся, но с флагом `NODE_TOO_OLD=1`, чтобы вызывающий скрипт
   предупредил до установки.

## Приоритет pnpm (`scripts\Find-Node-Toolchain.bat`)

Версия важнее происхождения, потому что пин `pm/lock.json` ломает сборку при расхождении:

1. `pnpm` из PATH с версией **ровно** `PNPM_EXPECTED` (сейчас 12.15.0) - годится и глобальный,
   и портативный;
2. `tools\pnpm-<PNPM_EXPECTED>-win32-x64`;
3. любой `tools\pnpm-*`;
4. любой `pnpm` из PATH - с флагом `PNPM_VER_MISMATCH=1`.

## Обновление глобального Node (`scripts\InstallOrUpdate-NodeJS.bat`)

- Версия глобального **проверяется**: `>= NODE_MIN_MAJOR` (26) → работаем на нём, ничего не трогаем.
- Устарел → **громкое предупреждение** (красная плашка: найденный путь, версия, требуемая версия)
  и предложение обновить глобальный:
  1. `winget install OpenJS.NodeJS` (если winget есть);
  2. если не вышло - MSI `node-v26.12.1-x64.msi` через `msiexec /qn` с запросом UAC;
  3. после каждой попытки - перепроверка версии (`:recheck_global_node`);
  4. не удалось / пользователь отказался → ставится портативная версия, и это **произносится вслух**.
- Тихих обновлений на машине пользователя не делаем: он должен видеть, что меняется.

## Грабли

- **winget есть почти всегда, но найти его из скрипта - задача.** Проверено на этой машине:
  - `C:\Users\<user>\AppData\Local\Microsoft\WindowsApps\winget.exe` - это **алиас** (0 байт);
    при запуске из чужого/изолированного окружения даёт «Доступ к этому файлу из системы отсутствует»;
  - `C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*\winget.exe` - рабочий exe
    (у нас `v1.29.380`), но **каталог `WindowsApps` не листается** (`dir` → «Отказано в доступе»),
    значит перебрать пакеты через `for /d` нельзя;
  - `Get-AppxPackage Microsoft.DesktopAppInstaller` в обычном контексте даёт `InstallLocation`,
    а в изолированном окружении Hermes пакетов не видит вовсе.
  Поэтому `:find_winget` ищет так: `where winget` → `%REAL_LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe`
  → `Get-AppxPackage ... InstallLocation` → `(Get-Command winget).Source`.
- **Версию winget спрашивать через переменную окружения**, а не подставлять путь в кавычки:
  `for /f ... in ('powershell -Command "(& $env:WINGET_EXE --version)"')`. Одинарные кавычки
  внутри `for /f` рвут разбор, а путь с пробелами (`Program Files`) без кавычек не запускается.
- `winget install`/`upgrade` требует прав: `Start-Process ... -Verb RunAs -Wait`, иначе установка
  пройдёт в фоне без прав и молча провалится.
- `%ProgramFiles%\nodejs` может содержать старый Node, хотя в `tools\` уже лежит новый - именно
  поэтому выбор идёт по версии, а не по факту наличия.
- Дубликаты `tools\node-*` копятся при обновлениях Hermes; лишние можно удалять (выбор идёт по
  численной версии, а не по имени каталога).
