# PR #477 — HOVED-PC backup / rollback gate (NO DEPLOY)

**Status:** HOLD. The verified working Raven Desktop Bridge v1.7.1 at
`127.0.0.1:18765` must remain running. This document authorizes no change.

## Stage 0 — read-only inventory

The existing PR477 Agent Runner capability is explicitly confirmed from
`/agent/ui`, not auto-run. The operator must first confirm that this UI is
served by the intended new candidate; the current HOVED-PC Bridge may not yet
include the PR477 capability. The preflight returns JSON to the browser only.

Record:
- listener PID for TCP 18765 and its **actual executable path** (not guessed
  by process name); a Python interpreter path is **not** a Raven install path
- current `/health` version, Doctor snapshot, relevant process identity,
  launch entrypoint (shortcut target / scheduled task / service if any), actual
  executable and configuration roots — independently verified on HOVED-PC
- any currently available backup folders (existence is *not* a verified backup)
- candidate location fixed to
  `C:\RAH\_stage\PR477\RAH-Raven-Vision.exe`; optional SHA-256 is of
  the actual EXE, not the SHA-256 of a GitHub artifact ZIP

**Gate:** `deployment_gate.decision = HOLD` regardless of discovered paths.

## Stage 1 — backup gate (separate future approved operation)

**Do not perform until explicitly approved.** Obtain a consistent copy outside
the live install of the exact launch executable/binary, relevant accompanying
Python sources and HTML assets, configuration, startup shortcuts/tasks,
and required logs. Exclude credentials/tokens from anything uploaded.

A backup is verified ONLY when the exact source and backup file inventory
and cryptographic hashes are compared, the backup location is confirmed,
and a non-destructive restore dry run is proven on an isolated location.
Record the exact process/shortcut restoration steps, original version,
and rollback trigger. The existing running process remains undisturbed.

If any item cannot be identified or compared: **STOP / HOLD**.

## Stage 2 — candidate gate (separate future approved operation)

Use exactly one standalone candidate under `C:\RAH\_stage\PR477`.
Verify trusted GitHub commit SHA and independently trusted candidate EXE
SHA-256. The CI ZIP digest cannot validate the extracted EXE alone.

Run a no-network `--self-test` on a suitable isolated machine, or after
safety approval under conditions that cannot bind port 18765. Do not start
a second Raven Desktop Bridge on that port.

## Stage 3 — controlled cutover (NOT authorized)

Only after explicit operator approval and verified backup/restore evidence:
schedule one controlled cutover and check `/health`, `/doctor/ui`,
`/command-wheel/ui`, `/agent/ui`, and `/vision/ui`.
Recheck the Agent Runner preflight button and read-only API constraints.
Failure triggers restoration from the verified backup and rechecking the
old healthy Bridge. Never alter Windows boot, RAH GOLD, model settings, or
tokens as part of this PR.

## Proof boundary

CI PASS proves the test package was built and tests passed in GitHub Actions;
it is not proof of a backup or deployment on HOVED-PC.
The preflight reads but does not create backups, test rollback, install,
restart, upload, or write local files.
