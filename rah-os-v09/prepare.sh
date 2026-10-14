#!/usr/bin/env bash
set -Eeuo pipefail
# Copy pinned v0.4 source to independent v0.9 staging without editing v0.4.
if [[ $# -ne 2 ]]; then echo 'Usage: prepare.sh BASELINE_REPO STAGED_OUTPUT' >&2; exit 2; fi
SRC="$(cd "$1" && pwd -P)"; OUT="$2"
[[ -f "$SRC/rah-os/build.sh" ]] || { echo 'Missing upstream rah-os/build.sh' >&2; exit 3; }
[[ ! -e "$OUT" ]] || { echo 'Candidate destination already exists; refusing overwrite' >&2; exit 4; }
mkdir -p "$OUT"
cp -a "$SRC/rah-os/." "$OUT/"
cp -a "$(dirname "$0")/overlay/." "$OUT/config/includes.chroot/"
export RAH_V09_STAGE="$OUT"
python3 - <<'PY'
import json,os
from pathlib import Path
root=Path(os.environ['RAH_V09_STAGE'])
def substitute(path,old,new,expected=1):
    p=root/path; t=p.read_text(encoding='utf-8'); num=t.count(old)
    if num!=expected: raise RuntimeError(f'{path}: expected {expected} occurrences of {old!r}; got {num}')
    p.write_text(t.replace(old,new),encoding='utf-8')
substitute('build.sh','RAH_VERSION="0.4"','RAH_VERSION="0.9"')
substitute('build.sh','--iso-volume "RAH_OS_04"','--iso-volume "RAH_OS_09"')
substitute('config/includes.chroot/etc/rah-os-release','VERSION="0.4"','VERSION="0.9"')
substitute('config/includes.chroot/etc/rah-os-release','EDITION="Raven v0.4 Command Deck Candidate"','EDITION="Raven v0.9 Command Deck ISO Candidate"')
a='config/includes.chroot/usr/local/bin/rah-live-acceptance'
substitute(a,'EXPECTED_OS_VERSION = "0.4"','EXPECTED_OS_VERSION = "0.9"')
substitute(a,'RAH OS v0.4 is Candidate','RAH OS v0.9 is Candidate',expected=2)
substitute(a,'RAH OS v0.4 live acceptance self-test','RAH OS v0.9 live acceptance self-test')
substitute(a,'RAH OS v0.4 read-only Live USB acceptance','RAH OS v0.9 read-only Live USB acceptance')
substitute(a,'VERSION="0.4"\nPROFILES','VERSION="0.9"\nPROFILES')
p=root/'RAH-OS-VERSION.json';obj=json.loads(p.read_text(encoding='utf-8'))
assert (obj['version'],obj['stage'])==('0.4.0','candidate')
obj['version']='0.9.0';obj['stage']='candidate'
obj['baseline']='RAH OS Raven v0.4.0 candidate (preserved)'
obj['candidate_date']='2026-10-14'
obj['features']['black_gold_v09_desktop_deck']=True
obj['stable_gate']['real_hardware_boot_passed']=False
obj['stable_gate']['report_reviewed']=False
obj['ci_gate']['status']='pending'
obj['next_action']='Build candidate, inspect BIOS/UEFI, Live USB test on OMEN and Lenovo before promotion.'
p.write_text(json.dumps(obj,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
PY
chmod +x "$OUT/config/includes.chroot/usr/local/bin/rah-v09-open-deck"
chmod +x "$OUT/config/includes.chroot/etc/skel/Desktop/RAH-v0.9-Command-Deck.desktop"
python3 -m py_compile "$OUT/config/includes.chroot/usr/local/bin/rah-live-acceptance"
python3 "$OUT/config/includes.chroot/usr/local/bin/rah-live-acceptance" --self-test
bash -n "$OUT/build.sh" "$OUT/config/includes.chroot/usr/local/bin/rah-v09-open-deck"
grep -Fqx 'VERSION="0.9"' "$OUT/config/includes.chroot/etc/rah-os-release"
[[ -f "$OUT/config/includes.chroot/etc/skel/Desktop/RAH-v0.9-Command-Deck.desktop" ]]
echo 'PASS: isolated v0.9 candidate staged; ISO NOT YET BUILT'
