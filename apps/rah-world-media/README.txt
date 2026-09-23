RAH WORLD MEDIA 9.9 — SUPER MODE
=================================

Windows-first global media command deck built directly in Python/Tkinter.
No Lovable or external app builder is required.

WHAT IS NEW IN 9.9
------------------
• SUPER MODE toggle — richer command-deck behavior without auto-starting heavy playback.
• SUPER SEARCH — one search across loaded TV, radio and webcam data; blank search shows favorites.
• SUPER SCENES — WORLD, NEWS, SPORTS, MUSIC, NORDICS, CAMS and RANDOM.
• SUPER MEDIA WALL — TV + Radio + Webcams in the browser with live HLS hover previews.
• TV MOSAIC 4 / 6 / 9 / 12.
• WORLD MIX mosaic — random HLS streams from multiple countries.
• NEXT button rotates to the next mosaic batch; FULLSCREEN uses the browser fullscreen API.
• Explicit TEST STREAM buttons for selected TV/radio streams; result + latency stored locally.
• Existing World Live autopilot, globe, favorites, city pins, themed webcams and history retained.
• State migrates from v6 to state_v99.json.
• Optional INSTALL.cmd copies the app to C:\RAH\WorldMedia\9.9 and creates shortcuts.

QUICK START
-----------
Portable: double-click START-HER.cmd.
Installed: double-click INSTALL.cmd once, then use the desktop shortcut.

RUNNABLE FILES
--------------
START-HER.cmd   Main launcher. Use this normally.
SELFTEST.cmd    Python/tkinter compile + public-source network smoke test.
REPAIR.cmd      Helps install Python/VLC with Winget when available.
INSTALL.cmd     Optional local installation + Desktop/Start Menu shortcut.
UNINSTALL.cmd   Removes the installed program only; preserves C:\RAH\IPTV data.

SUPER MODE SAFETY / PERFORMANCE
-------------------------------
Hover previews remain capped and muted. 4/6/9/12-screen mosaics start only after an explicit click.
Twelve simultaneous HLS streams can use substantial CPU/GPU/network bandwidth; use 4 or 6 on slower hardware.
Only click TEST STREAM when you want an explicit health probe; the app does not scan thousands of streams.

DATA / SOURCES
--------------
TV: public iptv-org catalog.
Radio: public Radio Browser mirrors.
Webcams: optional Windy Webcams API v3 key stored locally under C:\RAH\IPTV.
Radio Garden opens the official site externally.
Playback follows Windows/network/VPN routing. The app does not bypass DRM, subscriptions, paywalls or geo controls.

DATA LOCATION
-------------
C:\RAH\IPTV  favorites, history, state, cache, logs, stream-health cache, optional webcam API key.

SUCCESS
-------
START-HER.cmd reports PRECHECK PASS, then the RAH World Media 9.9 window opens.
Media Wall opens in your default browser. VLC is used for normal TV/radio PLAY actions.
