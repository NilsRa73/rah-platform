# RAH Raven Daily Driver v1.0 Stable

A local-first Python desktop sidecar for the RAH/Raven stack. It preserves the authority boundaries of the canonical platform while giving one desktop workspace for Council, Investigator, Chronicle, Mission, Insights and Devices.

## Canonical dependencies

- Command Center 2.4 / generation 9
- Node Agent 1.4
- Chronicle 1.7.1
- Daily Driver read-only bridge: `127.0.0.1:18767`

## Safety boundary

- no shell or generic process/file API;
- no native remote-control API;
- device dispatch remains fixed-allowlist, simulated and explicitly approved;
- OpenAI cloud is disabled by default;
- local LM Studio uses loopback only;
- personal archive/tool imports happen only when the user selects a file;
- Stable release does not require private user data.

## Install / start

Use the canonical one-click entry:

`START-HER-RAH-RAVEN-DAILY-DRIVER.cmd`

Runtime data is stored under:

`C:\RAH\DailyDriver\runtime`

The finalizer runs install/repair, the full test suite, deterministic runtime acceptance and then starts the app. Its latest report is:

`C:\RAH\Logs\RAVEN-DAILY-DRIVER-FINAL-LATEST.json`

## Optional integrations

LM Studio, a real Facebook archive, owned Sherlock/PhoneInfoga/SpiderFoot exports, and OpenAI cloud can still be tested explicitly. They are integration features, not prerequisites for proving the Stable application build.

Legacy Runtime Evidence and owned-machine review utilities remain available for diagnostics and privacy-safe evidence generation.


## Theme Engine v1

The Daily Driver has one persistent theme selector instead of separate program forks.

Presets:
- Raven Gold — default command-center workspace
- Picasso — artistic presentation/show mode
- Steam / Game — larger controller/sofa targets plus a Steam Big Picture launcher
- Facebook Investigator — blue/black analysis workspace
- Egypt / Horus — black/gold/bronze command style
- Cyber Neon — local-AI/agent lab style
- Clean Windows — restrained work mode

The selected theme is stored in `runtime/state/theme.json`. Insights includes a contrast/layout-profile self-audit. Steam is launched through `steam://open/bigpicture`; the Daily Driver does not patch or inject code into the Steam client.
