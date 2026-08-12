# Hermes-Portable-Scripts — репозиторий пользователя (MRafStudio)

GitHub: `MRafStudio/Hermes-Portable-Scripts`. Портабельный запускатель Hermes Agent на Windows.

## Раскладка (дом/полигон)

- **Дом (рабочая копия агента):** `C:\NEURO\Hermes` — здесь живёт агент (HERMES_HOME=`C:\NEURO\Hermes\data\hermes`, HOME/USERPROFILE=`C:\NEURO\Hermes\data\home`). **git pull в доме НЕ делать** — агент работает из этой копии.
- **Полигон (клон для отладки):** `D:\Hermes` — ВСЕ изменения скриптов делаются только здесь, пока не согласовано, что они безопасны для дома.
- Данные в `data\` (в .gitignore), проекты — `C:\NEURO\Hermes\projects`.
- Диск D: — только бэкапы + полигон.

## Механизм запуска

`Start.bat` в корне — главное меню. Задаёт всё окружение от `ROOT_DIR=%~dp0`:
`HERMES_HOME`, `DATA_DIR`, изоляцию (`TEMP/TMP/APPDATA/LOCALAPPDATA/HOME/USERPROFILE` → `data\`),
`PYTHONPATH=""`, `HF_HOME`, создаёт `PS_WRAPPER` (PowerShell с изоляцией) для получения ESC-символа.
Desktop-приложение запускается через `scripts\Start-Hermes-Desktop.bat` → `start /min ... Start-Hermes-Desktop-Console.bat`.

## Состояние после выпиливания kobold (коммит ещё НЕ запушен — на полигоне, uncommitted)

Удалено (git rm): `InstallOrUpdate-Kobold.bat`, `Start-Kobold.bat`, `PatchConfigKobold.bat`,
`Model-Setup.bat`, `Settings.bat`, `DetectGPU.bat`, `CreateConfig.bat`, `InstallOrUpdate-HF.bat`.
Обычным rm: `scripts\Config.ini` (был в .gitignore; содержал ТОЛЬКО kobold-параметры).

Почищено: `Start.bat` (GPU-секция, логика Config.ini, пункт [3] Настройки — меню теперь [1]/[2]/[5]/[0]),
`InstallOrUpdate.bat` (KoboldCpp-пункты, секция install_kobold с GPU-проверкой VRAM),
`Tools.bat` (пункт [4] Kobold DEBUG), `Start-Hermes-Desktop.bat` (автозапуск KoboldCpp),
`LaunchOptions.bat` (мёртвый CONFIG_FILE), `README.md`.

Осталось (ядро, не kobold): `InstallOrUpdate-Desktop/-Deps/-NodeJS/-Python/-UV/-Repo/-RU.bat`,
`Download-Electron.bat`, `LaunchOptions.bat`, `Rebuild-Desktop.bat`, `SmartPause.bat`,
`Start-Hermes-Desktop.bat`, `Start-Hermes-Desktop-Console.bat`, `Tools.bat`,
`bin\uv.exe`, `patch\`, `en-locale\`, `ru-locale\`.

## Известные нерешённые проблемы (лечатся в скриптах запуска)

1. Рабочая директория сессий = `C:\Users\Администратор.WIN-3UIGTI09LG4` вместо `data\home`.
2. Hermes лезет в `C:\Users\...\AppData\Roaming` системного профиля (из-за этого была перекомпиляция).
Причина обеих: desktop-приложение запускается вне `Start.bat` (не наследует изоляцию окружения).

## Git-личность репозитория

`git config user.name "RafStudio"`, `user.email "rafstudio@outlook.com"` (задано локально в доме;
в полигоне при коммите задать так же). Коммит-месседжи — на русском.
