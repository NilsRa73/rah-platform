from pathlib import Path
p=Path('.github/scripts/build_raven_2_0_22.py')
s=p.read_text(encoding='utf-8')
old_click='      link.click();\n      setTimeout(() => URL.revokeObjectURL(url), 1000);'
new_click='      link.click();\n      link.remove();\n      setTimeout(() => URL.revokeObjectURL(url), 1000);'
if s.count(old_click) != 2:
    raise SystemExit(f'expected 2 old PNG click markers, found {s.count(old_click)}')
s=s.replace(old_click,new_click)
old1='PNG er lagret etter ditt klikk. Dra Raven-Vision-Latest.png inn i ChatGPT.'
new1='PNG er laget. Dra Raven-Vision-Latest.png inn i ChatGPT. Raven sender ingenting automatisk.'
old2='PNG er lagret etter ditt klikk. Dra Raven-Vision-Latest.png inn i ChatGPT. TILBAKE TIL HANDOFF tar deg tilbake til Core.'
new2='PNG er laget. Dra Raven-Vision-Latest.png inn i ChatGPT. Raven sender ingenting automatisk. TILBAKE TIL HANDOFF tar deg tilbake til Core.'
if old1 not in s or old2 not in s:
    raise SystemExit('expected old PNG status strings were not found')
s=s.replace(old2,new2,1).replace(old1,new1,1)
p.write_text(s,encoding='utf-8')
