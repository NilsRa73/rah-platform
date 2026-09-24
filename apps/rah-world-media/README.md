# RAH World Media — canonical source

This directory is the editable source tree for **RAH World Media 14.0 — RAVEN SMART CLUSTER**.

v14 keeps the existing TV, Radio, Webcam, Globe, World Live, Super Search, Media Wall and synchronized Receiver features, and adds token-protected distributed TV workers for trusted local networks.

## Smart Cluster model

The Windows controller sends only stream assignments and cluster state. Each TV Worker page fetches its assigned HLS URLs directly and uses the local browser/media pipeline to decode and render them. This avoids turning the HOVED-PC into a video relay and lets capable TVs/Android TV devices contribute their own decode/render capacity.

Each worker supports 1–12 configured slots and includes an AUTO TUNE pass that steps through 2/4/6/8/10/12 simultaneous previews and falls back when playback health drops below the threshold. Browser MediaCapabilities data is shown when available, but v14 does not claim or force GPU/VPU acceleration because that is controlled by the target OS/browser.

## Build

On Windows PowerShell:

```powershell
.\apps\rah-world-media\BUILD-PACKAGE.ps1
```

The build uses a fixed file allowlist, generates `MANIFEST.sha256`, and writes `RAH_WORLD_MEDIA_v14_RAVEN_SMART_CLUSTER.zip` under `apps/rah-world-media/dist` unless another output directory is supplied.

## Safety / scope

LAN exposure is explicit opt-in, token protected, and does not add UPnP/NAT-PMP/automatic port forwarding. World Media opens public/legal stream URLs and optional webcam/provider pages. It does not add DRM, paywall, subscription, or geoblocking bypass logic.
