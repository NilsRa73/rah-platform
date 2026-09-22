# RAH Raven OS — 2-PC Grid v1.2.1

RAH Raven 2-PC Grid connects **HOVED-PC ↔ Lenovo** through the stable, fixed read-only Raven `system-inventory` path.

**v1.2.1 requires no Python installation on the Windows PCs.** The operator package runs on built-in Windows PowerShell/.NET.

## Run

1. Double-click `INSTALL-RAH-2PC-GRID.cmd`.
2. On Lenovo, use **START RAVEN CORE**, then **START LENOVO NODE**.
3. Copy the fresh Node token shown locally on Lenovo.
4. On HOVED-PC, use **TEST 2-PC LINK**, paste the token, then **RUN SYSTEM INVENTORY**.
5. When inventory shows PASS, press **FINAL REAL-HARDWARE ACCEPTANCE**.

The GUI defaults to Lenovo LAN hostname `DESKTOP-R2HTAGJ` and can fall back to the last known private LAN address. Release installs are pinned through `RAH-2PC-SOURCE-REF.txt`, so later repo changes cannot silently mix files from another version. Node Agent 1.4 Stable keeps its existing requester-source boundary: loopback/RFC1918 private LAN only.

## RAH Hardware Registry

Every successful detailed inventory can update:

`C:\RAH\HardwareRegistry\registry.json`

Per-device current profiles are stored under:

`C:\RAH\HardwareRegistry\devices\`

Changed hardware snapshots are kept under:

`C:\RAH\HardwareRegistry\history\<device>\`

The profile is designed for later upgrade and workload decisions. It records, where Windows/firmware reports it:

- PC manufacturer/model and system type
- motherboard manufacturer/model/version
- BIOS/UEFI version and Secure Boot state
- CPU model, socket, cores/threads and virtualization support
- total RAM, reported maximum RAM, RAM slots used/free
- RAM module manufacturer, part number, type, size, speed and configured speed
- GPU model, video processor, driver, reported VRAM and PNP hardware ID
- firmware-reported PCI/PCIe slots and whether they are reported available/in use
- disk model, size, interface/bus/media type and health data
- volumes and free capacity
- physical network adapters and link speed
- monitor model/manufacturer/product identifiers
- Raven bridge/runtime facts

Unnecessary serial numbers are deliberately not stored. PSU wattage, exact chassis clearance and exact PCIe lane/gen wiring are not reliably available from Windows and may still require model documentation or a physical check.

## Raven agent access

Raven `system-inventory` now includes the detailed local hardware profile when the collector is available.

Raven also exposes a separate fixed read-only capability:

`hardware-registry`

It reads only the fixed local registry path. It does not accept an arbitrary filesystem path and does not write files.

## What PASS means

A 2-PC inventory PASS proves:

`GET /raven/status -> local 127.0.0.1:18765 -> fixed system-inventory`

with the Node 1.4 single-use nonce + HMAC-SHA256 proof.

Results:

- `C:\RAH\2PCProof\results\last-inventory.json`
- `C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json`
- `C:\RAH\HardwareRegistry\registry.json`

## Safety boundary

- fixed remote route `/raven/status`
- fixed Node port `18766`
- fixed Raven capability `system-inventory`
- Node-to-Raven hop remains localhost `127.0.0.1:18765`
- no arbitrary shell
- no caller-controlled remote path
- no caller-controlled remote arguments
- fresh Node token is used only in memory
- no automatic firewall changes
- hardware-registry read capability uses one fixed local path
- detailed hardware collector is read-only

## Package checklist

**Package/version:** RAH Raven OS 2-PC Grid v1.2.1

**Run first:** `INSTALL-RAH-2PC-GRID.cmd`

**Main launcher:** `START-HER-RAH-2PC-GRID.cmd`

**Optional verification:** `VERIFY-RAH-2PC-GRID.cmd`

**Final acceptance:** `COMPLETE-RAH-2PC-GRID.cmd` or the GUI button.

**Success:** GUI shows `REAL-HARDWARE PASS`, the Lenovo inventory is stored, and the hardware registry contains both known machine profiles after both PCs have been scanned.

**Do not run:** older generic remote-shell experiments. This package intentionally keeps the remote authority narrow.
