# RAH Raven 2-PC Grid v1.2.1

This release closes the version-mixing and Windows App Execution Alias failure found during real Windows installation.

## Release identity

- Tag: `rah-2pc-grid-v1.2.1`
- Source commit: `a2ac2ac198ab6704d9b381ded7557f4652a1cb3f`
- Merge PR: #382
- Pre-merge 2-PC Windows CI: `35680919719` — SUCCESS
- Pre-merge Raven AI Fabric CI: `35680919714` — SUCCESS
- Post-merge 2-PC Windows CI: `35681011166` — SUCCESS
- Post-merge Raven AI Fabric CI: `35681011156` — SUCCESS

## Fixed in v1.2.1

- release installer is pinned to this exact release tag instead of floating `main`
- GUI repo sync follows the same source ref
- Raven Core installation receives the same pinned ref
- Lenovo Node Agent uses Raven AI Fabric's isolated Python runtime instead of Windows PATH/App Execution Alias
- Raven Python detection rejects Microsoft Store alias placeholders
- operator-side HMAC client and final acceptance remain pure Windows PowerShell/.NET

## Hardware Registry

v1.2.1 includes the persistent RAH Hardware Registry:

`C:\RAH\HardwareRegistry\registry.json`

It records upgrade-useful hardware facts including motherboard, CPU, RAM modules/slots, GPU, firmware-reported PCIe slots, disks, network adapters and monitors, with per-device history when hardware changes. Unnecessary serial numbers are deliberately not stored.

Raven exposes the registry only through the fixed read-only `hardware-registry` capability. No arbitrary filesystem path or shell authority is added.

## Install

Use the **v1.2.1 release installer**. Older v1.1.x/v1.2.0 installer assets should not be reused for new installations.
