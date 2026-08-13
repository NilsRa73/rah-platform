from pathlib import Path

replacements={
  'tests/raven-core-demo.test.mjs':[
    ('Raven Core Workflow v1\\.8','Raven Core Workflow v1\\.9'),
    ('Raven Core workflow v1.8 unified ChatGPT handoff center validation passed.','Raven Core workflow v1.9 source-aware ChatGPT handoff validation passed.'),
  ],
  'tests/raven-core-context.test.mjs':[
    ('RAH Raven Core Workflow v1\\.8','RAH Raven Core Workflow v1\\.9'),
    ('Core v1\\.8 · HANDOFF SESSION','Core v1\\.9 · SOURCE RETURN'),
    ('Raven Core v1.8 keeps Context Snapshot FORTSETT authority while unifying manual ChatGPT handoff controls.','Raven Core v1.9 keeps Context Snapshot FORTSETT authority with source-aware handoff return.'),
  ],
  'tests/raven-core-chatgpt-status.test.mjs':[
    ('RAH Raven Core Workflow v1\\.8','RAH Raven Core Workflow v1\\.9'),
    ('Core v1\\.8 · HANDOFF SESSION','Core v1\\.9 · SOURCE RETURN'),
    ('Raven Core v1.8 status handoff remains minimal, read-only and manual inside the unified handoff center.','Raven Core v1.9 status handoff remains minimal, read-only and manual inside the source-aware handoff center.'),
  ],
  'tests/raven-core-chatgpt-handoff-center.test.mjs':[
    ('RAH Raven Core Workflow v1\\.8','RAH Raven Core Workflow v1\\.9'),
    ('Core v1\\.8 · HANDOFF SESSION','Core v1\\.9 · SOURCE RETURN'),
    ('RAH Raven 2\\.0\\.22 · Core v1\\.8 support snapshot','RAH Raven 2\\.0\\.24 · Core v1\\.9 support snapshot'),
    ('Raven Core v1.8 adds a URL-only explicit handoff session without automatic sending.','Raven Core v1.9 adds source-aware URL-only handoff return without automatic sending.'),
  ],
  'tests/raven-vision-core.test.mjs':[
    ('RAH Raven Vision Core v0\\.4','RAH Raven Vision Core v0\\.5'),
    ('<span class="badge">v0\\.4<\\/span>','<span class="badge">v0\\.5<\\/span>'),
    ('Raven Vision Core v0.4 URL-only return handoff validation passed.','Raven Vision Core v0.5 source-preserving URL-only return handoff validation passed.'),
  ],
}
for name,pairs in replacements.items():
    path=Path(name)
    text=path.read_text(encoding='utf-8')
    for old,new in pairs:
        if old not in text:
            raise SystemExit(f'{name}: marker missing: {old}')
        text=text.replace(old,new)
    path.write_text(text,encoding='utf-8')
