#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
required=(
  'RAH-AI-INVESTIGATOR.html'
  'rah_investigator.py'
  'RAH-INVESTIGATOR-VERSION.json'
  'CHECK-RAH-INVESTIGATOR.ps1'
  'RUN-ME-FIRST-RAH-INVESTIGATOR.bat'
)
for name in "${required[@]}"; do
  test -f "$ROOT/$name" || { echo "Missing required Investigator file: $name" >&2; exit 2; }
done
python3 -m py_compile "$ROOT/rah_investigator.py"
python3 "$ROOT/rah_investigator.py" self-test
python3 - "$ROOT/RAH-INVESTIGATOR-VERSION.json" <<'PY'
import json, pathlib, sys
m=json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
assert m['product']=='RAH AI Investigator'
assert m['version']=='1.0-RC2'
assert m['stage']=='candidate'
assert m['scope']=='personal account recovery and authorized personal OSINT'
assert m['local_first'] is True
assert m['paid_services_required'] is False
assert m['validation']['stable_release_gate'] is False
PY
echo 'RAH AI Investigator v1.0 RC2 Kali-compatible local self-check PASS'
