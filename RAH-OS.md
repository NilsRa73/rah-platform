# RAH Raven OS — Front Door v0.5.1 candidate

RAH Raven OS Front Door is a thin, Windows-first orchestration layer over the existing Stable RAH components. It does not replace or widen the authority of Raven AI Fabric, Command Center 2.4 Stable, Node Agent 1.4 Stable, or RAH 2-PC Grid v1.3.0.

## Main entry point

Double-click `START-HER-RAH-OS.cmd`.

The startup path is now:

`PRECHECK -> SAFE REPAIR (only if needed) -> POSTCHECK -> START`

The precheck is read-only. Safe Repair refreshes only a fixed Front Door allowlist from `NilsRa73/rah-platform`. It does not run arbitrary commands, change firewall rules, persist Node tokens, discover the network, or auto-start the Node Agent.

## WPF Front Door

The control panel provides fixed local buttons for:

- PRECHECK
- SAFE REPAIR
- Raven Core / AI Fabric
- Raven Workspace (Desktop Bridge + local-AI probes + Raven Command)
- RAH Raven Command Center
- RAH 2-PC Grid
- 2-PC verification
- 2-PC install/update
- `C:\RAH` folder
- local status refresh for Raven Core :18765, Node Agent :18766, Desktop Bridge :47824, LM Studio :1234, Ollama :11434, Front Door self-test/repair readiness, Hardware Registry, and Project Memory configuration

`START LOCAL CORE` launches Raven Core and, when available, Command Center. It deliberately does not auto-start the remote Node Agent because Node tokens are fresh, transient, and tied to explicit local startup/enrollment.

## Install

Double-click `INSTALL-RAH-OS.cmd`.

The installer targets:

`C:\RAH\RavenOS`

It downloads the fixed Front Door files, runs the self-test, creates a desktop shortcut and a Start Menu shortcut, and only then launches the Front Door.

Installed files:

- `START-HER-RAH-OS.cmd`
- `INSTALL-RAH-OS.cmd`
- `REPAIR-RAH-OS.cmd`
- `RAH-OS-CONTROL.ps1`
- `RAH-OS-SELFTEST.ps1`
- `RAH-OS.md`

The candidate installer currently uses repository ref `main` and records it in `RAH-OS-SOURCE-REF.txt`. A stable release should pin an immutable release tag or commit.

## Self-test

Run `RAH-OS-SELFTEST.ps1` directly, or use PRECHECK in the control panel.

The self-test checks:

- Windows PowerShell compatibility
- WPF availability
- required Front Door files
- local Raven Core status on `127.0.0.1:18765`
- explicit Node Agent status on port `18766`
- Desktop Bridge status on `127.0.0.1:47824`
- LM Studio status on `127.0.0.1:1234`
- Ollama status on `127.0.0.1:11434`
- fixed Raven Workspace launcher presence
- fixed RAH launcher presence
- Hardware Registry presence
- Project Memory configuration presence

Missing optional components produce warnings. Missing Front Door/WPF requirements produce a failure.

## Safe Repair

Run `REPAIR-RAH-OS.cmd` or press SAFE REPAIR.

Safe Repair refreshes only the fixed Front Door allowlist. It cannot accept a user-supplied executable, shell command, remote target, firewall rule, or Node action.

## Safety boundary

- local fixed launcher allowlist only
- no arbitrary command field
- no generic shell endpoint
- no background network discovery
- no automatic firewall rule changes
- no Node token persistence
- no new remote permissions
- no automatic remote Node startup
- Stable component security boundaries remain authoritative

## Current dependency line

- Command Center: v2.4.0 Stable
- Node Agent: v1.4.0 Stable
- 2-PC Grid: v1.3.0
- Raven local bridge: `127.0.0.1:18765`
- Node local/LAN service: `:18766` when explicitly started

## Candidate acceptance

PASS requires:

1. `START-HER-RAH-OS.cmd` runs PRECHECK before the WPF panel.
2. Missing/corrupt Front Door support files can be refreshed only through the fixed Safe Repair allowlist.
3. WPF XAML and both PowerShell scripts parse on Windows PowerShell.
4. Every GUI action maps to a fixed known launcher, self-test, Safe Repair, or `explorer.exe C:\RAH`.
5. No user-supplied executable, command line, remote path, firewall rule, or shell command is accepted.
6. `START LOCAL CORE` still does not auto-start the Node Agent.
7. Existing RAH Stable component boundaries remain unchanged.


## Raven Core 7 integration

`C:\\RAH\\START-HER.cmd` is the new canonical daily entry point when Raven Core 7 is installed. It performs Core 7 precheck/repair/postcheck, starts the fixed local Raven Core and Command Center launchers when available, then opens this Front Door.

Front Door v0.3 reads `C:\\RAH\\RavenCore7\\state\\status.json` and shows the last Core 7 state. The **CORE 7 DIAGNOSTICS** button launches only the fixed `DIAGNOSTICS.cmd` entry point. Node Agent startup remains explicit and the existing Front Door safety boundary is unchanged.


## Worker Proof button

Front Door v0.4 adds **WORKER PROOF**. It launches only `C:\RAH\WORKER-PROOF.cmd`. The Core 7 worker validator reads the already-produced 2-PC acceptance files and their SHA-256 evidence; it does not receive or persist the fresh Node token. If hardware proof is still missing, the existing 2-PC Grid GUI is opened for the explicit physical pairing step.


## AI readiness controls

Front Door v0.5 adds two fixed local controls without widening Raven permissions:

- **AI SELF-CHECK** launches `C:\RAH\RAVEN-AI-SELF-CHECK.cmd`. The existing AI Fabric self-check verifies Raven Core health, the elevated job executor, LM Studio inference, AnythingLLM readiness, Project Memory, the local approval gate, and multi-AI Council readiness. It may start only the already-defined local Raven scheduled tasks used by AI Fabric.
- **ANYTHINGLLM GATE** launches `C:\RAH\START-HER-ANYTHINGLLM-APPROVAL.cmd`. The existing acceptance test remains loopback-only and exercises the fixed read-only `system-inventory` capability after AnythingLLM approval.

The Front Door status panel now also reports whether these two launchers are installed. Their absence does not grant a fallback shell or broaden authority; it is reported as a missing optional integration.


## v0.5.1 status hardening

Front Door v0.5.1 explicitly resolves the fixed `RAVEN-AI-SELF-CHECK.cmd` and `START-HER-ANYTHINGLLM-APPROVAL.cmd` launchers before constructing the status object. This keeps `Set-StrictMode -Version Latest` compatible with the AI readiness status panel and prevents an uninitialized-variable failure during startup/refresh. Contract tests now verify both launcher assignments occur before the status object consumes them.
