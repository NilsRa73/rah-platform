# RAH Raven 2-PC Grid v1.1.0

RAH Raven 2-PC Grid v1.1.0 completes the software side of the HOVED-PC ↔ Lenovo real-hardware proof.

## Release identity

- Tag: `rah-2pc-grid-v1.1.0`
- Source commit: `b82c5d3cdce786aaa2f0c267e9aa83adbb91e583`
- Merge PR: #376
- Pre-merge Windows CI: `35567937597` — SUCCESS
- Post-merge Windows CI: `35567983784` — SUCCESS

## New in v1.1.0

- Raven OS GUI button: **FINAL REAL-HARDWARE ACCEPTANCE**
- `COMPLETE-RAH-2PC-GRID.cmd`
- `rah_2pc_acceptance.py`
- validation of Lenovo hostname, private LAN, Node port 18766, local Raven port 18765 and all read-only safety flags
- final evidence file: `C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json`
- source inventory SHA-256 embedded in the acceptance report

## Safety boundary

No broader remote authority was added. The proof remains fixed to read-only `system-inventory`, with no arbitrary shell, caller-controlled remote path, caller-controlled remote arguments, token persistence, or automatic firewall modification.
