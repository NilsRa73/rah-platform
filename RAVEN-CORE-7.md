# RAH Raven Core 7.0 — Foundation Batch

Raven Core 7.0 is the canonical Windows integration layer over the RAH components that already exist and have their own safety contracts.

## One-click entry point

After installation, double-click:

`C:\RAH\START-HER.cmd`

The intended flow is:

`PRECHECK -> fixed Safe Repair if required -> POSTCHECK -> START`

The launcher starts only fixed local RAH launchers. It does **not** start a remote Node Agent automatically.

## What this foundation batch integrates

- RAH OS Front Door / self-test / Safe Repair
- Raven Core + AI Fabric on `127.0.0.1:18765`
- existing fixed Raven capability and Job Executor status
- Node Agent status on `:18766` without automatic startup
- LM Studio status on `127.0.0.1:1234`
- AnythingLLM status on `127.0.0.1:3001`
- Hardware Registry
- Project Memory configuration state
- RAH 2-PC Grid presence and verification launcher
- Command Center presence
- durable machine-local Core node ID
- JSON status and JSONL audit log

## Files users run

1. `INSTALL-RAVEN-CORE-7.cmd` — first install/update of this Core 7 batch.
2. `START-HER.cmd` — normal daily entry point.
3. `DIAGNOSTICS.cmd` — detailed local status and hardware refresh.
4. `REPAIR.cmd` — fixed-scope Safe Repair.
5. `WORKER-PROOF.cmd` — validates existing real-hardware 2-PC evidence; if evidence is still pending it opens the existing fixed 2-PC Grid for the physical step.
6. `ACCEPT-RAVEN-CORE-7.cmd` — one-click software acceptance; it consumes Worker Proof only after immutable evidence validation.

PowerShell is used under the hood, but normal operation is through `.cmd` launchers.

## Installed layout

User-facing runnable files stay at the top level:

- `C:\RAH\START-HER.cmd`
- `C:\RAH\DIAGNOSTICS.cmd`
- `C:\RAH\REPAIR.cmd`
- `C:\RAH\WORKER-PROOF.cmd`
- `C:\RAH\ACCEPT-RAVEN-CORE-7.cmd`
- `C:\RAH\INSTALL-RAVEN-CORE-7.cmd`

Core implementation/state:

- `C:\RAH\RavenCore7\RAVEN-CORE-7.ps1`
- `C:\RAH\RavenCore7\RAVEN-CORE-7-WORKER-PROOF.ps1`
- `C:\RAH\RavenCore7\RAVEN-CORE-7-ACCEPTANCE.ps1`
- `C:\RAH\RavenCore7\RAVEN-CORE-7-CONFIG.json`
- `C:\RAH\RavenCore7\state\status.json`
- `C:\RAH\RavenCore7\state\worker-proof.json`
- `C:\RAH\RavenCore7\state\acceptance.json`
- `C:\RAH\RavenCore7\state\node-id.txt`
- `C:\RAH\RavenCore7\logs\core7-audit.jsonl`

## Definition of foundation PASS

The foundation is ready when:

- Front Door launcher + self-test exist.
- AI Fabric launcher exists.
- Core 7 can create a machine-local node ID.
- Core 7 writes `status.json`.
- fixed local status checks run without arbitrary command input.
- Hardware Registry refresh is best-effort and does not widen permissions.
- local Raven health/capabilities can be read when port 18765 is online.
- Node 18766 is only reported; it is not auto-started.
- no firewall rule is created or modified.
- no Node token is persisted.
- no background LAN discovery is introduced.

`READY-TO-START` means the required files exist but local Raven Core is currently offline.
`PASS` means the required files exist and Raven Core is online.
`FAIL` means a required foundation file is missing.

## Safety contract

Core 7 adds orchestration, not authority.

- no generic shell
- no user-provided executable/path/command
- no `Invoke-Expression`
- no automatic firewall changes
- no background network scanning/discovery
- no automatic remote Node startup
- no Node token persistence
- remote actions remain limited by the existing Raven fixed capability allowlist
- Core repair delegates only to the existing RAH OS fixed-allowlist Safe Repair

## What remains for later Core 7 milestones

This batch deliberately does not pretend physical multi-PC acceptance is complete. The next gates are:

1. HOVED-PC reboot acceptance.
2. Omen/second-PC explicit Node enrollment.
3. HOVED-PC -> Worker fixed-capability job -> result return.
4. shared-storage round-trip with checksum.
5. Børge worker package after the two local PCs pass.
6. only then cloud workers.

The existing RAH 2-PC Grid remains the explicit route for current two-PC hardware verification; Core 7 does not silently discover or enroll other devices.


## Acceptance truth model

`ACCEPT-RAVEN-CORE-7.cmd` validates the local Core 7 software contract, PowerShell syntax, policy flags, Front Door self-test, Hardware Registry self-test and Project Memory snapshot self-test when those components are installed.

A missing/offline optional local AI service is informational or a warning, not an invented failure. More importantly, the acceptance report always records physical second-PC acceptance as explicitly pending until an enrolled Worker actually completes a real fixed-capability round trip. Core 7 never turns presence of scripts into a fake hardware PASS.


## Worker Proof

`WORKER-PROOF.cmd` is the bridge between the already-stable 2-PC Grid and Core 7. It does not implement a new remote protocol.

It runs the existing 2-PC client/acceptance self-tests, then looks only for:

- `C:\RAH\2PCProof\results\last-inventory.json`
- `C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json`

A Worker becomes `PASS` only when the acceptance schema and all fixed safety gates are true and the source inventory SHA-256 still matches the hash recorded by the real-hardware acceptance step. The compact Core state stores the accepted hostname and evidence hashes, never the fresh Node token.

If physical evidence is missing, Worker Proof reports `PENDING` and can open the existing 2-PC Grid GUI. Token entry remains inside that existing explicit pairing flow; Core 7 never reads, asks for, copies, or persists the token.

This preserves the current route:

`HOVED-PC -> Node :18766 /raven/status -> local Raven :18765 -> system-inventory`

with no arbitrary commands, caller paths, caller arguments, discovery scan, or firewall automation.
