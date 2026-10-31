# RAH AI Studios — Raven Flash R1.2 session recovery

**Status: R1.2 source candidate; new ISO acceptance pending.**

On 31 October 2026 Nils reported that Raven Flash boots on his physical PC and
manual login with `rah` / `live` works. He also reported that closing the browser
returns to the login screen and loses all tabs. This is a user report, not an
independently observed full hardware acceptance.

R1.1 executed Chromium as the login session and put its profile in the runtime
directory. Browser close therefore ended the desktop; logout could discard that
profile. R1.2 makes Openbox own the login session, moves the browser profile into
the live user's home, and requests last-session tab recovery. The panel, right
click menu and Win+B reopen the browser. Win+H opens the Raven start page.

**Same live boot only:** closing/reopening the browser and logging out/in preserve
the home profile. Power-off/reboot still clears this RAM-backed live environment.
No internal Windows disk or USB persistence is enabled automatically. Existing
tabs already lost from R1.1 cannot be promised recoverable.

R1 reached the greeter on the user's PC but rejected `rah`. R1 disabled APT
recommends without explicitly including `user-setup`, so live-config could not
create the live user. `sudo` was also missing. R1.1 restores these prerequisites,
locales and keyboard configuration explicitly while keeping the minimal build.
The current ISO is named `RAH-Raven-Flash-R1.2-amd64.iso`.

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
that LightDM autologin starts Openbox and Chromium. R1.2 additionally closes the
real Chromium window, checks that the same Openbox stays alive, opens two local
test tabs, closes/reopens Chromium and verifies both URLs through a loopback-only
test debugging port. That port is never enabled by normal launchers. No internet
or host disk is exposed to the guest. Serial-console parameters
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

See `RECORD-PLAN.md` for the proposed display-count record investigation and
separate boot-speed measurements. No world record is claimed by this project.

