RAH WORLD MEDIA 14.0 — RAVEN WORLD GRID
=================================================

Windows command deck for public/legal World TV, World Radio and Webcams.

NEW IN v14 — RAVEN WORLD GRID
- Resilient TV catalog loading: cached channel data remains usable if IPTV-org is temporarily unavailable.
- Channels + streams are critical; country/category/logo metadata may fail without making the TV list disappear.
- HENT KANALER performs a forced refresh but still falls back to the last known good local cache.
- Media Wall supports 16 / 36 / 64 / 100 / 256 / 500 visible tiles.
- LIVE LIMIT is separate from visible tiles: default 16, selectable up to 256.
- Tiles above the live limit remain lightweight STANDBY tiles; click one to activate it and retire the oldest live tile.
- NEXT BANK and AUTO 10s rotate through the source pool.
- CLEAN removes tile captions for a denser wall.
- XREAL 32:9 changes grid geometry for ultrawide/XREAL-style viewing.
- More than 64 simultaneous live streams triggers a warning because GPU/network/browser limits vary.

MULTI-RECEIVER SYNC
- Raven Receiver remains available on trusted LAN devices.
- Heartbeat, friendly names, queue, SYNC NOW and best-effort synchronized TV/radio starts remain from v12.
- Sync is best effort, not frame-accurate genlock.

SECURITY
- Localhost remains the safe default.
- Trusted-LAN access is explicit opt-in and requires the secret token.
- Never port-forward the Remote/Receiver port to the internet or share the token publicly.

MEDIA
TV: iptv-org public catalog with local cache fallback. VLC remains the most compatible desktop player.
Radio: Radio Browser public API with mirror fallback.
Webcams: optional Windy Webcams API v3 key; attribution/source links retained.

RUN
1. Extract ZIP.
2. Double-click START-HER.cmd.
3. Optional INSTALL.cmd installs under C:\RAH\WorldMedia\14.0.
4. DIAGNOSTICS.cmd creates a support report.

DATA
Favorites/history/settings remain under C:\RAH\IPTV\.
Existing v12 data is preserved; v14 changes the program install folder, not the shared media-data folder.

LEGAL / SAFETY
Public/legal sources and user-owned M3U only. No DRM, subscription, paywall or geo-restriction bypass.
Playback follows the device/network/VPN routing already active.
