# RAH OS Raven v0.3 Multi-Profile Candidate

RAH OS v0.3 is one Debian 13 live/install base with five boot personalities. The profiles share the same filesystem, drivers and Raven Core; the boot menu selects the session with the `rah.profile=` kernel parameter.

## Profiles

1. **RAH OS Standard** (`rah.profile=standard`) — KDE Plasma desktop and Raven Command Center.
2. **RAH Nova VI** (`rah.profile=nova`) — controller-first full-screen RAH shell with keyboard/mouse fallback.
3. **RAH Ghost & Rescue** (`rah.profile=rescue`) — recovery workspace with hardware/storage tools and RAH Ghost imaging.
4. **RAH Forge** (`rah.profile=forge`) — Raven + browser + developer terminal workspace.
5. **RAH Arcade Nexus** (`rah.profile=arcade`) — controller-first RetroArch/media launcher. No commercial ROMs are bundled.

## Multiboot design

The ISO carries both Syslinux/ISOLINUX for legacy BIOS and GRUB EFI for UEFI. Both menus expose the same five profiles plus an advanced/recovery/install path. The canonical CI build opens the completed ISO after live-build finishes and verifies both boot menus, the UEFI and BIOS boot payloads, the squashfs runtime files, the v0.3 release marker and the ISO SHA-256 checksum.

## Ghost safety

`rah-ghost create` images a selected block device to a normal file and writes a SHA-256 sidecar. `rah-ghost verify` checks that image. Restore is deliberately guarded: the target must be a block device, `--erase-target` is mandatory, mounted target/child partitions are refused, and the operator must type `ERASE /dev/TARGET` exactly before any write starts.

## Candidate gate

A v0.3 ISO is a download candidate only after all three GitHub jobs pass:

- Raven + profile self-tests
- Windows USB prep self-test
- Full Debian 13 ISO build + finished-image inspection

Do not overwrite an internal SSD merely because the ISO built successfully. First boot the candidate as a live USB and run RAH Hardware Check on the actual target machine.
