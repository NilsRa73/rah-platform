#!/usr/bin/env bash
set -Eeuo pipefail
RAH_VERSION="0.7"
DIST="trixie"
ARCH="amd64"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${ROOT_DIR}/.." && pwd)"
STABLE_CONFIG="${REPO_DIR}/rah-os/config"
WORK_DIR="${ROOT_DIR}/.build"
OUT_DIR="${ROOT_DIR}/output"
log() { printf '\n[RAH OS v0.7 GOLD SHELL] %s\n' "$*"; }
if [[ ${EUID} -ne 0 ]]; then echo "This build script must run as root inside the CI/Linux builder." >&2; exit 1; fi
for cmd in lb debootstrap xorriso mksquashfs; do command -v "$cmd" >/dev/null 2>&1 || { echo "Missing build dependency: $cmd" >&2; exit 1; }; done
test -d "$STABLE_CONFIG" || { echo "Stable RAH OS config not found: $STABLE_CONFIG" >&2; exit 1; }
log "Preparing clean candidate workspace"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"
cd "$WORK_DIR"
log "Configuring Debian ${DIST} / ${ARCH} live ISO under RAH identity"
lb config noauto \
  --mode debian \
  --distribution "$DIST" \
  --architectures "$ARCH" \
  --binary-images iso-hybrid \
  --bootloaders "syslinux grub-efi" \
  --debian-installer live \
  --debian-installer-gui true \
  --archive-areas "main contrib non-free-firmware" \
  --security true \
  --updates true \
  --apt-recommends true \
  --iso-application "RAH OS Raven Gold Shell" \
  --iso-publisher "RAH AI Studios" \
  --iso-volume "RAH_OS_07" \
  --bootappend-live "boot=live components quiet splash username=rah hostname=rah-os locales=nb_NO.UTF-8 keyboard-layouts=no timezone=Europe/Oslo"
log "Applying v0.3 Stable payload as immutable base"
cp -a "${STABLE_CONFIG}/." "${WORK_DIR}/config/"
log "Overlaying v0.7 Gold Shell branding and integration"
cp -a "${ROOT_DIR}/config/." "${WORK_DIR}/config/"
log "Building RAH OS v0.7 candidate ISO"
lb build
ISO_SRC="$(find "$WORK_DIR" -maxdepth 1 -type f \( -name '*.hybrid.iso' -o -name '*.iso' \) | head -n 1 || true)"
if [[ -z "$ISO_SRC" || ! -f "$ISO_SRC" ]]; then echo "Build completed but no ISO was found." >&2; exit 1; fi
ISO_DST="${OUT_DIR}/RAH-OS-Raven-v${RAH_VERSION}-${ARCH}.iso"
cp "$ISO_SRC" "$ISO_DST"
( cd "$OUT_DIR"; sha256sum "$(basename "$ISO_DST")" > "$(basename "$ISO_DST").sha256" )
log "READY: ${ISO_DST}"
