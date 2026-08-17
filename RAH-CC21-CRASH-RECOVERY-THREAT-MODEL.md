# RAH CC 2.1 Crash-Recovery Threat Model

Status: implementation-readiness only. No updater or runtime mutation is authorized by this document.

## Protected state

The updater already stages and Git-verifies the full 50-file transaction before local activation and can roll back handled activation errors. The remaining lifecycle risk is process termination, power loss, or concurrent updater execution during the flat-file activation window.

The recovery design protects only the fixed CC 2.1 transaction set: the 49 canonical package files plus `RAH-COMMAND-CENTER-VERSION.json` last. It must not become a generic file-transaction engine.

## Trust anchors retained

The only accepted package source remains the fixed GitHub-verified CC 2.1 promotion commit `a6b77f93dca5f774cdb76deb707edc71f86638a1`. Commit SHA, verified Git tree, exact `100644` blob map, exact package allowlist, downloaded Git-blob identity, recursive dependency integrity, Node 1.3 token-proof behavior, and exact 4/3/5 authority remain unchanged.

## Exclusive execution

A later implementation must acquire an OS-level exclusive file handle with `FileShare.None` on the fixed root-local lock before journal inspection, recovery, or network activity. The existence of the lock file is not authority; only the live OS handle is. No unlocked fallback is permitted.

## Journal data minimization

The active journal is fixed at `.rah-transactions/command-center-active.json`. The only per-file recovery facts are fixed relative path, expected Git blob ID, whether the target existed before activation, and its original SHA-256 when it existed. Transaction directories are derived from a strict transaction ID, never supplied by the journal as arbitrary filesystem paths.

Tokens, HMAC/auth proofs, nonces, passwords, peer IDs, requester context values/digests, Node session secrets, action challenges, or local approval proofs are forbidden journal material.

## State machine

`staged` means every transaction byte is verified but target mutation has not started. `backup-complete` means every pre-existing target has a verified backup and original state is recorded; mutation still has not started. `activation-started` must be durably recorded before the first target replacement. `committed` may be recorded only after all 50 final target Git blobs verify. `rollback-started` is written before any recovery mutation and makes rollback restartable/idempotent.

A crash after activation completed but before `committed` is intentionally conservative: the next updater run restores the pre-transaction state instead of guessing that activation was complete.

## Startup recovery

Recovery runs before any GitHub/API/raw download. `staged` and `backup-complete` need no target rollback because mutation was not authorized yet. `activation-started` and `rollback-started` restore all originally existing targets from verified backup and remove only fixed transaction targets that were originally absent. `committed` first verifies all 50 current target blobs; any mismatch transitions to rollback.

Malformed, oversized, ambiguous, wrong-release, wrong-phase, duplicate, path-traversal, invalid-hash, missing-backup, or otherwise inconsistent journal state fails closed. An orphan journal temp file is ambiguity, not permission to continue. Unknown staging/backup directories without the active journal are never trusted as recovery authority.

## Durable journal writes

The implementation target is same-directory temporary write, write-through/durable flush, then replace/rename of the fixed active journal. Transition ordering matters more than cleanup convenience: recovery authority must reach durable storage before the mutation it authorizes.

## Explicit limits

This design does not claim a single atomic filesystem transaction across 50 files. It is a crash-recoverable rollback protocol. Disk/controller failures that corrupt both the active package and verified backup remain outside this phase. Reparse-point/junction hardening and stronger filesystem provenance may be treated as a later independent boundary if needed.
