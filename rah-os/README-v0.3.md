# RAH OS Raven v0.3 Multi-Profile Candidate

RAH OS is an experimental Debian 13 (trixie) desktop distribution for the RAH/Raven ecosystem. v0.3 is now the canonical Candidate on `main`.

## Five boot profiles

1. **RAH OS Standard** — KDE Plasma + Raven Command Center.
2. **RAH Nova VI** — controller-first full-screen RAH shell.
3. **RAH Ghost & Rescue** — recovery workspace with guarded imaging/restore tools.
4. **RAH Forge** — Raven + browser + developer terminal workspace.
5. **RAH Arcade Nexus** — controller-first RetroArch/media shell. No commercial ROMs are bundled.

Both legacy BIOS (Syslinux/ISOLINUX) and UEFI (GRUB EFI) expose the same five profiles through the `rah.profile=` kernel parameter.

## CI status

The v0.3 candidate has passed repository validation for:

- Raven HTTP/diagnostics tests;
- all five profile contracts;
- Windows read-only USB-prep self-test;
- full Debian 13 ISO build;
- finished ISO BIOS + UEFI payload inspection;
- SquashFS runtime inspection;
- SHA-256 verification and artifact upload.

The canonical machine-readable status is `RAH-OS-VERSION.json`.

## Windows USB preparation

On Windows, double-click:

`START-HER.cmd`

It runs `RAH-OS-USB-PREP.ps1` read-only. It locates the candidate ISO, verifies SHA-256 when a sidecar is present, inventories USB disks, flags Windows system/boot disks, detects common flashing tools, and writes a preparation report. It never formats, partitions or flashes a disk.

The actual USB write remains an explicit action in Rufus, balenaEtcher or Ventoy after you have checked the target drive.

## One-click Live USB acceptance

After booting the candidate USB, double-click **RAH Live Acceptance** on the desktop.

The acceptance tool:

- confirms RAH OS v0.3 and `boot=live`;
- records which of the five profiles is active;
- verifies the local Raven health endpoint and systemd service;
- reads the existing hardware diagnostics;
- requires network, display and GPU checks to be ready for a full PASS;
- saves a privacy-safe JSON report in `~/Downloads`;
- never writes to a block device or changes partitions;
- never promotes RAH OS to Stable automatically.

Exit/result semantics are:

- **PASS** — eligible for human Stable review;
- **PENDING** — boot worked but one or more hardware checks need attention;
- **FAIL** — wrong OS/live context or a required Raven/diagnostics contract failed.

## Stable gate

RAH OS v0.3 remains **Candidate** until a real target machine produces a PASS `rah-os-live-acceptance-v1` report. A PASS report is evidence for Stable review; it is not an automatic promotion.

Do not overwrite an internal SSD merely because CI or the Live USB check passes. Installation to internal storage remains a separate explicit user action.

## Safety model

The Raven service remains local and unprivileged on `127.0.0.1:18765`. There is no generic shell endpoint, package-install endpoint, remote-control authority or automatic disk write. RAH Ghost restore remains separately guarded by a block-device check, explicit `--erase-target`, mounted-target refusal and exact typed confirmation.

## Historical note

This file is retained as the v0.3-specific guide. The canonical RAH OS README now carries the same current Candidate status and acceptance flow.
