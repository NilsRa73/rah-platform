# RAH Raven 2-PC Grid v1.2.0

RAH Raven 2-PC Grid v1.2.0 fixes the Windows Python/App Execution Alias failure and introduces the first persistent Raven Hardware Registry.

## Release identity

- Tag: `rah-2pc-grid-v1.2.0`
- Source commit: `0c4c6301932ad7b8146eebf824e5dcb16ca11a52`
- Merge PR: #379
- 2-PC post-merge Windows validation: `35669818324` — SUCCESS
- Daily Driver Windows runtime: `35669818310` — SUCCESS
- Release Gate: `35669818226` — SUCCESS

## Python-free operator runtime

The 2-PC Windows operator package no longer depends on Python.

The HMAC client, verification flow, hardware collector, registry manager and FINAL ACCEPTANCE run with built-in Windows PowerShell/.NET.

This specifically removes the failure where the Windows App Execution Alias exposed a fake `python.exe` launcher and sent the user to Microsoft Store.

## Persistent RAH Hardware Registry

Hardware profiles are stored under:

`C:\RAH\HardwareRegistry`

The registry records, where Windows/firmware reports it:

- system manufacturer/model
- motherboard manufacturer/model/version
- BIOS/UEFI information
- CPU model/socket/cores/threads/virtualization support
- RAM total, reported maximum, used/free slots
- RAM module manufacturer, part number, type, size and speed
- GPU model, driver, reported VRAM and hardware ID
- firmware-reported PCI/PCIe slots and usage
- disk model, size, media/bus type and health
- volumes/free capacity
- physical network adapters and link speed
- monitor model/manufacturer/product identifiers

Changed profiles are versioned in per-device history.

Unnecessary serial numbers are deliberately excluded. PSU wattage, physical chassis clearance and exact PCIe lane/generation wiring may still require manufacturer documentation or physical inspection.

## Raven integration

- `system-inventory` now carries the detailed hardware profile when available.
- New fixed read-only `hardware-registry` Raven capability.
- Daily Driver DeviceRegistry consumes the same persistent hardware registry.
- No arbitrary shell, arbitrary filesystem path or caller-controlled remote command authority was added.

## Operator files

- `INSTALL-RAH-2PC-GRID.cmd`
- `START-HER-RAH-2PC-GRID.cmd`
- `VERIFY-RAH-2PC-GRID.cmd`
- `COMPLETE-RAH-2PC-GRID.cmd`
- `RAH-RAVEN-2PC-GUI.ps1`
- `RAH-2PC-CLIENT.ps1`
- `RAH-2PC-ACCEPTANCE.ps1`
- `RAH-HARDWARE-INVENTORY.ps1`
- `RAH-HARDWARE-REGISTRY.ps1`
- `RAH-2PC-GRID.md`
