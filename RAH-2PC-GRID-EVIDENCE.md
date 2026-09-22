# RAH Raven 2-PC Grid — Evidence Log

**Milestone:** HOVED-PC ↔ Lenovo persistent read-only hardware knowledge + real-hardware proof  
**Current release:** `rah-2pc-grid-v1.3.0`  
**Stage:** software-complete / packaged / physical two-machine acceptance pending  
**Repository:** `NilsRa73/rah-platform`

## Current software milestone — v1.3.0

- PR #379 — Python-free operator runtime + persistent Hardware Registry — MERGED
- PR #382 — pinned release runtime + hardened Python detection — MERGED
- PR #385 — legacy BIOS/WMI slot compatibility — MERGED
- PR #388 — Hardware Registry → Project Memory knowledge — MERGED
- PR #389 — automatic best-effort hardware knowledge sync — MERGED
- v1.3.0 software commit: `cb9c37f5f775bc37e46a2c724f0f9ea126356387`
- v1.3.0 pre-merge 2-PC Windows validation: `35689819192` — SUCCESS
- v1.3.0 post-merge 2-PC Windows validation: `35689891970` — SUCCESS
- Hardware knowledge AI Fabric validation: `35689301879` — SUCCESS
- Hardware knowledge post-merge AI Fabric validation: `35689410039` — SUCCESS
- Package / one-click / Release Gate on hardware-knowledge foundation: SUCCESS

## What Raven now knows

Fixed registry:

`C:\RAH\HardwareRegistry\registry.json`

Per-device current profiles and changed-history snapshots remain under:

- `C:\RAH\HardwareRegistry\devices\`
- `C:\RAH\HardwareRegistry\history\<device>\`

Where Windows/firmware exposes the values, profiles include:

- PC manufacturer/model/system type
- motherboard manufacturer/product/version
- BIOS/UEFI and Secure Boot facts
- CPU model/socket/cores/threads/virtualization
- total RAM and reported maximum
- RAM slots used/free
- RAM module manufacturer, part number, size, type and speed
- GPU model/driver/reported VRAM/PNP hardware ID
- firmware-reported PCI/PCIe slots and usage
- disks, interfaces/media/bus and health
- volumes/free capacity
- physical network adapters/link speed
- monitors

Unnecessary serial numbers are deliberately not stored. PSU wattage, physical chassis clearance and exact PCIe lane/gen wiring may still require manufacturer documentation or a physical check.

## Durable hardware knowledge

Project Memory sync now adds a bounded read-only `RAH HARDWARE CONTEXT` section from the Hardware Registry.

- accepted schema: `rah-hardware-registry-v1`
- input bound: 2 MiB
- a `serialNumber` field causes hardware memory sync to refuse the registry
- sync state records registry SHA-256 and device count
- hardware/upgrade questions prefer authenticated AnythingLLM knowledge before general LM Studio chat
- token matching avoids false positives such as `ram` inside `program`

v1.3.0 closes the loop from scan to knowledge:

1. successful inventory updates the Hardware Registry
2. if Project Memory is configured, GUI requests `SYNC-RAH-PROJECT-MEMORY.ps1 -Force`
3. GUI reports `REQUESTED`, `NOT_CONFIGURED`, or `WARNING`
4. Project Memory problems never convert a successful hardware inventory into FAIL

Project Memory is configured once with:

`C:\RAH\CONFIGURE-RAH-PROJECT-MEMORY.cmd`

## Safety boundary

- fixed remote Node endpoint: `GET /raven/status`
- fixed Node port: `18766`
- fixed Raven inventory capability: `system-inventory`
- Node-to-Raven hop remains `127.0.0.1:18765`
- fixed read-only `hardware-registry` capability reads only the canonical registry file
- no arbitrary shell
- no caller-controlled remote path
- no caller-controlled remote arguments
- no token persistence
- no automatic firewall changes
- Project Memory hardware context is reference-only
- Node Agent 1.4 Stable requester-source policy remains loopback/RFC1918 private LAN

## Packaged release v1.3.0

- Annotated tag: `rah-2pc-grid-v1.3.0`
- Tag object SHA: `9d8759b5164ebde43679daa53cc1069a2051f3d8`
- Tag target: `cb9c37f5f775bc37e46a2c724f0f9ea126356387`
- Release publisher run: `35690013769` — SUCCESS
- GitHub Release ID: `393470321`
- Release page: `https://github.com/NilsRa73/rah-platform/releases/tag/rah-2pc-grid-v1.3.0`
- Direct installer: `https://github.com/NilsRa73/rah-platform/releases/download/rah-2pc-grid-v1.3.0/INSTALL-RAH-2PC-GRID.cmd`
- ZIP: `https://github.com/NilsRa73/rah-platform/releases/download/rah-2pc-grid-v1.3.0/RAH-Raven-2PC-Grid-v1.3.0.zip`
- Checksums: `https://github.com/NilsRa73/rah-platform/releases/download/rah-2pc-grid-v1.3.0/SHA256SUMS.txt`

Publisher gates verified:

- annotated tag resolves to the exact software commit
- tag source contains `RAH HARDWARE CONTEXT`
- tag source contains hardware-aware AnythingLLM routing
- GUI contains best-effort `Request-RahHardwareKnowledgeSync`
- v1.2.2 legacy BIOS compatibility is preserved
- release installer is pinned to `rah-2pc-grid-v1.3.0`
- package identifies v1.3.0
- old Python operator-runtime files are absent
- ZIP and SHA256SUMS were created successfully

The annotated tag is structurally verified. GitHub reports it as unsigned because no GPG/SSH tag signature is attached.

## Operator package

Run:

1. `INSTALL-RAH-2PC-GRID.cmd`
2. `START-HER-RAH-2PC-GRID.cmd`

Optional:

- `VERIFY-RAH-2PC-GRID.cmd`
- `COMPLETE-RAH-2PC-GRID.cmd`

Do not use older v1.0–v1.2.2 installers for new installations.

## Remaining real-hardware acceptance

Software and release gates are complete. Physical HOVED-PC ↔ Lenovo acceptance still requires an actual run on the owned Windows PCs:

1. install v1.3.0 on both PCs
2. Lenovo Raven Core healthy on `127.0.0.1:18765`
3. Lenovo Node Agent 1.4 Stable running on private LAN
4. HOVED-PC reaches Lenovo TCP `18766`
5. use the fresh locally displayed Node token
6. **RUN SYSTEM INVENTORY** returns PASS
7. **FINAL REAL-HARDWARE ACCEPTANCE** creates `C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json` with `overall: PASS`
8. Hardware Registry contains the scanned machine profiles
9. if Project Memory is configured, inventory output shows `KNOWLEDGE : REQUESTED`

## Conclusion

RAH Raven 2-PC Grid v1.3.0 is **software DONE, Python-free for the operator, source-pinned, legacy-BIOS tolerant, hardware-registry integrated, Project-Memory aware and packaged**. The remaining milestone is the explicit physical two-machine PASS.
