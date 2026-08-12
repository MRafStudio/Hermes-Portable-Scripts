# verify_installers.py — канонический тест скриптов установки (Llama.cpp + Llama.cpp)
# Запуск: python scripts/tests/verify_installers.py  (или pytest — функции test_*)
# Проверяет целостность репозитория: генераторы, установщики, меню, Start.bat, базу моделей.
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPTS = os.path.join(ROOT, 'scripts')

_failures = []


def chk(name, cond):
    if cond:
        print('PASS', name)
    else:
        _failures.append(name)
        print('FAIL', name)


def _read(rel):
    with open(os.path.join(SCRIPTS, rel), encoding='utf-8', errors='ignore') as f:
        return f.read()


# --- генераторы start-скриптов (должны быть в репо!) ---
def test_generators_in_repo():
    chk('llama_gen_startbat.py', os.path.exists(os.path.join(SCRIPTS, 'py', 'llama_gen_startbat.py')))
    chk('llama_gen_startbat.py', os.path.exists(os.path.join(SCRIPTS, 'py', 'llama_gen_startbat.py')))


# --- установщики: не затирают пользовательские правки (if-not-exist-защита!) ---
def test_installers_preserve_user_edits():
    llm = _read('InstallOrUpdate-Llama.bat')
    chk('llm: if-exist start_llama.bat (правки сохраняются)', 'if exist "%LLAMA_DIR%\\start_llama.bat"' in llm)

    # --- Синхронизация флагов: генератор == сгенерированный bat == служба! ---
    import os as _os
    _base = _os.path.dirname(_os.path.dirname(_os.path.dirname(__file__)))  # scripts/tests/ -> корень репо
    gen = open(_os.path.join(_base, 'scripts', 'py', 'llama_gen_startbat.py'), encoding='utf-8').read()
    svc = open(_os.path.join(_base, 'scripts', 'Llama-Service.bat'), encoding='utf-8').read()
    flags = ['--parallel 1', '--image-min-tokens 1024', '--alias llama']
    for fl in flags:
        chk(f'синхрон флагов: {fl} (генератор+служба)', fl in gen and fl in svc)
    # сгенерированный start_llama.bat (data) — если есть — тоже сверяем
    gen_bat = _os.path.join(_base, 'data', 'llama', 'start_llama.bat')
    if _os.path.exists(gen_bat):
        bat = open(gen_bat, encoding='utf-8', errors='ignore').read()
        for fl in flags:
            chk(f'синхрон флагов: {fl} (сгенерированный start_llama.bat)', fl in bat)
    chk('llm: сообщение о сохранении правок', 'правки пользователя сохраняются' in llm)
    llama = _read('InstallOrUpdate-Llama.bat')
    chk('llama: if-exist start_llama.bat', 'if exist "%LLAMA_DIR%\\start_llama.bat"' in llama)
    chk('llama: вопрос перегенерации', 'Перегенерировать start_llama.bat' in llama)


# --- установщики: вызывают генераторы (генерируют start-скрипт при установке!) ---
def test_installers_call_generators():
    llm = _read('InstallOrUpdate-Llama.bat')
    chk('llm: вызов llama_gen_startbat', 'llama_gen_startbat.py' in llm)
    llama = _read('InstallOrUpdate-Llama.bat')
    chk('llama: вызов llama_gen_startbat', 'llama_gen_startbat.py' in llama)


# --- меню плагинов: llama (не llm/Qwythos!) ---
def test_plugins_menu_llama():
    menu = _read('InstallOrUpdate-Plugins.bat')
    chk('меню: пункт [1] Llama.cpp', 'Llama.cpp — установка/обновление' in menu)
    chk('меню: порт 8080', 'порт 8080' in menu)
    chk('меню: Qwythos убран', 'Qwythos' not in menu)
    chk('меню: вызов InstallOrUpdate-Llama', 'InstallOrUpdate-Llama.bat' in menu)


# --- Start.bat: автозапуск llama (не llm!) ---
def test_start_bat_llama():
    start = _read(os.path.join('..', 'Start.bat'))
    chk('Start.bat: Start-Llama-IfNeeded', 'Start-Llama-IfNeeded.bat' in start)


# --- база моделей (llama_models.py): Qwen-основная, Gemma-резерв, без Qwythos ---
def test_models_db():
    src = _read(os.path.join('py', 'llama_models.py'))
    chk('база: Qwen3.6-35B', 'Qwen3.6-35B' in src)
    chk('база: Gemma-3-27B осталась', 'Gemma-3-27B' in src)
    chk('база: Qwythos убрана', 'Qwythos' not in src)
    chk('база: mmproj_ИСТИННОЕ поле', 'I_MMPROJ_SRC' in src)


# --- скиллы (репо): autonomous-execution + memos-tool-id-formats ---
def test_skills_in_repo():
    chk('скилл autonomous-execution', os.path.exists(os.path.join(SCRIPTS, 'skills', 'software-development', 'autonomous-execution', 'SKILL.md')))
    chk('скилл memos-tool-id-formats', os.path.exists(os.path.join(SCRIPTS, 'skills', 'software-development', 'memos-tool-id-formats', 'SKILL.md')))


def main():
    print('=== verify_installers.py (канонический тест репозитория) ===')
    for name, fn in sorted(globals().items()):
        if name.startswith('test_') and callable(fn):
            fn()
    if _failures:
        print(f'RESULT: {len(_failures)} FAILED: {_failures}')
        return 1
    print('RESULT: ALL PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
