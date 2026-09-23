# RAH Raven OS — Front Door v0.6 candidate

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
- `ACCEPT-RAH-OS-v0.6.cmd`
- `ACCEPT-RAH-OS-v0.6.ps1`
- `RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd`
- `RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1`
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


## v0.6 unified acceptance gate

Front Door v0.6 adds a fixed **RUN HOVED-PC v0.6** action and reads the resulting state from:

`C:\RAH\RavenOS\state\RAH-OS-ACCEPTANCE.json`

The v0.6 acceptance engine evaluates five independent areas:

1. **Front Door** — required launchers, control panel, self-test, repair and acceptance files are installed.
2. **Raven Core** — Core 7 PASS evidence or the local Raven Core loopback service on port 18765.
3. **Local AI** — latest Raven AI Self-Check PASS, or a visible LM Studio/Ollama endpoint while full proof remains pending.
4. **AnythingLLM** — the loopback-only approval acceptance report must be PASS for a full v0.6 PASS.
5. **Worker Proof** — the existing immutable 2-PC real-hardware proof must be PASS and accepted.

The overall state is:

- `PASS` only when all five areas are PASS.
- `PENDING` when no area has failed but one or more still need runtime or real-hardware proof.
- `FAIL` when a required Front Door file is missing or existing Worker Proof is invalid/failed.

The acceptance engine does not start the Node Agent, discover the LAN, alter firewall rules, read or persist a Node token, or add remote authority. Its only write is the local acceptance state file.

## v0.6 build order

The release order is intentionally gated:

`Front Door v0.6 -> Raven Core 7 -> Local AI -> AnythingLLM approval -> Worker Proof -> RAH-OS-ACCEPTANCE.json -> ISO candidate`

The Linux live ISO remains on the validated v0.3 Stable line until the Windows-first v0.6 acceptance chain is green. After that, the ISO metadata/build scripts can be bumped and a new v0.6 candidate ISO produced, inspected and hardware-boot tested before any Stable promotion.


## HOVED-PC ordered acceptance sequence

The one-click entry point is:

`C:\RAH\RavenOS\RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd`

It runs the v0.6 gates in this exact order:

`Front Door -> Raven Core -> Local AI -> AnythingLLM -> Worker Proof -> Combined Acceptance`

The runner executes the existing fixed PowerShell validators directly so intermediate `.cmd` pause prompts do not break automation. Worker Proof uses validation mode only; it does not open the physical pairing flow and it never reads or stores the fresh Node token.

After the five stages, the runner invokes the combined acceptance engine and reconciles each gate with evidence from the current HOVED-PC run. Every area in `RAH-OS-ACCEPTANCE.json` is therefore one of:

- `PASS`
- `PENDING`
- `FAIL`

The final files are:

- `C:\RAH\RavenOS\state\RAH-OS-ACCEPTANCE.json` — release-gate result.
- `C:\RAH\RavenOS\state\RAH-OS-HOVED-PC-SEQUENCE.json` — ordered stage log with exit codes and output tails.

AnythingLLM exit code 10 is treated as `PENDING` because it means local one-time configuration is still required. Local AI `PARTIAL` is also `PENDING`. A failed current Front Door, Local AI or AnythingLLM run is not allowed to inherit a stale PASS from an older report.
