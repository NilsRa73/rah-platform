#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK="$ROOT/.build"
OUT="$ROOT/output"
ISO="$OUT/RAH-Raven-Flash-R1.2-amd64.iso"
if [ "$(id -u)" -ne 0 ]; then echo 'Run inside isolated Linux CI builder as root.' >&2; exit 1; fi
for x in lb xorriso; do command -v "$x" >/dev/null 2>&1 || { echo "Missing tool: $x" >&2; exit 1; }; done
mkdir -p "$OUT"
rm -rf "$WORK"
mkdir -p "$WORK"
cd "$WORK"
lb config noauto \
  --mode debian \
  --distribution trixie \
  --architectures amd64 \
  --binary-images iso-hybrid \
  --bootloaders 'syslinux grub-efi' \
  --debian-installer none \
  --archive-areas 'main non-free-firmware' \
  --apt-recommends false \
  --iso-application 'RAH Raven Flash R1.2 Live' \
  --iso-publisher 'RAH AI Studios' \
  --iso-volume 'RAVEN_FLASH_R12' \
  --bootappend-live 'boot=live components quiet username=rah hostname=raven-flash locales=nb_NO.UTF-8 keyboard-layouts=no timezone=Europe/Oslo'
cp -a "$ROOT/config/." "$WORK/config/"
chmod 755 "$WORK/config/includes.chroot/usr/local/bin/raven-flash-session"
chmod 755 "$WORK/config/includes.chroot/usr/local/bin/raven-flash-browser"
chmod 755 "$WORK/config/hooks/live/0200-raven-login-check.hook.chroot"
lb build
SOURCE="$(find "$WORK" -maxdepth 1 -type f \( -name '*.hybrid.iso' -o -name '*.iso' \) | head -n 1)"
[ -s "$SOURCE" ] || { echo 'No ISO produced' >&2; exit 1; }
cp "$SOURCE" "$ISO"
(cd "$OUT" && sha256sum "$(basename "$ISO")" > "$(basename "$ISO").sha256")
echo "Candidate ISO ready: $ISO"
echo 'Hardware UEFI/BIOS and Wi-Fi tests remain PENDING.'

