#!/usr/bin/env bash
set -Eeuo pipefail

ISO="${1:-rah-os-next/output/RAH-OS-Raven-v0.7-amd64.iso}"
WORK="${RAH_V07_INSPECT_DIR:-/tmp/rah-v07-check}"

pass(){ printf '[PASS] %s\n' "$*"; }
fail(){ printf '[FAIL] %s\n' "$*" >&2; exit 1; }

check_contains() {
  local file="$1" needle="$2" label="$3"
  if grep -Fq "$needle" "$file"; then
    pass "$label"
  else
    echo "----- $file -----" >&2
    sed -n '1,220p' "$file" >&2 || true
    echo "-----------------" >&2
    fail "$label: missing expected text: $needle"
  fi
}

check_squash_file() {
  local squash="$1" path="$2"
  if unsquashfs -cat "$squash" "$path" >/dev/null 2>&1; then
    pass "SquashFS contains $path"
  else
    fail "SquashFS is missing $path"
  fi
}

test -s "$ISO" || fail "ISO missing or empty: $ISO"
pass "ISO exists: $ISO ($(du -h "$ISO" | awk '{print $1}'))"

rm -rf "$WORK"
mkdir -p "$WORK"

xorriso -osirrox on -indev "$ISO" -extract /boot/grub/grub.cfg "$WORK/grub.cfg" >/dev/null 2>&1   || fail "Could not extract GRUB config"
pass "GRUB config extracted"

xorriso -osirrox on -indev "$ISO" -extract /isolinux/live.cfg "$WORK/live.cfg" >/dev/null 2>&1   || fail "Could not extract ISOLINUX config"
pass "ISOLINUX config extracted"

xorriso -osirrox on -indev "$ISO" -extract /live/filesystem.squashfs "$WORK/filesystem.squashfs" >/dev/null 2>&1   || fail "Could not extract filesystem.squashfs"
pass "SquashFS extracted"

check_contains "$WORK/grub.cfg" "RAH OS // GOLD SHELL" "UEFI/GRUB RAH Gold Shell branding"
check_contains "$WORK/live.cfg" "RAH OS v0.7 GOLD SHELL" "BIOS/ISOLINUX RAH Gold Shell branding"

for path in   usr/local/bin/rah-hub   usr/local/bin/rah-first-run   usr/local/bin/rah-live-acceptance   usr/share/plymouth/themes/rah-gold/rah-gold.plymouth   usr/share/plymouth/themes/rah-gold/rah-gold.script   usr/share/backgrounds/rah/rah-gold.svg   usr/share/icons/hicolor/scalable/apps/rah-raven.svg   usr/share/plasma/look-and-feel/org.rah.gold.desktop/contents/splash/Splash.qml   etc/skel/Desktop/RAH-Hub.desktop
do
  check_squash_file "$WORK/filesystem.squashfs" "$path"
done

unsquashfs -cat "$WORK/filesystem.squashfs" etc/rah-os-release > "$WORK/rah-os-release"   || fail "Could not read etc/rah-os-release"
check_contains "$WORK/rah-os-release" 'VERSION="0.7"' "RAH release version"

unsquashfs -cat "$WORK/filesystem.squashfs" etc/os-release > "$WORK/os-release"   || fail "Could not read etc/os-release"
check_contains "$WORK/os-release" 'ID=rah-os' "Visible OS identity is RAH OS"
check_contains "$WORK/os-release" 'ID_LIKE=debian' "Debian compatibility identity retained"

unsquashfs -cat "$WORK/filesystem.squashfs" usr/local/bin/rah-live-acceptance > "$WORK/accept.py"   || fail "Could not extract Live Acceptance"
python3 "$WORK/accept.py" --self-test
pass "Live Acceptance v0.7 self-test"

unsquashfs -cat "$WORK/filesystem.squashfs" usr/local/lib/rah/raven-agent.py > "$WORK/raven-agent.py"   || fail "Could not extract Raven Agent"
check_contains "$WORK/raven-agent.py" "RAH OS RAVEN v0.7 GOLD SHELL" "Raven landing page v0.7 identity"

(
  cd "$(dirname "$ISO")"
  sha256sum -c "$(basename "$ISO").sha256"
)
pass "ISO SHA-256 verified"

echo
echo "RAH OS v0.7.1 finished ISO inspection: PASS"
