# llama_bench.py — бенчмарк локальных моделей llama.cpp (Hermes Portable)
# Прогоняет набор промптов через OpenAI-совместимый API llama-server и
# снимает замеры: TTFT (префилл), скорость генерации, валидность JSON, vision.
#
# Использование:
#   python llama_bench.py --port 5505 --label "Qwen-3.6-35B-A3B UD-IQ4_NL"
#   python llama_bench.py --port 5505 --image C:\path\test.png --max-tokens 768
#
# Выход — таблица: тест | prompt tok | compl tok | префилл,с | t/s | json | время,с
import argparse
import base64
import json
import sys
import time
import urllib.request

try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

TEST_IMAGE = None  # заполняется из --image


def call(base, model, messages, max_tokens, extra=None, timeout=300):
    """Один chat-completion; возвращает (content, reasoning, usage, timings, wall)."""
    body = {"model": model, "messages": messages, "max_tokens": max_tokens}
    if extra:
        body.update(extra)
    t0 = time.time()
    req = urllib.request.Request(
        f"{base}/chat/completions",
        data=json.dumps(body).encode("utf-8"),
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        resp = json.loads(r.read().decode("utf-8"))
    wall = time.time() - t0
    msg = resp["choices"][0]["message"]
    return (
        msg.get("content") or "",
        msg.get("reasoning_content") or "",
        resp.get("usage", {}),
        resp.get("timings", {}),
        wall,
    )


def try_json(text):
    """Пытается распарсить JSON (вырезает ```json-обёртки)."""
    t = text.strip()
    if t.startswith("```"):
        lines = t.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].strip() == "```":
            lines = lines[:-1]
        t = "\n".join(lines).strip()
    try:
        json.loads(t)
        return True
    except Exception:
        return False


def run_test(base, model, name, messages, max_tokens, extra=None):
    try:
        content, reasoning, usage, t, wall = call(base, model, messages, max_tokens, extra)
    except Exception as e:
        print(f"  {name:<22} ОШИБКА: {e}")
        return None
    pps = t.get("prompt_per_second", 0) or 0
    pred = t.get("predicted_per_second", 0) or 0
    json_ok = try_json(content) if "json" in name.lower() else ""
    print(
        f"  {name:<22} prompt={usage.get('prompt_tokens', 0):>5}  "
        f"compl={usage.get('completion_tokens', 0):>5}  "
        f"prefill={pps:>6.0f} tok/s  gen={pred:>6.0f} tok/s  "
        f"json={'OK' if json_ok else ('' if json_ok == '' else 'FAIL')}  "
        f"wall={wall:>6.1f}s  think={len(reasoning):>5}ch  answer={content[:40]!r}"
    )
    return {"name": name, "usage": usage, "timings": t, "wall": wall, "json": json_ok, "content": content, "reasoning": reasoning}


def main():
    ap = argparse.ArgumentParser(description="Бенчмарк llama.cpp моделей")
    ap.add_argument("--port", type=int, default=5505)
    ap.add_argument("--label", default="", help="имя модели для отчёта")
    ap.add_argument("--max-tokens", type=int, default=1024)
    ap.add_argument("--image", default="", help="путь к картинке для vision-теста")
    args = ap.parse_args()

    base = f"http://127.0.0.1:{args.port}/v1"
    with urllib.request.urlopen(urllib.request.Request(f"{base}/models"), timeout=8) as r:
        models = json.loads(r.read().decode("utf-8"))
    model = models["data"][0]["id"]
    print(f"=== Модель: {args.label or model}  (порт {args.port}, max_tokens={args.max_tokens}) ===\n")

    results = []

    # 1. Приветствие (EN, коротко)
    results.append(run_test(base, model, "hello (en, 256)", [
        {"role": "user", "content": "Reply with exactly: Hello world."},
    ], 256))

    # 2. Русский, с думанием (реалистичный сценарий)
    results.append(run_test(base, model, "russian (1024)", [
        {"role": "user", "content": "Что такое REST API? Объясни за 3 предложения."},
    ], 1024))

    # 3. Русский, без думания (чистая генерация)
    results.append(run_test(base, model, "russian none (512)", [
        {"role": "user", "content": "Что такое REST API? Объясни за 3 предложения."},
    ], 512, {"reasoning_effort": "none"}))

    # 4. Код
    results.append(run_test(base, model, "code (1024)", [
        {"role": "user", "content": "Write a Python function that computes fibonacci numbers iteratively, with docstring."},
    ], 1024))

    # 5. Строгий JSON (как L3-промпт MemOS)
    results.append(run_test(base, model, "json (2048)", [
        {"role": "system", "content": "You are a data extraction engine. Return ONLY valid JSON, no markdown fences."},
        {"role": "user", "content": 'Analyze the following and return JSON with keys: "title" (string), "summary" (string), "tags" (array of 3 strings), "steps" (array of 3 objects each with "name" and "duration_min"). Topic: setting up IIS URL Rewrite for an SPA.'},
    ], 2048))

    # 6. Vision (если задана картинка)
    if args.image:
        try:
            with open(args.image, "rb") as f:
                b64 = base64.b64encode(f.read()).decode("ascii")
            results.append(run_test(base, model, "vision (128)", [
                {"role": "user", "content": [
                    {"type": "text", "text": "Describe this image in 2 sentences."},
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
                ]},
            ], 512))
        except Exception as e:
            print(f"  vision ОШИБКА: {e}")

    print("\n=== ИТОГ ===")
    for r in results:
        if not r:
            continue
        t = r["timings"]
        u = r["usage"]
        print(
            f"  {r['name']:<22} prompt={u.get('prompt_tokens', 0):>5}  compl={u.get('completion_tokens', 0):>5}  "
            f"gen={t.get('predicted_per_second', 0):>6.0f} tok/s  wall={r['wall']:>6.1f}s"
        )


if __name__ == "__main__":
    main()
