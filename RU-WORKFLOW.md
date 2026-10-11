# Русификация Hermes Desktop - схема A (апстрим-база + наш слой)

Корень установки: `D:\NEURO\Hermes`. Автоматически: `Tools.bat` → `[10]` (`scripts\py\ru_workflow.py`).

## Что это и почему так

С версии ~1.0 апстрим Hermes **сам поддерживает русский**: `ru` в `BundledLocale`
(`apps/desktop/src/i18n/types.ts`), в списке языков (`languages.ts`) и в каталоге
(`catalog.ts`), плюс плюрализация `RU_PLURAL`/`RU_NOUN` и модульный словарь
(`ru.ts` + `ru_aux_tasks.ts`, `ru_onboarding.ts`, ...). Наши прежние патчи
`types/languages/catalog` и подмена `ru.ts` целиком стали вредны: подмена стирала их
3531 перевод и не давала их обновлений.

**Схема A:** база - апстримный `ru.ts` (обновляется вместе с репой), а наш файл -
компактный **слой** `ru-layer.ts` с тем, чего у апстрима нет. Глубокое слияние делает
`mergeTranslations` (рекурсивный), поэтому новый `ru.ts` собирается так:

```ts
import { mergeTranslations } from '@hermes/shared/i18n'
import { ruLayerOverrides } from './ru-layer'      // наш слой
...
export const ru = defineLocale(mergeTranslations(ruOverrides, ruLayerOverrides))
```

Никаких ps1-патчей: файл `ru.ts` **конструируется** из апстримного эталона
(`i18n_build_layer.py --install`), а не правится поиском/заменой.

## Файлы

| Путь | Роль |
|---|---|
| `scripts\ru-locale\ru.ts` | **наш источник переводов** (правим здесь) |
| `scripts\ru-locale\ru-constants.ts` | наши подписи/описания полей настроек |
| `scripts\ru-locale\ru-layer.ts` | **генерируемый слой** - то, что уходит в репу (руками не править) |
| `scripts\en-locale\en.ts` + `en_*.ts` | эталон en **с модулями** (их подключает `en.ts`) |
| `scripts\en-locale\en-constants.ts` | эталон подписей полей |
| `scripts\upstream-locale\ru.ts` + `ru_*.ts` | **апстримная база** (берётся из `git HEAD`, не из рабочего дерева!) |

Эталоны обновляет `i18n_sync_refs.py` (в цикле - шаг 1). Апстримный `ru.ts` тянется
через `git show HEAD:...`, потому что в рабочем дереве на его месте лежит наш `ru.ts`.

## Инструменты (`scripts\py\`)

| Скрипт | Назначение |
|---|---|
| `i18n_sync_refs.py` | эталоны: `en.ts` + модули `en_*.ts`, апстримный `ru.ts` из git HEAD |
| `i18n_refs.py` | ядро: полный словарь en (разворачивает модули), апстримный ru, наш ru; `--stats`, `--flat DIR` |
| `i18n_build_layer.py` | собирает `ru-layer.ts`; `--install` - ещё и `ru.ts` (апстрим + подключение слоя) в репу |
| `i18n_verify.py` | проверка перед сборкой: структура, esbuild, живые ключи, установка, покрытие (exit 1 = не собирать) |
| `i18n_status.py` | сводка покрытия и дыр; `--flat DIR` - `en.flat`/`ru.flat`/`holes.flat` для WinMerge |
| `ru_workflow.py` | полный цикл: эталоны → слой+установка → проверка → сводка → тестовая сборка |
| `i18n_apply_flat.py` | импорт пакета переводов в наш `ru.ts` (правки - в файл-список `ключ = текст`) |
| `ru_locale_backup.py` | `backup`/`restore`/`status`: файлы локализации + готовая сборка |
| `i18n_sort_like_en.py` | низкоуровневый парсер TS-локалей (используют `i18n_refs`/`ru_workflow`) |

Питон: `data\hermes\hermes-agent\venv\Scripts\python.exe`.

## Что апстрим делает сам (нам не надо)

- Регистрация языка: `types.ts` / `languages.ts` / `catalog.ts` (патчи удалены).
- Плюрализация: `RU_PLURAL`/`RU_NOUN` внутри апстримного `ru.ts`.
- Модульный словарь и `defineFieldCopy` для подписей полей.

## Workflow: русификация под новую версию Hermes

```
python scripts\py\ru_workflow.py            # весь цикл (в конце - тестовая сборка)
python scripts\py\ru_workflow.py --skip-build
```
По шагам (вручную):

1. **Эталоны**: `python scripts\py\i18n_sync_refs.py`
2. **Слой + установка**: `python scripts\py\i18n_build_layer.py --install`
3. **Проверка**: `python scripts\py\i18n_verify.py` (нужен «ИТОГ: проверка пройдена»)
4. **Сводка**: `python scripts\py\i18n_status.py --holes 20 --flat data\temp\i18n-compare`
5. **Перевод дыр** (см. ниже) → повторить 2-3.
6. **Сборка**: `Tools.bat` → `[5]` (бэкап + release) или `[10]` (цикл + вопрос о боевой сборке).

## Как переводить дыры

1. `i18n_status.py --flat data\temp\i18n-compare` → в `holes.flat` список «ключ = англ. текст».
2. Правим **`scripts\ru-locale\ru.ts`** (наш источник): `ключ: 'русский текст'`.
   Вложенность как в `en.ts`, ключи с дефисом - в кавычках, переносы - внутри шаблона.
   Импорт пачкой: `python scripts\py\i18n_apply_flat.py --flat <файл> --ru scripts\ru-locale\ru.ts`.
3. `i18n_build_layer.py --install` → слой перегенерируется (апстримные переводы из него
   автоматически вычитаются, мусор и английские заглушки отбрасываются).
4. `i18n_verify.py` → сборка.

Правило: **существующие переводы не трогаем**; слой содержит только то, чего нет у апстрима.
Если апстрим перевёл ключ лучше - наш дубль просто перестанет попадать в слой при генерации.

## Критерии готовности

- `i18n_verify.py` → exit 0 (структура, esbuild, все ключи слоя живые, установка совпадает).
- `i18n_status.py` показывает покрытие и **0 мёртвых** ключей в слое.
- `Tools.bat [5]` → сборка успешна, Desktop запускается, UI на русском.

## Откат

- `Tools.bat [6]` - файлы локализации + собранный Desktop из `data\backup\`.
- Копии: `ru-layer.ts.pre-build` (до генерации), `data\backup\ru-locale\` (по бэкапу).

## Пункты Tools.bat

`[1]` сравнение эталона и итога (WinMerge: `en.flat` vs `ru.flat`, список дыр - `holes.flat`) ·
`[2]` сравнение источника и слоя (`ru.ts` vs `ru-layer.ts`) · `[3]` .env · `[4]` config.yaml ·
`[5]` пересборка с бэкапом · `[6]` откат · `[7]` очистка репозитория ·
`[8]` проверка русификации · `[9]` сборка слоя `ru-layer.ts` · `[10]` полный цикл.
