# RAH Raven 2-PC Grid v1.2.2

This patch release fixes the real-hardware failure where some Windows/BIOS combinations omit optional `Win32_SystemSlot` properties.

## Release identity

- Tag: `rah-2pc-grid-v1.2.2`
- Source commit: `92687b9f867880256e100eb6c952bca562e99dc9`
- Runtime fix: PR #385
- Release identity: PR #386
- Windows fix CI: `35684597192` — SUCCESS
- Windows release CI: `35684823775` — SUCCESS

## Fixed

- missing `Purpose`, `Status`, or `MaxDataWidth` no longer aborts hardware inventory under PowerShell StrictMode
- optional slot values become empty or null while all available hardware facts remain recorded
- the built-in self-test simulates a legacy BIOS slot with those fields absent
- release packaging rejects any return of direct `$slot.Purpose` access

The PowerShell-only operator runtime, HMAC boundary, read-only inventory capability, fixed registry path and no-serial-number privacy boundary are unchanged.

## Install

Download and run the v1.2.2 release installer. It safely refreshes `C:\RAH\2PCProof` from the pinned v1.2.2 tag.
