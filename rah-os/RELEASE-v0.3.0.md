# RAH OS Raven v0.3.0 Stable

RAH OS v0.3.0 is the first release in this line promoted to Stable after both automated CI validation and a reviewed real-hardware Live USB acceptance PASS.

## Release identity

- Version: `0.3.0`
- Stage: `stable`
- Annotated tag: `v0.3.0`
- Stable source commit: `c1e824401f9351c65c241ff33d1f5711ce6795dd`
- Promotion PR: #363

## Validation completed

- Raven + profile self-tests
- Windows USB-prep self-test
- Debian 13 amd64 ISO build
- BIOS + UEFI payload inspection
- SquashFS/runtime inspection
- SHA-256 verification
- Artifact upload
- Post-merge rebuild on `main`
- Real-hardware Live USB boot
- Reviewed `rah-os-live-acceptance-v1` overall `PASS`

## Included profiles

- RAH OS Standard
- RAH Nova VI
- RAH Ghost & Rescue
- RAH Forge
- RAH Arcade Nexus

## Safety boundary

Raven remains loopback-only and unprivileged. There is no generic shell endpoint, automatic package-install authority, automatic internal-disk write, or automatic Stable promotion. RAH Ghost destructive restore remains separately guarded by explicit erase intent and exact target confirmation.

## Download note

The full ISO is produced and validated by the `Build RAH OS ISO` workflow. The GitHub Actions ISO artifact is larger than a normal GitHub Release asset, so this release preserves the checksum and release metadata here while the validated ISO remains in the workflow artifact store for its configured retention window.
