# RAH OS Raven v0.7 Gold Shell — development candidate

This is the next RAH OS line built on top of the validated **RAH OS v0.3 Stable** Debian 13 base. The stable tree under `rah-os/` is intentionally left unchanged.

## Goal

v0.7 is the first large "make it feel like RAH" batch:

- RAH-branded boot menu for BIOS and UEFI;
- black/gold Plymouth boot splash;
- black/gold SDDM login background;
- RAH Gold Plasma splash and KDE defaults;
- upgraded Yggdrasil/raven wallpaper and RAH Raven icon;
- a fixed-function **RAH Hub** for Command Center, hardware, rescue, Nova and Live Acceptance;
- first-run welcome that opens the RAH Hub on request;
- visible OS identity as RAH OS while keeping `ID_LIKE=debian`;
- v0.7-aware Raven landing page and Live Acceptance;
- dedicated candidate CI/build workflow.

## Safety and release status

This is **not Stable**. It does not overwrite the v0.3 Stable files and it does not bypass the Windows v0.6/HOVED-PC acceptance work. Internal-disk installation remains a separate explicit user action.

The RAH Hub is a fixed allowlist launcher. It has no arbitrary command field, no remote shell, no automatic firewall changes and no disk-write action.

## Build

From a Debian 13/live-build environment:

```bash
sudo bash rah-os-next/build.sh
```

Output:

`rah-os-next/output/RAH-OS-Raven-v0.7-amd64.iso`

The build starts with the Stable `rah-os/config/` payload and overlays only the new v0.7 Gold Shell files from `rah-os-next/config/`.
