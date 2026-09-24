RAH WORLD MEDIA 14.0 — RAVEN SMART CLUSTER
================================================

Windows command deck for public/legal World TV, World Radio and Webcams.

NEW: SMART CLUSTER TV WORKERS
- Open the token-protected TV Worker page on Smart TVs, Android TV boxes, PCs, tablets or other modern browsers on the same trusted LAN.
- Each worker fetches its assigned HLS streams directly from the source and decodes/renders them locally through the device browser/media pipeline. The HOVED-PC sends only assignments and control state; it does not re-encode or mirror the video.
- Each worker starts with 4 local decode slots. You can adjust 1–12 slots manually or press AUTO TUNE. AUTO TUNE tests 2/4/6/8/10/12 simultaneous previews and falls back when fewer than 75% remain healthy.
- The cluster scheduler distributes different HLS channels across all active workers and reports total local decode slots.
- NEXT BATCH rotates the shared stream pool without restarting the Windows app.
- MediaCapabilities is reported when the browser exposes it. “supported / smooth / efficient” is useful evidence, but hardware GPU/VPU acceleration is ultimately controlled by the TV OS/browser and cannot be forced by the app.

PRESERVED: MULTI-RECEIVER SYNC
- Open RAVEN RECEIVER on several trusted-LAN devices: PC, phone, tablet, TV or projector browser.
- Receivers keep friendly names and heartbeat status.
- TV/radio broadcasts use the shared server clock for approximate synchronized starts.
- SYNC NOW, persistent queue, World Live, Super Search, presets, My Library, diagnostics and Media Wall remain available.

SECURITY
- Localhost remains the safe default.
- Smart Cluster requires explicit trusted-LAN opt-in and the same secret token as Remote/Receiver.
- No UPnP, NAT-PMP or automatic port forwarding is used.
- Never port-forward the Remote/Receiver/Cluster port and do not share the token publicly.

MEDIA
TV: iptv-org public catalog. VLC remains the most compatible desktop player.
Radio: Radio Browser public API with mirror fallback.
Webcams: optional Windy Webcams API v3 key; attribution/source links retained.

RUN
1. Extract ZIP.
2. Double-click START-HER.cmd.
3. In World Media click SMART CLUSTER and approve trusted LAN.
4. The TV Worker URL is copied automatically. Open that same URL on TV 1 and TV 2.
5. Rename each TV and press AUTO TUNE on each worker.
6. Optional INSTALL.cmd installs under C:\RAH\WorldMedia\14.0.

DATA
Persistent favorites/history/settings remain under C:\RAH\IPTV\. v12 state/token/queue/broadcast data migrate forward automatically where applicable.

LEGAL / SAFETY
Public/legal sources and user-owned M3U only. No DRM, subscription, paywall or geo-restriction bypass. Playback follows the device/network/VPN routing already active.
