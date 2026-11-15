# RAH Network Commander R1 — Raven Flash / RAH OS

**Status:** Offline GUI prototype in an isolated candidate branch. Not yet a live scanner, remote-control daemon, device-agent registry, or completed RAH OS integration. No changes to Windows, Ventoy, F:, EFI/BCD, existing RAH GOLD, or main branch.

## Open it
- Boot Raven Flash candidate and choose **RAH Network Commander** from the Openbox right-click menu; or open Raven launcher / RAH Gold and select the network panel.
- On Windows for UI-only preview, open the network.html file locally. Its file:///opt/raven-flash/ return links are intended for the Linux ISO.
- The Chrome Remote Desktop button opens https://remotedesktop.google.com/access. You must already have Chrome Remote Desktop host installed and signed in on the remote Windows/Mac/Linux PC. A hyperlink does not install the host.
- The Android buttons open RustDesk and scrcpy documentation. They do not install an app, issue ADB commands, or turn on screen/input sharing.

## Current truthful features
- No automatic discovery or online-status claims. Four previously named Windows PCs are **unverified placeholders** (HOVED-PC, OMEN, SAMSUNG 750XFG, Packard Bell). No Android is claimed connected.
- Register Android/PC names and choose a preferred remote tool. Saved URL is validated as plain HTTP(S) without credentials or query/hash parameters; unsafe schemes are rejected.
- Search, filter, add, remove, JSON export/import. Local browser data is RAM-based on this Live ISO unless a separate persistence mechanism is implemented. Download the JSON to durable storage before shutdown.
- Passwords, PINs, API keys, and access tokens must never be entered in the device registry.

## For real Android remote control
1. **RustDesk**: install the official Android app on the phone and the official controller on a PC; allow screen sharing, input control and requested special permissions on the phone; use an approved device ID and authentication flow. Android may require fresh capture permission after app restarts.
2. **scrcpy**: run scrcpy on a Windows/Linux computer after the Android owner authorizes USB debugging and ADB pairing; optional wireless ADB requires setup on a trusted local network. Do not expose unsecured ADB ports publicly.
3. **Chrome Remote Desktop**: useful for controlling existing Windows/Mac/Linux hosts; it is not an automatic full-control host for every Android handset.
4. **Tailscale** can connect devices privately but does not itself provide touchscreen remote control or bypass Android permission requirements.

## Next engineering gates
- [x] Offline source UI, safe links and explicit NOT TESTED status.
- [ ] Automated JS test PASS from GitHub Actions on this candidate branch.
- [ ] Candidate ISO SHA-256 + QEMU BIOS/UEFI/login and actual menu handoff verified.
- [ ] Physical HOVED-PC/OMEN and at least one Android device tested, with individual, revocable permission.
- [ ] Bridge integration for a read-only authenticated live inventory; separate explicit approval for any remote actions.
- [ ] Persistent device configuration, role-based authorization, event logs, and disconnect control in mature RAH OS.

Official documentation:
- https://support.google.com/chrome/answer/1649523
- https://rustdesk.com/docs/en/client/android/
- https://github.com/Genymobile/scrcpy
