RAH APP FINDER / TEST HUB v1.0.1
================================

PURPOSE
RAH projects move quickly, and extracted releases can end up on Desktop,
Downloads, OneDrive, C:\RAH and other local RAH folders. This utility scans
those locations, identifies the most likely launcher for each app/version,
and creates a live local test hub.

ONE CLICK
Double-click START-HER.cmd.

WHAT IT DOES
- Scans C:\RAH, Desktop, Downloads, Documents, OneDrive and RAH folders on mounted drives.
- Prefers START-HER.cmd / START-*.cmd, then normal EXE launchers, HTA dashboards and HTML entrypoints.
- Detects versions/status such as v3.1, stable, RC and candidate.
- Groups related versions and marks the newest/best detected copy.
- Creates Desktop\RAH Apps with preferred app shortcuts.
- Creates Desktop\RAH Apps\All versions with every detected version.
- Creates Desktop shortcut: RAH TEST HUB.
- Creates Desktop shortcut: RAH RESCAN APPS.
- Creates a read-only browser inventory: RAH-TEST-HUB.html.
- Stores machine-readable inventory in apps.json.

SAFETY
- Does not delete, move, archive or modify discovered app folders.
- Only replaces .lnk shortcuts inside its own Desktop\RAH Apps folder.
- No background watcher or hidden PowerShell process is installed.
- Re-scan happens only when you run RAH RESCAN APPS or START-HER.cmd.

EXTRA ROOTS
Edit C:\RAH\AppFinder\roots.txt after first run and add one folder per line.
If C:\RAH is not writable, the utility falls back to %LOCALAPPDATA%\RAH\AppFinder.

This tool intentionally prefers reliable discovery over guessing. If a folder
does not have a recognizable launcher, it is not given a shortcut.


v1.0.1 FIX
- Replaced the dynamic JScript/JavaScript HTA renderer with static HTML cards and VBScript button handlers.
- This avoids the Windows mshta/JScript parser error reported on line 16 / character 18.
- START, FOLDER and RESCAN buttons no longer depend on JSON.parse, JSON.stringify or modern JavaScript support.
