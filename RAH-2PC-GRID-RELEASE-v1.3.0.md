# RAH Raven 2-PC Grid v1.3.0

v1.3.0 turns the persistent Hardware Registry into durable Raven knowledge.

## Release identity

- Tag: `rah-2pc-grid-v1.3.0`
- Source commit: `cb9c37f5f775bc37e46a2c724f0f9ea126356387`
- Hardware knowledge foundation: PR #388
- v1.3.0 integration: PR #389
- PR validation: `35689819192` — SUCCESS
- Post-merge validation: `35689891970` — SUCCESS
- PR #388 AI Fabric hardware-context validation: `35689301879` — SUCCESS
- PR #388 post-merge AI Fabric validation: `35689410039` — SUCCESS

## New in v1.3.0

- Hardware Registry remains at `C:\RAH\HardwareRegistry\registry.json`.
- Project Memory snapshots include a bounded read-only `RAH HARDWARE CONTEXT` section.
- Hardware/upgrade questions prefer the authenticated AnythingLLM knowledge workspace.
- A successful 2-PC inventory updates the registry, then requests a background Project Memory sync when Project Memory is configured.
- Manual **REFRESH THIS PC HARDWARE** does the same.
- Knowledge status is separate: `REQUESTED`, `NOT_CONFIGURED`, or `WARNING`.
- Knowledge-sync problems never change a successful inventory/registry update into FAIL.
- v1.2.2 legacy BIOS/WMI slot compatibility is retained.

## Safety

- remote authority remains the fixed read-only `system-inventory` path
- no arbitrary shell, path, arguments, token persistence or firewall changes
- Project Memory hardware context is reference-only
- hardware context accepts only `rah-hardware-registry-v1`, is bounded to 2 MiB, and refuses `serialNumber` fields

## Install

Download and run the v1.3.0 release installer. It refreshes `C:\RAH\2PCProof` from the pinned v1.3.0 tag.

For durable AnythingLLM knowledge, configure Project Memory once with:

`C:\RAH\CONFIGURE-RAH-PROJECT-MEMORY.cmd`

If it is not configured yet, inventory still passes and the GUI reports `NOT_CONFIGURED`.
