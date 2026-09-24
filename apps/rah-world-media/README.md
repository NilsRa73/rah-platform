# RAH World Media — canonical source

This directory is the editable source tree for **RAH World Media 14.0 — Raven World Grid**.

The v14 line keeps the v12 Raven Sync Deck features and adds resilient TV-catalog loading plus a browser World Grid with up to 500 visible tiles and an independent live-stream limit.

## Build

On Windows PowerShell:

```powershell
.\apps\rah-world-media\BUILD-PACKAGE.ps1
```

The build uses a fixed file allowlist, generates `MANIFEST.sha256`, and writes `RAH_WORLD_MEDIA_v14_RAVEN_WORLD_GRID.zip` under `apps/rah-world-media/dist` unless another output directory is supplied.

## Safety / scope

World Media opens public/legal stream URLs and optional webcam/provider pages. Normal cards remain hover/click driven; the large World Grid starts only when the user explicitly opens a grid preset. The live limit defaults to 16 even when hundreds of tiles are visible.

The source tree does not add DRM, paywall or geoblocking bypass logic. Trusted-LAN receiver mode remains explicit and token protected.

## Development rule

Change this canonical directory first, run the contract/CI checks, then build the distributable ZIP. Do not publish a newer package whose source has not been promoted back here.
