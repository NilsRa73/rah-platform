# RAH AI Studios — Raven Flash R1.3 local first

**Status: source candidate; ISO build, browser rendering and physical boot
acceptance are pending. No world-record or measured boot-time claim.**

Raven Flash is a separate browser-first live OS candidate with RAH visual identity.
It uses a standard Linux/live-build base. R1.3 opens a self-contained local launcher
without waiting for internet. The launcher offers configurable local HTML and
server links, plus web services; each opens only on user choice in a new tab.
Native executables are not automatically downloaded or installed.

## What changed in R1.3

- Replaced the concept boot-menu HTML with the actual direct launcher. The page
  contains no external assets or initial fetches; CSP blocks network connections
  from the page itself. User-initiated navigation remains available.
- Masked NetworkManager-wait-online in this local-live image, retaining
  NetworkManager, Wi-Fi, DHCP and the ordinary Chromium sandbox.
- Selected SquashFS zstd level 3 for a fast-decompression A/B candidate. A larger
  image may cost more read time; speed must be measured on physical hardware.
- Added a read-only Linux boot report in the desktop right-click menu.
- Added the Windows `START-HER.cmd` companion for read-only boot inventory and
  `TRIPLE-BOOT.md` for a two-second-menu target. No boot menu is installed by it.
- Retained R1.2 Openbox session lifetime, browser profile continuity, last-session
  tab recovery, panel and keyboard shortcuts. Win+B reopens the browser; Win+H
  opens the local home page.

The HTML footer reports only this page's elapsed loading time, not OS boot time
or power-button-to-browser time. It does not claim connectivity based on
`navigator.onLine`. App addresses are entered by the user, not guessed.

## Live environment and prior login repair

Public live-media credentials: **rah / live**. Intended behavior is graphical
autologin. On 31 October 2026 the user reported physical boot and manual login;
this was not independent full hardware acceptance. R1.1 added missing user-setup,
sudo and related live-login prerequisites after R1 failed to create the user.
R1.2 made Openbox own the session so closing Chromium no longer ends the desktop,
and moved its profile out of the runtime directory.

The profile and configured links survive browser close within one live boot.
Power-off/reboot clears this RAM-backed live environment. No automatic persistence
or disk installer is provided. No Windows or RAH GOLD disk is changed.

## Build and validation

Run `bash raven-flash/build.sh` as root inside an isolated Linux builder with
live-build and ISO tools. Output: `RAH-Raven-Flash-R1.3-amd64.iso` and SHA-256.
The dedicated GitHub Actions workflow validates shell/Python/JS/configuration,
builds a BIOS+UEFI candidate, verifies ISO contents and checksum, then boots a
networkless diskless QEMU environment. Acceptance checks actual PAM login,
graphical autologin, a real Chromium window, offline local page opening, desktop
survival and two real tabs restoring after browser close/reopen.

QEMU uses extracted kernel/initrd, so this does not verify firmware bootloader
menus, Secure Boot, physical GPU/Wi-Fi or power-button boot speed. The ISO is
uploaded only after those automated checks pass. Artifacts expire after 14 days.

Local source checks:

```
python3 raven-flash/tests/test-session.py -v
python3 raven-flash/tests/test-local-first.py -v
node raven-flash/tests/test-start-page.cjs
```

The JS test executes actual launcher code in a minimal DOM; it is not a full
Chromium rendering test. Windows CMD behavior still requires physical Windows
acceptance. Starting the companion prompts for UAC only to read boot metadata;
reports stay local and are opened in Notepad and Explorer.

## Hardware gates

1. Obtain ISO from this candidate's successful build and verify its SHA-256.
2. Test on a separately prepared USB; do not install to internal disks.
3. Verify autologin, display, keyboard, network, local page and browser recovery.
4. Test ordinary Windows boot again with the USB removed.
5. Use five cold-start videos to measure power-button to clickable page, and
   measure real network readiness separately. Record median and best result.

Read `TRIPLE-BOOT.md` before boot-menu work and `RECORD-PLAN.md` for documentation.
A two-second selection timeout is a design target, not total boot time. No
firmware, BCD or EFI write is included in the Windows companion.
