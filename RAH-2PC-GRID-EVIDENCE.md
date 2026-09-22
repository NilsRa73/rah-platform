# RAH Raven 2-PC Grid — Evidence Log

**Milestone:** HOVED-PC ↔ Lenovo persistent read-only hardware knowledge + real-hardware proof  
**Current release:** `rah-2pc-grid-v1.2.1`  
**Stage:** software-complete / packaged / real-hardware acceptance pending  
**Repository:** `NilsRa73/rah-platform`

## Current software milestone — v1.2.1

- PR #379 — Python-free runtime + persistent hardware registry — MERGED
- PR #382 — pinned release runtime + hardened Python detection — MERGED
- v1.2 base merge: `0c4c6301932ad7b8146eebf824e5dcb16ca11a52`
- v1.2.1 software merge: `a2ac2ac198ab6704d9b381ded7557f4652a1cb3f`
- Pre-merge 2-PC Windows validation: `35680919719` — SUCCESS
- Pre-merge Raven AI Fabric validation: `35680919714` — SUCCESS
- Post-merge 2-PC Windows validation: `35681011166` — SUCCESS
- Post-merge Raven AI Fabric validation: `35681011156` — SUCCESS

## Python and version-mixing failures fixed

v1.1 failed on a real Windows machine because the Windows App Execution Alias exposed `python.exe` without a real Python runtime.

v1.2 removed Python from the 2-PC operator runtime. v1.2.1 additionally fixes the real installation failure caused by an older release bootstrapper fetching newer `main` files.

v1.2.1 pins release installs with `RAH-2PC-SOURCE-REF.txt`, and the release installer is hard-pinned to `rah-2pc-grid-v1.2.1`. GUI repo sync and Raven Core installation follow that same ref, preventing cross-version file mixing.

The Lenovo Node launcher uses Raven AI Fabric's isolated `C:\RAH\AI-Fabric\venv\Scripts\python.exe` rather than PATH/App Execution Alias. AI Fabric now validates candidate Python executables and rejects the Microsoft Store placeholder alias.

The operator runtime remains:

- HMAC client: `RAH-2PC-CLIENT.ps1`
- final acceptance: `RAH-2PC-ACCEPTANCE.ps1`
- detailed hardware collector: `RAH-HARDWARE-INVENTORY.ps1`
- persistent registry: `RAH-HARDWARE-REGISTRY.ps1`
- GUI/self-test/installer: Windows PowerShell/.NET

GitHub CI may still use Python for static project tests, and the broader Raven AI Fabric has its own isolated Python environment. The installed 2-PC operator package itself does not require Python.

## Persistent RAH Hardware Registry

Fixed root:

`C:\RAH\HardwareRegistry`

Files:

- `registry.json` — central multi-device registry
- `devices\<device>.json` — current per-device profile
- `history\<device>\...` — changed hardware snapshots

The detailed profile can record, where Windows/firmware exposes it:

- PC manufacturer/model/system type
- motherboard manufacturer/product/version
- BIOS/UEFI data and Secure Boot state
- CPU model/socket/cores/threads/virtualization facts
- RAM total, reported maximum, slots used/free
- RAM module manufacturer, part number, type, size and speed
- GPU name/video processor/driver/reported VRAM/PNP hardware ID
- firmware-reported PCI/PCIe slots and usage
- disk model/size/interface/media/bus/health
- volumes and free capacity
- physical network adapters/link speed
- monitor model/manufacturer/product identifiers

Unnecessary serial numbers are deliberately not stored.

PSU wattage, chassis clearance and exact PCIe lane/generation wiring are not reliably discoverable on every Windows system and may still require manufacturer documentation or physical inspection.

## Raven integration

- fixed remote Node endpoint: `GET /raven/status`
- fixed Node port: `18766`
- fixed Raven inventory capability: `system-inventory`
- Node-to-Raven hop: localhost `127.0.0.1:18765`
- `system-inventory` can carry the detailed `rah-hardware-profile-v1` profile
- new fixed read-only Raven capability: `hardware-registry`
- `hardware-registry` reads only `C:\RAH\HardwareRegistry\registry.json`
- Daily Driver DeviceRegistry consumes the same registry

Safety remains:

- no arbitrary shell
- no caller-controlled remote path
- no caller-controlled remote arguments
- no token persistence
- no automatic firewall changes
- Node Agent 1.4 Stable requester-source policy remains loopback/RFC1918 private LAN
- Tailscale `100.64.0.0/10` remains outside this Stable proof

## Packaged release v1.2.1

- Annotated tag: `rah-2pc-grid-v1.2.1`
- Tag object SHA: `5f8156245038c2e9a07759f9f40c277fcb874698`
- Tag target: `a2ac2ac198ab6704d9b381ded7557f4652a1cb3f`
- Release publisher run: `35681160122` — SUCCESS
- GitHub Release ID: `393425575`
- Release page: `https://github.com/NilsRa73/rah-platform/releases/tag/rah-2pc-grid-v1.2.1`
- Direct installer: `https://github.com/NilsRa73/rah-platform/releases/download/rah-2pc-grid-v1.2.1/INSTALL-RAH-2PC-GRID.cmd`
- ZIP: `https://github.com/NilsRa73/rah-platform/releases/download/rah-2pc-grid-v1.2.1/RAH-Raven-2PC-Grid-v1.2.1.zip`
- Checksums: `https://github.com/NilsRa73/rah-platform/releases/download/rah-2pc-grid-v1.2.1/SHA256SUMS.txt`

Publisher package gates verified:

- release installer contains `set "REF=rah-2pc-grid-v1.2.1"`
- package contains `RAH-2PC-SOURCE-REF.txt` with the same tag
- old operator files `rah_2pc_inventory_client.py` and `rah_2pc_acceptance.py` are absent
- Python-free VERIFY marker is present
- Hardware Registry runtime is present

The tag is annotated and structurally verified. GitHub reports it as unsigned because no GPG/SSH tag signature is attached.

v1.2.0 remains historical. **Use v1.2.1 for all new installs.**

## Current operator package

Top-level runnable files:

- `INSTALL-RAH-2PC-GRID.cmd` — install/update into `C:\RAH\2PCProof`
- `START-HER-RAH-2PC-GRID.cmd` — Raven OS GUI
- `VERIFY-RAH-2PC-GRID.cmd` — Python-free package self-test
- `COMPLETE-RAH-2PC-GRID.cmd` — final real-hardware gate

Supporting runtime:

- `RAH-RAVEN-2PC-GUI.ps1`
- `RAH-2PC-CLIENT.ps1`
- `RAH-2PC-ACCEPTANCE.ps1`
- `RAH-HARDWARE-INVENTORY.ps1`
- `RAH-HARDWARE-REGISTRY.ps1`

## Remaining real-hardware acceptance

The software/release is complete. The physical milestone becomes PASS when:

1. v1.2.1 is installed on both owned Windows PCs.
2. Lenovo Raven Core is healthy on `127.0.0.1:18765`.
3. Lenovo Node Agent 1.4 Stable runs with `compute` capability on private LAN.
4. HOVED-PC reaches Lenovo on TCP `18766`.
5. A fresh locally displayed Node token is used.
6. **RUN SYSTEM INVENTORY** returns PASS.
7. **FINAL REAL-HARDWARE ACCEPTANCE** creates:
   `C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json`
   with `overall: PASS`.
8. `C:\RAH\HardwareRegistry\registry.json` contains the scanned hardware profiles.

## Conclusion

RAH Raven 2-PC Grid v1.2.1 is **software DONE, Python-free for the operator, source-pinned, hardware-registry integrated and packaged**. The remaining gate is the explicit two-machine physical run and its generated PASS evidence.
