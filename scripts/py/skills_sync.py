"""skills_sync.py save|pull|status|list - наш Git-контур защиты скиллов Hermes.

Источник истины : SCM-Manager  RafStudio/hermes-rk7-skills
Рабочая копия   : D:/NEURO/Hermes/data/hermes/skills   (то, что читает Hermes)
Клон для git    : D:/NEURO/Hermes/skills-repo
Креды           : data/hermes/.env -> SCM_URL / SCM_USER / SCM_APIKEY
                  ВАЖНО: пароль для git и API - ПОЛНЫЙ api-ключ (не passphrase).

Версионируем ТОЛЬКО наши каталоги. Признак принадлежности - файл-метка OURS в каталоге
скилла или в каталоге-категории (метка на категории берёт её целиком). Чужие скиллы не трогаем.

Команды:
  list   - печатает, что версионируем, и что реально есть на диске
  save   - рабочая копия -> клон -> commit -> push (со сверкой SHA через ls-remote)
  pull   - репозиторий -> рабочая копия, с БЭКАПОМ в data/backup/skills-<дата-время>
  status - что отличается между рабочей копией и клоном
"""
from __future__ import annotations

import filecmp
import os
import pathlib
import shutil
import subprocess
import sys
import time

HOME = pathlib.Path("D:/NEURO/Hermes")
SKILLS = HOME / "data" / "hermes" / "skills"
REPO = HOME / "skills-repo"
ENV = HOME / "data" / "hermes" / ".env"
BACKUP = HOME / "data" / "backup"
REPO_SUBDIR = "skills"

# Наши каталоги определяются МЕТКОЙ: файл OURS в каталоге скилла или в каталоге-категории
# (метка на категории берёт её целиком, поэтому новый скилл внутри подхватится сам).
# Содержимое скиллов при этом не правится.
MARKER = "OURS"


def is_ours(rel: str, roots: list) -> bool:
    return any(rel == r or rel.startswith(r + "/") for r in roots)


def collect_our() -> list:
    roots = []
    for m in sorted(SKILLS.rglob(MARKER)):
        if not m.is_file():
            continue
        rel = m.parent.relative_to(SKILLS).as_posix()
        if rel == "." or is_ours(rel, roots):
            continue
        roots.append(rel)
    return roots


def unmarked_recent(days: float = 2.0) -> list:
    """Скиллы без метки, недавно правленные: свежий наш скилл без метки должно быть видно."""
    now = time.time()
    out = []
    for md in SKILLS.rglob("SKILL.md"):
        rel = md.parent.relative_to(SKILLS).as_posix()
        if is_ours(rel, OUR):
            continue
        age = (now - md.stat().st_mtime) / 86400.0
        if age <= days:
            out.append("%s (правка %.1f дн назад)" % (rel, age))
    return out


OUR = collect_our()

GITIGNORE = (
    "# Версионируем только наши каталоги (метка-файл OURS; правило в tools/skills_sync.py).\n"
    "*\n"
    "!*/\n"
    "!skills/\n"
    "!skills/**\n"
    "!tools/\n"
    "!tools/**\n"
    "!README.md\n"
    ".gitattributes\n"
)


def env() -> dict:
    d = {}
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.startswith("#"):
            k, _, v = line.partition("=")
            d[k.strip()] = v.strip()
    return d


# Служба и крон идут под учёткой СИСТЕМА, а клон на диске принадлежит rafst:
# без этого git падает с "detected dubious ownership", а его сообщение с кириллицей
# (имя учётки) ещё и ломает декод (UnicodeDecodeError в _readerthread).
SAFE = ["-c", "safe.directory=*"]


def git(*args: str, cwd: pathlib.Path = REPO, check: bool = True) -> subprocess.CompletedProcess:
    r = subprocess.run(["git", *SAFE, *args], cwd=str(cwd), capture_output=True, text=True,
                       encoding="utf-8", errors="replace",
                       timeout=300, env={**os.environ, "GIT_TERMINAL_PROMPT": "0"})
    if check and r.returncode != 0:
        print("git", " ".join(args), "-> rc", r.returncode)
        print((r.stdout + r.stderr).strip()[:600])
    return r


def auth_url() -> str:
    e = env()
    plain = e["SCM_URL"] + "/scm/repo/RafStudio/hermes-rk7-skills.git"
    return plain.replace("://", "://" + e["SCM_USER"] + ":" + e["SCM_APIKEY"] + "@", 1)


def push_url() -> str:
    e = env()
    plain = e["SCM_URL"] + "/scm/repo/RafStudio/hermes-rk7-skills.git"
    return plain.replace("://", "://" + e["SCM_USER"] + ":" + e["SCM_APIKEY"] + "@", 1)


def ensure_repo() -> None:
    if not (REPO / ".git").exists():
        REPO.parent.mkdir(parents=True, exist_ok=True)
        git("clone", auth_url(), str(REPO), cwd=HOME)
    git("config", "user.name", "Hermes Agent")
    git("config", "user.email", "hermes@local")
    # пустой репозиторий: HEAD не разрешается, пока нет первого коммита -> заводим ветку main
    if git("rev-parse", "--verify", "-q", "HEAD", check=False).returncode != 0:
        git("symbolic-ref", "HEAD", "refs/heads/main", check=False)
    (REPO / ".gitignore").write_text(GITIGNORE, encoding="utf-8", newline="\n")


def cmd_list() -> int:
    print(f"рабочая копия: {SKILLS}")
    print(f"клон:          {REPO}")
    warn = unmarked_recent()
    print(f"\nнаших каталогов по метке {MARKER}: {len(OUR)}")
    print(f"скиллов без метки с правкой за 2 дня: {len(warn)}")
    for line in warn:
        print("  БЕЗ МЕТКИ:", line)
    print()
    miss = []
    for rel in OUR:
        n = len(list((SKILLS / rel).rglob("SKILL.md"))) if (SKILLS / rel).exists() else 0
        print(f"  {'OK ' if n else 'НЕТ'} {rel:52} SKILL.md: {n}")
        if not n:
            miss.append(rel)
    if miss:
        print("\nотсутствуют на диске:", ", ".join(miss))
    return 0


def copy_tree(src: pathlib.Path, dst: pathlib.Path) -> int:
    n = 0
    for f in src.rglob("*"):
        if f.is_dir():
            continue
        rel = f.relative_to(src)
        if any(part in {".git", "__pycache__", ".cache"} for part in rel.parts):
            continue
        target = dst / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(f, target)
        n += 1
    return n


def prune_extra(src: pathlib.Path, dst: pathlib.Path) -> list:
    """Удаляет в dst то, чего уже нет в src (файлы и опустевшие каталоги).

    Без этого шага клон накапливает «призраки»: файл заменили или удалили в рабочей копии,
    copy_tree его не трогает - и он остаётся в репозитории навсегда.
    Границы безопасности: работаем только внутри dst (наши каталоги с меткой OURS).
    """
    removed = []
    if not dst.exists():
        return removed
    for f in sorted(dst.rglob("*"), key=lambda p: len(p.parts), reverse=True):
        rel = f.relative_to(dst)
        if any(part in {".git", "__pycache__", ".cache"} for part in rel.parts):
            continue
        if f.is_dir():
            try:
                if not any(f.iterdir()):
                    f.rmdir()
                    removed.append(str(rel).replace(os.sep, "/") + "/")
            except OSError:
                pass
        elif not (src / rel).exists():
            f.unlink()
            removed.append(str(rel).replace(os.sep, "/"))
    return removed


def cmd_save(message: str = "") -> int:
    ensure_repo()
    total = 0
    removed = []
    for rel in OUR:
        src = SKILLS / rel
        if not src.exists():
            continue
        total += copy_tree(src, REPO / REPO_SUBDIR / rel)
        removed += [f"{rel}/{r}" for r in prune_extra(src, REPO / REPO_SUBDIR / rel)]
    # сам скрипт - в репозиторий
    (REPO / "tools").mkdir(exist_ok=True)
    shutil.copy2(pathlib.Path(__file__), REPO / "tools" / "skills_sync.py")
    print(f"скопировано файлов: {total}" + (f" | удалено лишних: {len(removed)}" if removed else ""))
    for r in removed[:20]:
        print("  удалено из клона:", r)
    if len(removed) > 20:
        print(f"  ... ещё {len(removed) - 20}")
    warn = unmarked_recent()
    if warn:
        print(f"ВНИМАНИЕ: {len(warn)} скилл(ов) без метки, правленных за 2 дня - проверь, наши ли это:")
        for line in warn:
            print("  БЕЗ МЕТКИ:", line)
    git("add", "-A")
    st = git("status", "--porcelain")
    if not st.stdout.strip():
        print("изменений нет - коммит не нужен")
    else:
        msg = message or f"skills: сохранение {time.strftime('%Y-%m-%d %H:%M')}"
        r = git("commit", "-m", msg)
        print("commit:", r.stdout.strip().splitlines()[0] if r.stdout.strip() else r.stderr[:120])
    rb = git("rev-parse", "--abbrev-ref", "HEAD", check=False)
    branch = rb.stdout.strip() if (rb.returncode == 0 and rb.stdout.strip() and rb.stdout.strip() != "HEAD") else "main"
    p = git("push", push_url(), f"HEAD:refs/heads/{branch}")
    print("push rc:", p.returncode)
    ls = git("ls-remote", auth_url(), f"refs/heads/{branch}")
    remote_sha = (ls.stdout.split()[0] if ls.stdout.strip() else "(пусто)")
    local_sha = git("rev-parse", "HEAD").stdout.strip()
    print(f"local : {local_sha}")
    print(f"remote: {remote_sha}")
    print("СВЕРКА:", "СОВПАЛО" if local_sha == remote_sha else "РАСХОЖДЕНИЕ")
    return 0


def cmd_status() -> int:
    ensure_repo()
    diff = []
    extra = []
    for rel in OUR:
        src = SKILLS / rel
        if not src.exists():
            continue
        for f in src.rglob("*"):
            if f.is_dir() or any(p in {".git", "__pycache__"} for p in f.relative_to(src).parts):
                continue
            t = REPO / REPO_SUBDIR / rel / f.relative_to(src)
            if not t.exists():
                diff.append(("только в рабочей", str(f.relative_to(SKILLS))))
            elif not filecmp.cmp(f, t, shallow=False):
                diff.append(("отличается", str(f.relative_to(SKILLS))))
        # обратная сторона: в клоне осталось то, чего в рабочей копии уже нет (мусор для save)
        tdir = REPO / REPO_SUBDIR / rel
        if tdir.exists():
            for f in tdir.rglob("*"):
                if f.is_dir() or any(p in {".git", "__pycache__"} for p in f.relative_to(tdir).parts):
                    continue
                if not (src / f.relative_to(tdir)).exists():
                    extra.append(str(f.relative_to(REPO / REPO_SUBDIR)))
    print(f"расхождений: {len(diff)} | лишнего в клоне: {len(extra)}")
    for kind, path in diff[:60]:
        print(f"  {kind:16} {path}")
    if len(diff) > 60:
        print(f"  ... ещё {len(diff) - 60}")
    for path in extra[:20]:
        print(f"  {'только в клоне':16} {path}")
    if len(extra) > 20:
        print(f"  ... ещё {len(extra) - 20}")
    return 0


def cmd_pull(force: bool = False) -> int:
    ensure_repo()
    git("fetch", push_url(), check=False)
    branch = git("rev-parse", "--abbrev-ref", "HEAD").stdout.strip() or "main"
    git("reset", "--hard", f"origin/{branch}", check=False)
    stamp = time.strftime("%Y-%m-%d_%H-%M-%S")
    bdir = BACKUP / f"skills-{stamp}"
    n = 0
    for rel in OUR:
        src = REPO / REPO_SUBDIR / rel
        if not src.exists():
            continue
        dst = SKILLS / rel
        if dst.exists():
            bdir.mkdir(parents=True, exist_ok=True)
            copy_tree(dst, bdir / rel)
        n += copy_tree(src, dst)
    print(f"разложено файлов: {n} | бэкап: {bdir if bdir.exists() else '(не потребовался)'}")
    return 0


def main() -> int:
    # крон читает наш stdout как UTF-8: не даём консольной кодировке испортить вывод
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass
    cmd = (sys.argv[1] if len(sys.argv) > 1 else "list").lower()
    if cmd == "list":
        return cmd_list()
    if cmd == "save":
        return cmd_save(" ".join(sys.argv[2:]))
    if cmd == "pull":
        return cmd_pull()
    if cmd == "status":
        return cmd_status()
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
