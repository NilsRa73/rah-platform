# RAH Raven Daily Driver — Legacy Acceptance Compatibility

RAH Raven Daily Driver 1.0 is **Stable**. The old Candidate-era owned-machine acceptance entry points are retained only so old shortcuts and instructions fail safely and lead to the current Stable flow.

## Current one-click path

Use:

`START-HER-RAH-RAVEN-DAILY-DRIVER.cmd`

That launcher calls the canonical Stable finalizer:

`RAH-RAVEN-DAILY-DRIVER-FINAL.ps1`

The Stable finalizer performs:

1. Stable manifest and authority-contract checks.
2. install/repair through the fixed installer;
3. isolated Python verification;
4. the full unit/smoke suite;
5. the deterministic Stable Runtime Gate;
6. optional app launch;
7. one machine-readable result under `C:\RAH\Logs\RAVEN-DAILY-DRIVER-FINAL-LATEST.json`.

## Old entry points

These names remain for backward compatibility:

- `ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat`
- `OWNED-MACHINE-ACCEPT-RAH-RAVEN.ps1`
- `REVIEW-RAH-RAVEN-DAILY-DRIVER-STABLE.py`

The BAT/PowerShell pair now forwards to the Stable finalizer. It no longer attempts Candidate promotion review.

If an old command passes a Facebook/archive path, the compatibility wrapper deliberately **does not read, copy, hash, or persist that path or its contents**. Live LM Studio, private archive imports, and owned-tool imports remain optional explicit diagnostics after release.

The Python review script is now read-only lifecycle verification. A healthy current repository returns:

`status: ALREADY_STABLE`

It never promotes, mutates Git, or consumes legacy evidence.

## Self-test

Compatibility launcher:

`ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat --self-test`

Lifecycle verifier:

`python REVIEW-RAH-RAVEN-DAILY-DRIVER-STABLE.py --self-test`

Both validate the current Stable contract. They do not reinstall or launch the application in self-test mode.

## Stable boundary

Current Stable contract:

- Daily Driver 1.0.0: Stable
- Stable gate: passed
- Command Center: 2.4.0 / generation 9
- Node Agent reference: 1.4.0
- Chronicle reference: 1.7.1
- Stable package: exactly 39 files
- authority delta: none
- shell, generic process API, generic file API, native remote control and credential-attack features: disabled
- cloud agent: disabled by default

The legacy compatibility layer is not part of the 39-file Stable runtime package and cannot reopen or re-promote the Stable lifecycle.
