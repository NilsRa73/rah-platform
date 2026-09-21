# RAH OS v0.3 Stable — Evidence Log

**Release:** RAH OS Raven v0.3 Stable  
**Stable date:** 2026-09-21  
**Repository:** `NilsRa73/rah-platform`

## Promotion

- PR: #363 — `RAH OS v0.3: promote real-hardware validated release to Stable`
- PR result: MERGED
- Target branch: `main`
- Merge commit: `c1e824401f9351c65c241ff33d1f5711ce6795dd`

## CI evidence

Stable promotion workflow:

- Run: `35549391344` — Build RAH OS ISO
- Raven + profile self-tests: PASS
- Windows USB-prep self-test: PASS
- Stable metadata/build-source validation: PASS
- Debian 13 amd64 ISO build: PASS
- Finished ISO BIOS/UEFI/runtime inspection: PASS
- SHA-256 verification: PASS
- ISO artifact upload: PASS
- Checksum artifact upload: PASS
- Overall result: SUCCESS

Post-merge verification on `main`:

- Run: `35552223734` — Build RAH OS ISO #21
- Head: `c1e824401f9351c65c241ff33d1f5711ce6795dd`
- Event: push to `main`
- Overall result: SUCCESS

## Tag and GitHub Release

- Annotated tag: `v0.3.0`
- Tag object SHA: `7d8dfe9a7da9ade35deeeac2a4aed77e4050d015`
- Tag object type: `tag`
- Peeled target commit: `c1e824401f9351c65c241ff33d1f5711ce6795dd`
- Tag message: `RAH OS v0.3.0 Stable`
- Clean-checkout tag verification: PASS
- Release publisher run: `35562326415`
- Release publisher result: SUCCESS
- GitHub Release ID: `392701849`
- GitHub Release: `https://github.com/NilsRa73/rah-platform/releases/tag/v0.3.0`
- Published assets:
  - `RAH-OS-Raven-v0.3-amd64.iso.sha256`
  - `RAH-OS-v0.3.0-RELEASE-INFO.txt`

## Real-hardware evidence

- RAH OS v0.3 booted from USB on real hardware.
- RAH Live Acceptance completed.
- `rah-os-live-acceptance-v1` returned overall `PASS`.
- The PASS report was reviewed before Stable promotion.
- No serious hardware/runtime blocker was recorded.
- Stable promotion remained a human decision.

## Canonical Stable state

`rah-os/RAH-OS-VERSION.json` on `main` records:

- `version: 0.3.0`
- `stage: stable`
- `stable_gate.status: passed`
- `real_hardware_boot_passed: true`
- `report_reviewed: true`
- `automatic_promotion: false`

## Conclusion

RAH OS v0.3 Stable completed the CI gate, reviewed real-hardware acceptance gate, annotated release-tag verification, and GitHub Release publication. The Stable source of record is merge commit `c1e824401f9351c65c241ff33d1f5711ce6795dd`, fixed by annotated tag `v0.3.0`.
