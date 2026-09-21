# RAH Raven 2-PC Grid v1.0.0

RAH Raven 2-PC Grid v1.0.0 is the first packaged HOVED-PC ↔ Lenovo proof for the fixed, read-only Raven `system-inventory` path.

## Release identity

- Tag: `rah-2pc-grid-v1.0.0`
- Software source commit: `72041b252bc8beed5d800146ab1e86af2ab8ef43`
- Merge PR: #372
- Windows pre-merge CI: `35566214360` — SUCCESS
- Windows post-merge CI: `35566259182` — SUCCESS

## Included

- `INSTALL-RAH-2PC-GRID.cmd` — standalone installer
- `START-HER-RAH-2PC-GRID.cmd` — primary launcher
- `RAH-RAVEN-2PC-GUI.ps1` — Raven OS black/gold GUI
- `rah_2pc_inventory_client.py` — fixed HMAC inventory client
- `VERIFY-RAH-2PC-GRID.cmd` — self-test
- `RAH-2PC-GRID.md` — operator guide

## Safety boundary

The remote authority remains deliberately narrow: Node Agent 1.4 Stable exposes only the fixed `GET /raven/status` path for this proof, which invokes the local Raven `system-inventory` capability. There is no arbitrary shell, caller-controlled remote path, caller-controlled remote arguments, token persistence, or automatic firewall modification.

The real-hardware milestone is complete only after HOVED-PC receives `RAH RAVEN 2-PC INVENTORY · PASS` from Lenovo and the sanitized result JSON is written under `C:\RAH\2PCProof\results\last-inventory.json`.
