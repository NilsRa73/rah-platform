# Raven Agent Effect Pack v1 — Candidate

This Candidate is intentionally focused on a working end-to-end Raven control plane before UI/menu polish.

## Functional chain

`START-RAVEN-V1-ACCEPTANCE.cmd` performs the real HOVED-PC gate:

1. validate/repair the Raven Bridge Python environment,
2. start the loopback-only Desktop Bridge,
3. run Raven Doctor including real desktop capture,
4. run Agent Team LIVE through Raven + AI Fabric + local AI,
5. require all runtime gates to pass,
6. automatically freeze the known-good Candidate with SHA-256 evidence.

A successful run ends with:

`RAH RAVEN V1: FULL PASS + FROZEN CANDIDATE`

## Known local AI baseline

- LM Studio API: `http://127.0.0.1:1234/v1`
- model: `gemma-3-4b-it`
- no automatic model download or model replacement is required for acceptance

## Recovery

A successful Candidate is stored under:

`C:\RAH\_STABLE_CANDIDATES\RAVEN-AGENT-EFFECT-PACK-V1\<timestamp>`

Each snapshot includes a SHA-256 manifest. `ROLLBACK-RAVEN-V1.cmd` verifies the manifest before restoring known-good files and first backs up the current files under `C:\RAH\_ARCHIVE`.

Rollback is non-destructive overlay recovery: it does not delete files.

## Promotion boundary

Passing the local gate freezes a Candidate only. It does not merge PR #448 and does not promote STABLE automatically.
