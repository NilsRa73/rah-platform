from pathlib import Path

for path in Path('tests').glob('*.mjs'):
    text=path.read_text(encoding='utf-8')
    updated=text.replace('Core v1\\.10 · SOURCE RETURN','Core v1\\.10 · HANDOFF RESUME').replace('Core v1.10 · SOURCE RETURN','Core v1.10 · HANDOFF RESUME')
    if updated != text:
        path.write_text(updated,encoding='utf-8')
