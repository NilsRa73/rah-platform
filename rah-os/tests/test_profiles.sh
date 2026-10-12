#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="$ROOT/config/includes.chroot/usr/local/bin/rah-profile-session"
NOVA="$ROOT/config/includes.chroot/usr/local/bin/rah-nova-shell"
GHOST="$ROOT/config/includes.chroot/usr/local/bin/rah-ghost"
GRUB="$ROOT/config/bootloaders/grub-pc/grub.cfg"
ISO="$ROOT/config/bootloaders/isolinux/live.cfg.in"

fail() { echo "[FAIL] $*" >&2; exit 1; }
pass() { echo "[PASS] $*"; }
assert_eq() { [[ "$1" == "$2" ]] || fail "$3: expected '$2', got '$1'"; pass "$3"; }

for p in standard nova rescue forge arcade; do
  got="$(RAH_PROFILE="$p" bash "$PROFILE" --resolve-only)"
  assert_eq "$got" "$p" "environment profile $p resolves"
done

assert_eq "$(RAH_PROFILE=garbage bash "$PROFILE" --resolve-only)" standard "unknown profile falls back safely"
assert_eq "$(env -u RAH_PROFILE RAH_CMDLINE='quiet splash rah.profile=nova' bash "$PROFILE" --resolve-only)" nova "kernel-style cmdline selects Nova"
assert_eq "$(env -u RAH_PROFILE RAH_CMDLINE='rah.profile=forge rah.profile=arcade' bash "$PROFILE" --resolve-only)" arcade "last kernel profile wins deterministically"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
HOME="$TMP" RAH_PROFILE=rescue RAH_SESSION_DELAY=0 RAH_PROFILE_DRY_RUN=1 bash "$PROFILE" >/dev/null
assert_eq "$(cat "$TMP/.cache/rah-os/profile")" rescue "dry-run records selected profile without launching GUI"

python3 -m py_compile "$NOVA"
pass "Nova VI controller shell compiles"

for file in "$GRUB" "$ISO"; do
  for pair in \
    'rah.profile=standard' \
    'rah.profile=nova' \
    'rah.profile=rescue' \
    'rah.profile=forge' \
    'rah.profile=arcade'
  do
    grep -Fq "$pair" "$file" || fail "$(basename "$file") missing $pair"
  done
  pass "$(basename "$file") contains all five RAH profiles"

  grep -Fq 'INSTALL RAH OS // GRAPHICAL SETUP' "$file" || fail "$(basename "$file") missing RAH installer branding"
  grep -Fq 'RAH SYSTEM TOOLS // INSTALL' "$file" || fail "$(basename "$file") missing RAH system-tools branding"
  if grep -Fiq 'Debian' "$file"; then
    fail "$(basename "$file") exposes Debian branding in the visible boot menu"
  fi
  pass "$(basename "$file") exposes RAH-only visible boot branding"
done

grep -Fq -- '--erase-target' "$GHOST" || fail "Ghost restore erase gate missing"
grep -Fq 'ERASE $target' "$GHOST" || fail "Ghost typed confirmation gate missing"
grep -Fq 'mounted_children' "$GHOST" || fail "Ghost mounted-target guard missing"
pass "Ghost destructive restore retains three independent safety gates"

echo "RAH OS v0.3 profile + boot-branding contract: PASS"
