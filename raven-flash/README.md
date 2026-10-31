# RAH AI Studios — Raven Flash R1.1 login fix

**Status: login fix candidate. Physical USB desktop acceptance remains pending.**

R1 reached the greeter on the user's PC but rejected `rah`. R1 disabled APT
recommends without explicitly including `user-setup`, so live-config could not
create the live user. `sudo` was also missing. R1.1 restores these prerequisites,
locales and keyboard configuration explicitly while keeping the minimal build.
The ISO is named `RAH-Raven-Flash-R1.1-amd64.iso` to distinguish it from R1.

The intended behavior is automatic login to Raven Flash. Manual live-session
credentials are **`rah` / `live`** (the upstream live-config default password).
They are public live-media defaults, not credentials for an installed system.

Raven Flash is a separate browser-first live operating-system candidate.
It has its own RAH visual identity. Under the hood it uses a standard live-build
base; no upstream branding is shown in the RAH interface.

- UEFI + legacy BIOS hybrid ISO candidate via live-build.
- Live session with RAM-backed overlay; no disk installer.
- Local offline start page at `file:///opt/raven-flash/start.html`.
- Chromium, Openbox, LightDM, NetworkManager and a small panel.
- Wi-Fi setup may be required. No personal credentials are embedded.
- External AI services are hyperlinks, not integrated local agents.
- 10–20-second boot is a target, not a measured result.

## Build

See `.github/workflows/build-raven-flash-r1.yml` in this PR. The workflow
validates source and builds a candidate ISO in an isolated runner.
Artifact outputs are SHA-256 checked and expire after 14 days.

A chroot build hook refuses to proceed without live-login prerequisites.
Before uploading an ISO, a diskless QEMU test boots its kernel/initrd and live
filesystem, actually logs in with `rah` / `live` via PAM, checks sudo, and checks
that LightDM autologin starts Openbox and Chromium. Serial-console parameters
are added only by the test; it does not verify firmware boot or physical GPUs.
Boot diagnostics are uploaded even on test failure; the ISO is uploaded only
after the boot test succeeds.

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
