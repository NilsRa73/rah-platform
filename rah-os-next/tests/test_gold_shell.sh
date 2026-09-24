#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail(){ echo "[FAIL] $*" >&2; exit 1; }
pass(){ echo "[PASS] $*"; }
bash -n "$ROOT/build.sh"
bash -n "$ROOT/config/hooks/live/020-rah-gold-shell.hook.chroot"
bash -n "$ROOT/config/includes.chroot/usr/local/bin/rah-hub"
bash -n "$ROOT/config/includes.chroot/usr/local/bin/rah-first-run"
pass "shell syntax"
grep -Fq 'RAH OS // GOLD SHELL' "$ROOT/config/bootloaders/grub-pc/grub.cfg" || fail "GRUB RAH title missing"
grep -Fq 'RAH OS v0.7 GOLD SHELL' "$ROOT/config/bootloaders/isolinux/live.cfg.in" || fail "ISOLINUX RAH title missing"
! grep -Fiq 'Debian' "$ROOT/config/bootloaders/grub-pc/grub.cfg" || fail "visible Debian branding leaked into GRUB menu"
! grep -Fiq 'Debian' "$ROOT/config/bootloaders/isolinux/live.cfg.in" || fail "visible Debian branding leaked into ISOLINUX menu"
pass "boot branding"
grep -Fq 'ID=rah-os' "$ROOT/config/hooks/live/020-rah-gold-shell.hook.chroot" || fail "RAH os-release identity missing"
grep -Fq 'ID_LIKE=debian' "$ROOT/config/hooks/live/020-rah-gold-shell.hook.chroot" || fail "Debian compatibility identity missing"
grep -Fq 'LookAndFeelPackage=org.rah.gold.desktop' "$ROOT/config/includes.chroot/etc/skel/.config/kdeglobals" || fail "RAH look-and-feel not selected"
grep -Fq 'background=/usr/share/backgrounds/rah/rah-gold.svg' "$ROOT/config/includes.chroot/usr/share/sddm/themes/breeze/theme.conf.user" || fail "SDDM background missing"
pass "desktop/login identity"
hub="$ROOT/config/includes.chroot/usr/local/bin/rah-hub"
for action in command hardware rescue nova acceptance files system; do grep -Fq "$action" "$hub" || fail "RAH Hub action missing: $action"; done
! grep -Fiq 'eval ' "$hub" || fail "RAH Hub must not eval arbitrary input"
pass "RAH Hub fixed allowlist"
python3 "$ROOT/config/includes.chroot/usr/local/bin/rah-live-acceptance" --self-test
grep -Fq 'RAH OS RAVEN v0.7 GOLD SHELL' "$ROOT/config/includes.chroot/usr/local/lib/rah/raven-agent.py" || fail "Raven page not v0.7 branded"
pass "v0.7 runtime identity"
python3 - "$ROOT/RAH-OS-VERSION.json" <<'PY'
import json,sys
m=json.load(open(sys.argv[1],encoding="utf-8"))
assert m["version"]=="0.7.0-dev"
assert m["stage"]=="development-candidate"
assert m["stable_base"]["version"]=="0.3.0"
assert m["release_gate"]["status"]=="pending"
assert m["safety_boundary"]["automatic_stable_promotion"] is False
PY
pass "candidate manifest"
echo "RAH OS v0.7 Gold Shell contract: PASS"
