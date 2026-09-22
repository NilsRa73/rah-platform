# RAH Raven OS — Front Door v0.1 candidate

This is the first thin RAH OS orchestration layer over existing Stable components. It does not replace or widen the authority of Raven AI Fabric, Command Center 2.4 Stable, Node Agent 1.4 Stable, or RAH 2-PC Grid v1.3.0.

## Main entry point

Double-click `START-HER-RAH-OS.cmd`.

The WPF control panel provides fixed local buttons for:

- Raven Core / AI Fabric
- RAH Raven Command Center
- RAH 2-PC Grid
- 2-PC verification
- 2-PC install/update
- `C:\RAH` folder
- local status refresh for ports 18765/18766 and persistent Hardware Registry state

`START LOCAL CORE` launches Raven Core and, when available, Command Center. It deliberately does not auto-start the remote Node Agent because Node tokens are fresh, transient, and tied to explicit local startup/enrollment.

## Install

Double-click `INSTALL-RAH-OS.cmd`. It installs the Front Door files under:

`C:\RAH\RavenOS`

The candidate installer downloads only a fixed three-file allowlist from this repository and writes `RAH-OS-SOURCE-REF.txt`. A future stable RAH OS release should pin this source ref to an immutable release tag.

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

1. `START-HER-RAH-OS.cmd` finds and opens `RAH-OS-CONTROL.ps1`.
2. WPF XAML parses on Windows PowerShell 5.1.
3. Refresh reports local component presence without modifying the machine.
4. Every action maps to a fixed known launcher or `explorer.exe C:\RAH`.
5. No user-supplied executable, command line, remote path, firewall rule, or shell command is accepted.
6. Existing RAH stable tests remain unchanged and pass.
