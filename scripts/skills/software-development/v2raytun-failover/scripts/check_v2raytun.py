#!/usr/bin/env python3
"""check_v2raytun.py - проверка серверов v2RayTun + переключение активного.

Использование:
  python check_v2raytun.py            # список конфигов + TCP-статус
  python check_v2raytun.py --select <id>   # переключить активный (закрой v2RayTun!)
  python check_v2raytun.py --check-ip      # проверить реальный IP через прокси :10809
"""
import json, os, socket, subprocess, sys, time

def _find_pref():
    # реальный APPDATA (не портабельный %APPDATA% от Start.bat!)
    for u in ['rafst']:
        p = rf'C:\Users\{u}\AppData\Roaming\v2RayTun.net\v2RayTun\shared_preferences.json'
        if os.path.exists(p):
            return p
    # fallback: поиск по всем пользователям
    import glob
    hits = glob.glob(r'C:\Users\*\AppData\Roaming\v2RayTun.net\v2RayTun\shared_preferences.json')
    return hits[0] if hits else ''

PREF = _find_pref()


def load() -> dict:
    return json.load(open(PREF, encoding='utf-8'))


def tcp_check(host: str, port: int, timeout: float = 3.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def get_ip_via_proxy() -> str:
    try:
        out = subprocess.run(['curl', '--noproxy', '*', '-s', '--max-time', '8',
                              '-x', 'http://127.0.0.1:10809', 'https://api.ipify.org'],
                             capture_output=True, text=True, timeout=12)
        return out.stdout.strip()
    except Exception:
        return ''


def get_ip_direct() -> str:
    try:
        out = subprocess.run(['curl', '--noproxy', '*', '-s', '--max-time', '5',
                              'https://api.ipify.org'], capture_output=True, text=True, timeout=8)
        return out.stdout.strip()
    except Exception:
        return ''


def main():
    d = load()
    cfgs = {k.replace('flutter.config_', ''): v for k, v in d.items() if k.startswith('flutter.config_')}
    sel = d.get('flutter.selected_config', '')
    print(f'Активный: {sel}')

    if '--check-ip' in sys.argv:
        direct, proxied = get_ip_direct(), get_ip_via_proxy()
        print(f'Прямой IP : {direct or "(нет)"}')
        print(f'Через VPN: {proxied or "(нет)"}')
        ok = proxied and proxied != direct
        print('VPN туннелит:', 'ДА' if ok else 'НЕТ (failover нужен!)')
        return 0 if ok else 1

    alive = []
    for cid, raw in cfgs.items():
        try:
            c = json.loads(raw) if isinstance(raw, str) else raw
        except json.JSONDecodeError:
            continue
        ob = c.get('singBoxOutbound', {})
        host, port = ob.get('server', ''), ob.get('server_port', 0)
        rem = c.get('remarks', cid)
        up = tcp_check(host, port) if host else False
        mark = 'ЖИВ' if up else 'мёртв'
        cur = ' <- АКТИВНЫЙ' if cid == sel else ''
        print(f'  {mark:5} {cid[:12]} {rem[:28]:28} {host}:{port}{cur}')
        if up:
            alive.append(cid)

    if '--select' in sys.argv:
        target = sys.argv[sys.argv.index('--select') + 1]
        if target not in cfgs:
            print(f'ОШИБКА: конфиг {target} не найден')
            return 1
        # проверка: v2RayTun закрыт?
        procs = subprocess.run(['tasklist'], capture_output=True, text=True).stdout
        if 'v2RayTun.exe' in procs:
            print('ВНИМАНИЕ: v2RayTun ЗАПУЩЕН - правка затрется при закрытии! Закройте приложение.')
            return 2
        bak = PREF + '.bak'
        open(bak, 'w', encoding='utf-8').write(open(PREF, encoding='utf-8').read())
        d['flutter.selected_config'] = target
        open(PREF, 'w', encoding='utf-8').write(json.dumps(d, ensure_ascii=False, indent=2))
        print(f'Активный переключён на {target} (бэкап: {bak})')
        print('Запустите v2RayTun и проверьте IP: --check-ip')

    return 0


if __name__ == '__main__':
    sys.exit(main())
