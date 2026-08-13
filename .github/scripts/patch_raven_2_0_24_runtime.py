from pathlib import Path
path=Path('RAH-RAVEN-VISION-CORE.html')
text=path.read_text(encoding='utf-8')
old='<span class="badge">v0.4</span>'
new='<span class="badge">v0.5</span>'
if old not in text:
    raise SystemExit('Vision badge marker missing')
path.write_text(text.replace(old,new,1),encoding='utf-8')
