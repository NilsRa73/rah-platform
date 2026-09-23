RAH WORLD MEDIA 12.0 — RAVEN SYNC DECK
================================================

Windows command deck for public/legal World TV, World Radio and Webcams.

NEW: MULTI-RECEIVER SYNC
- Open RAVEN RECEIVER on several trusted-LAN devices: PC, phone, tablet, TV or projector browser.
- Each receiver registers a heartbeat and may be given a friendly device name.
- The PC control deck and Remote Deck show how many receivers are online.
- TV/radio broadcasts are scheduled about 1.8 seconds ahead using the server clock, so receivers attempt to begin together. Browser/stream buffering can still create small drift; this is best-effort sync, not frame-accurate genlock.
- SYNC NOW restarts the current broadcast with a fresh shared start time.
- Broadcast queue remains persistent.

SECURITY
- Localhost remains the safe default.
- Trusted-LAN access is explicit opt-in and requires the secret token.
- Receiver identity is an app-local random ID + friendly name, not OS/device account access.
- Never port-forward the Remote/Receiver port to the internet and do not share the token publicly.

MEDIA
TV: iptv-org public catalog. VLC remains the most compatible desktop player.
Radio: Radio Browser public API with mirror fallback.
Webcams: optional Windy Webcams API v3 key; attribution/source links retained.

RUN
1. Extract ZIP.
2. Double-click START-HER.cmd.
3. Optional INSTALL.cmd installs under C:\RAH\WorldMedia\12.0.
4. DIAGNOSTICS.cmd for a support report.

DATA
Persistent favorites/history/settings remain under C:\RAH\IPTV\. v11 broadcast queue/state/token migrate forward automatically on first use.

LEGAL / SAFETY
Public/legal sources and user-owned M3U only. No DRM, subscription, paywall or geo-restriction bypass. Playback follows the device/network/VPN routing already active.
