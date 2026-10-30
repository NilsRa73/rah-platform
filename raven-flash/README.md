# RAH AI Studios — Raven Flash R1

**Status: source candidate + visual preview. Not yet hardware-boot tested.**

Raven Flash is a separate browser-first live operating-system candidate.
It has its own RAH visual identity. Under the hood it uses a standard live-build
base; no upstream branding is shown in the RAH interface.

- UEFI + legacy BIOS hybrid ISO candidate via live-build.
- Live session with RAM-backed overlay; no disk installer.
- Local offline start page at `file:///opt/raven-flash/start.html`.
- Chromium, Openbox, LightDM, NetworkManager and a small panel.
- Wi-Fi setup may be required. No credentials are embedded.
- External AI services are hyperlinks, not integrated local agents.
- 10–20-second boot is a target, not a measured result.

## Build

See `.github/workflows/build-raven-flash-r1.yml` in this PR. The workflow
validates source and attempts a candidate ISO build in an isolated runner.
Artifact outputs are SHA-256 checked and expire after 14 days.

## Safe hardware acceptance

1. Obtain ISO from a *successful* CI build and verify SHA-256.
2. Copy ISO onto a separate USB previously prepared with Ventoy.
3. Select USB with the PC's one-time UEFI/BIOS boot menu.
4. Use live mode only. Do not install or enable persistence.
5. Confirm display, keyboard, network and browser.
6. Power off, remove USB, and verify ordinary Windows boot.

If Secure Boot blocks the candidate, do not change the firmware automatically.
The existing RAH OS, Windows and RAH GOLD remain untouched.

## Gates

- [ ] CI-built and verified ISO
- [ ] Boot tested on actual hardware
- [ ] Network and Wi-Fi tested
- [ ] Windows normal boot rechecked after USB removal
