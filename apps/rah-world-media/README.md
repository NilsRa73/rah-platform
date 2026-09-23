# RAH World Media — canonical source

This directory is the editable source tree for the published **RAH World Media 9.9 SUPER MODE** package.

The source was promoted from `downloads/RAH_WORLD_MEDIA_v9_9_SUPER_MODE.zip` without redesigning the runtime. Future World Media work should change this directory first, run the contract/CI checks, and build the distributable ZIP with `BUILD-PACKAGE.ps1`.

## Build

On Windows PowerShell:

```powershell
.\apps\rah-world-media\BUILD-PACKAGE.ps1
```

The build uses a fixed file allowlist, generates `MANIFEST.sha256`, and writes the ZIP under `apps/rah-world-media/dist` unless another output directory is supplied.

## Safety / scope

World Media opens public/legal stream URLs and optional webcam/provider pages. Heavy playback remains click-to-start. The source tree does not add DRM, paywall, or geoblocking bypass logic.

## Next development line

Keep 9.9 as the stable baseline. New work should preserve the current TV, Radio, Webcam, Globe, World Live, Super Search, stream-health and Media Wall features while improving preview quality, recovery, source health, and packaging.
