# RAH Raven 2-PC Grid v1 — Evidence Log

**Milestone:** HOVED-PC ↔ Lenovo fixed read-only system inventory proof  
**Stage:** software-complete / real-hardware acceptance pending  
**Date:** 2026-09-21  
**Repository:** `NilsRa73/rah-platform`

## Merge

- PR: #372 — `RAH 2-PC: Raven OS GUI for HOVED-PC ↔ Lenovo inventory proof`
- Result: MERGED
- Merge commit: `72041b252bc8beed5d800146ab1e86af2ab8ef43`

## Windows CI evidence

Pre-merge validation:

- Run: `35566214360`
- Python syntax: PASS
- Fixed HMAC runtime self-test: PASS
- Security / XAML contract tests: PASS
- PowerShell GUI parse: PASS
- GUI self-test entry: PASS
- Overall: SUCCESS

Post-merge validation on `main`:

- Run: `35566259182`
- Head: `72041b252bc8beed5d800146ab1e86af2ab8ef43`
- Event: push to `main`
- All Windows contract steps: PASS
- Overall: SUCCESS

## Delivered operator package

- `INSTALL-RAH-2PC-GRID.cmd` — standalone installer into `C:\RAH\2PCProof`
- `START-HER-RAH-2PC-GRID.cmd` — primary one-click launcher
- `RAH-RAVEN-2PC-GUI.ps1` — Raven OS black/gold WPF GUI
- `rah_2pc_inventory_client.py` — fixed-purpose HMAC inventory client
- `VERIFY-RAH-2PC-GRID.cmd` — local package self-test
- `RAH-2PC-GRID.md` — operator guide

## Authority and safety boundary

The remote proof is deliberately narrow:

- fixed Node endpoint: `GET /raven/status`
- fixed Node port: `18766`
- fixed Raven capability: `system-inventory`
- Node-to-Raven hop: localhost `127.0.0.1:18765`
- single-use source-bound nonce + HMAC-SHA256 proof
- no arbitrary shell
- no caller-controlled remote path
- no caller-controlled remote arguments
- no token persistence
- no automatic firewall changes
- Node Agent 1.4 Stable requester-source policy is unchanged: loopback and RFC1918 private LAN only
- Tailscale `100.64.0.0/10` is intentionally outside this Stable proof

## Remaining real-hardware acceptance

Software is complete. The milestone becomes real-hardware PASS when:

1. The standalone package installs/opens on both owned Windows PCs.
2. Lenovo has Raven Core healthy on `127.0.0.1:18765`.
3. Lenovo runs Node Agent 1.4 Stable with `compute` capability on private LAN.
4. HOVED-PC reaches Lenovo on TCP `18766`.
5. A fresh locally displayed Node token is pasted into the HOVED-PC GUI.
6. **RUN SYSTEM INVENTORY** returns `RAH RAVEN 2-PC INVENTORY · PASS`.
7. `C:\RAH\2PCProof\results\last-inventory.json` identifies the Lenovo host and preserves all read-only safety flags.

No broader remote authority should be added merely to make this acceptance easier.

## Conclusion

RAH Raven 2-PC Grid v1 is **software DONE** on `main`, with Windows CI green before and after merge. The only remaining gate is the explicit two-machine real-hardware acceptance run.
