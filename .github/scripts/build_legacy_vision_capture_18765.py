from pathlib import Path

index_path = Path('index.html')
readme_path = Path('README.md')
index_text = index_path.read_text(encoding='utf-8')
readme_text = readme_path.read_text(encoding='utf-8')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 baseline match, got {count}')
    return text.replace(old, new, 1)


index_text = replace_once(
    index_text,
    'http://127.0.0.1:8765/capture/active-window',
    'http://127.0.0.1:18765/capture/active-window',
    'index capture endpoint',
)

readme_text = replace_once(
    readme_text,
    'python server.py',
    'python raven_bridge.py',
    'README canonical Bridge entrypoint',
)
readme_text = replace_once(
    readme_text,
    'http://127.0.0.1:8765/health',
    'http://127.0.0.1:18765/health',
    'README health endpoint',
)
readme_text = replace_once(
    readme_text,
    'http://127.0.0.1:8765/capture/active-window',
    'http://127.0.0.1:18765/capture/active-window',
    'README capture endpoint',
)

if ':8765' in index_text:
    raise SystemExit('index.html still contains retired :8765')
if ':8765' in readme_text:
    raise SystemExit('README.md still contains retired :8765')
for required in (
    'http://127.0.0.1:18765/capture/active-window',
):
    if required not in index_text:
        raise SystemExit(f'index.html missing postcondition: {required}')
for required in (
    'python raven_bridge.py',
    'http://127.0.0.1:18765/health',
    'http://127.0.0.1:18765/capture/active-window',
):
    if required not in readme_text:
        raise SystemExit(f'README.md missing postcondition: {required}')

index_path.write_text(index_text, encoding='utf-8')
readme_path.write_text(readme_text, encoding='utf-8')
print('legacy Vision capture/docs canonical 18765 transform: PASS')
