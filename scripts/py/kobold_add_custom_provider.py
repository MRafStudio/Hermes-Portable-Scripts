# kobold_add_custom_provider.py — вставка custom_providers (enable_thinking:false) в config.yaml
# Использование: python kobold_add_custom_provider.py <CONFIG_YAML> <MODEL_ID> <BASE_URL>
import sys

cfg = sys.argv[1]
model = sys.argv[2]
base_url = sys.argv[3]

sec = (
    '\n'
    '# KoboldCPP (Qwythos): enable_thinking:false — чище tool-calls\n'
    'custom_providers:\n'
    '  - name: kobold\n'
    '    base_url: ' + base_url + '\n'
    '    api_mode: openai\n'
    '    model: ' + model + '\n'
    '    extra_body:\n'
    '      chat_template_kwargs:\n'
    '        enable_thinking: false\n'
)

raw = open(cfg, 'rb').read()
if b'custom_providers:' in raw:
    print('custom_providers already present — пропуск')
    sys.exit(0)

if not raw.endswith(b'\n'):
    sec = '\n' + sec
open(cfg, 'ab').write(sec.encode('utf-8'))
print('custom_providers appended to', cfg)
