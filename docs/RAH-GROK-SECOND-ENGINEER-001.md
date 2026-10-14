# RAH AI Studios — Grok Second Engineer, review 001

**Status:** DRAFT CANDIDATE. This branch does not change the running HOVED-PC, Raven Bridge, Gemma, RAH OS or production GitHub main branch.

## Single source of truth
- Work queue: [GROK-REVIEW-001, issue #461](https://github.com/NilsRa73/rah-platform/issues/461)
- Source to review: pinned commit `a9642c31e99481bdfe29ac7dc87fa3461eb05321`.
- Verified latest HOVED-PC signals: Raven Bridge 18765 HTTP health PASS; Gemma model endpoint responding; Agent Bridge 18781 offline with inferred token-context access denied; independent authenticated worker proof PENDING.
- GitHub issue is for nonsecret coordination. Sensitive diagnostics remain local; send only sanitized summaries to `RAH CLOUD/99_INBOX`.

## Working agreement
1. ChatGPT maintains the task and independently verifies review conclusions and cloud report readback.
2. Grok Build locally reads a temporary snapshot containing issue #461 and the pinned source, with its tool allowlist restricted to `read_file,grep,list_dir` and all terminals, editing and web tools disallowed.
3. A one-click **local candidate launcher**, `START-HER-RAH-GROK-REVIEW-001.cmd`, has been prepared separately for the user. It is not part of this draft PR and has **not** been executed on Windows.
4. When the user elects to run it, the launcher should generate `C:\RAH\Logs\GROK-REVIEW-001-LATEST.md` and sanitized JSON, and copy to `G:\My Drive\RAH CLOUD\99_INBOX` if mounted. Local copies are not proof of completed remote sync.
5. ChatGPT independently fetches the cloud file and reviews it before proposing any actual repair.

## Guardrails and billing
- No scripts are run merely by reading this file or GitHub issue.
- No automatic installs, elevation/UAC, model changes, token reads, ACL changes or production service stops.
- Headless Grok CLI is available in official docs via `grok --no-auto-update -p ... --output-format json`; its first use may require existing subscriber authentication. The launcher refuses if an `XAI_API_KEY` or `GROK_API_KEY` environment variable exists to avoid accidentally using an API key. This is **not** exhaustive proof that a custom provider is absent, so account billing configuration remains unverified.
- If Grok CLI is missing, CLI options differ, sign-in is unavailable, or output is not parseable: stop as BLOCKED. Do not retry on behalf of the user.

## Acceptance
- **GitHub candidate PASS:** draft PR exists with candidate AGENTS rules and this documentation; issue #461 remains OPEN.
- **Runner static PASS:** one local CMD wrapper with embedded PowerShell was checked structurally. **Windows runtime: NOT_VERIFIED**.
- **Grok review delivery PASS:** only after user's optional single run produces a nonsecret report independently visible through the Google Drive connector.
- **Agent Bridge runtime PASS:** requires separate, explicitly approved authenticated 18781 and worker chain test; no such claim is made here.
- **RAH Stable Gate:** OPEN until full acceptance of Raven, local AI, worker/node and OS.

The Grok account and GitHub repository are not automatically linked by creating these GitHub files. A future approved local invocation or app connection is required.

## BIG BATCH 001 — 12 October 2026, independent review + safe candidate

**Cloud evidence now read independently by ChatGPT from the connected Drive folder:**
- `GROK-REVIEW-001-LATEST.json`, generated 2026-10-12T21:24:00Z, reports `grokExecuted=true`, `reportsWritten=true`, `GROK_REVIEW_DELIVERED_LOCAL_STABLE_GATE_OPEN`; reports `credentialsTouched=false`, `tokenAclModified=false`, `codeOrServicesModified=false`. A producer report cannot prove its own integrity/authenticity or token immutability.
- `GROK-REVIEW-001-LATEST.md`, detailed static Grok review, independently retrieved and reviewed.
- `RAH-AGENT-BRIDGE-SAFE-FIX-LATEST.json`, 2026-10-12T20:17Z: `BLOCKED_SAFE`, `python_self_test=PASS`, `port_18781_health=false`, `token_state=NOT_CHECKED`, worker/Lenovo unverified. `EXISTING_TOKEN_ACCESS_DENIED_UNCHANGED` is inferred and does **not** prove the exact failing file operation.
- `RAH-AGENT-JOBS-v3-LATEST.json`, 2026-10-12T21:37Z: **PLANNED_NOT_EXECUTED**, not agent-work proof.
- `RAH-REPORT-FLOW-HEALTH-R2-LATEST.json`, 2026-10-12T21:47Z: locally synced report; remote readback must be checked separately.

**Static review correction:** Grok's claim that `Path.exists()` always suppresses `PermissionError` is incorrect for Python 3.13 (and should not be assumed for RAH's 3.12 runtime). On Python 3.13, `_ignore_error(EACCES)` is false and a permission error may propagate. Python-version-specific behavior should not be relied upon. New strict loader calls `read_text` directly and fails closed on any `OSError`.

**Isolated source candidate changes (no deployment):**
- `rah_agent_bridge.py`: production startup now uses `read_existing_token()` and refuses missing, invalid or unreadable token without creating/rotating it. Token validation occurs **before** JobBus directory writes. `load_or_create_token()` remains only for synthetic temporary test helpers. This does not modify the separate production installer, which must **not** be re-run on HOVED-PC.
- `JobBus.finish` rejects mismatched `claimedBy` and worker ID (queue-state integrity improvement, not an authentication guarantee since clients share a bearer token).
- `tests/test_agent_bridge_fail_closed_candidate.py`: six isolated regression cases for token preservation, missing/invalid/unreadable token, pre-write startup rejection, and forged worker completion.
- `tests/RAH-AGENT-BRIDGE-RUNTIME-TEST.ps1`: creates an explicit **synthetic token in a CI-only temporary root** so Windows test no longer relies on production-style implicit token creation.
- `tools/rah_grok_review_receipt_gate.py` and `tests/test_grok_review_receipt_gate.py`: accept or reject sanitized Grok *receipt claims* without declaring port 18781, actual agent work or OS Stable Gate PASS.
- GitHub Actions candidate workflow runs those offline tests and Windows ephemeral runtime tests automatically. **GitHub CI PASS is not equivalent to HOVED-PC PASS.**

**Remaining BLOCKED:** Actual HOVED-PC port 18781, Windows scheduled task identity, original token reachability, Agent Worker live delivery, local Gemma execution in the current round, authenticated Lenovo node chain, RAH OS acceptance. No token/ACL/process changes authorized or performed by this batch.

**Acceptance discipline:** Review-delivery confirmed by independent Google Drive readback. Source candidate is only accepted when exact-head GitHub Actions checks succeed. Machine Stable Gate OPEN until independent authorized on-machine evidence; never auto-merge this draft.


## BIG BATCH 004 — 13 October 2026: HOVED-PC proof + Raven GOLD compatibility

### Fresh independently retrieved Drive reports

The following files appeared in the exact user-owned `RAH CLOUD/99_INBOX` folder. ChatGPT read their contents through the connected Google Drive; the local report's own `PENDING_CONNECTOR` flag is historical producer state, not the post-readback verification here.

- `RAH-RAVEN-AGENT-LIVE-LATEST.json`, 2026-10-13 15:11 UTC: Raven GOLD identity PASS, real *read-only* `system-inventory` and `hovedpc-local-status` agent-runner jobs PASS. **Queued Job Executor remains HTTP 404**, no proof of its elevation.
- `RAH-AGENT-INTEGRATION-R2-LATEST.json`, 2026-10-13 15:10 UTC: a synthetic loopback Agent Bridge on **18782**, real pinned `rah_agent_worker.py` and existing **local Gemma inference** PASS (both explicit local-model and protocol-stub cases). Unauthenticated request rejected with 401; no production 18781 startup.
- `RAH-AGENT-BIG-BATCH-R2-LATEST.json`, 2026-10-13 15:09 UTC: 18781 remains `BLOCKED_SAFE`, token access preflight refused, and `/ai/health`, `/agent/jobs/health` returned HTTP 404 from canonical Raven GOLD. Existing token and ACL unchanged according to machine report.
- `RAH-RAVEN-GEMMA-P2-LATEST.json`: local Gemma inference PASS but real queued executor blocked. `RAH-HOVED-PC-R8-LATEST.json`: canonical `18765/health` PASS, 18781 OFFLINE, report sync separately staged.

### Pinned-code route mismatch (source fact)

- `desktop-bridge/raven_bridge.py` (canonical GOLD) provides `POST /lm/chat` and `POST /agent/run`; **does not register** `/ai/chat` or `/agent/jobs`.
- `desktop-bridge/raven_bridge_agent.py` imports `raven_jobs` and `raven_ai_fabric` to layer `/agent/jobs` and `/ai/chat` over the canonical app, but that entrypoint is not the verified stable GOLD process on HOVED-PC.
- Pinned `rah_agent_worker.py` expects `POST /ai/chat` and `POST /agent/jobs` on 18765: this explains the **route-level 404 mismatch**, distinct from production 18781 startup, task and token problems.

### New unmerged candidate source and CI

- `rah_agent_worker.py` now supports `POST /lm/chat` only when an explicit `provider=lmstudio` receives 404 from `/ai/chat`. No `provider=auto` or paid/cloud fallback occurs on this compatibility path. It preserves explicit model and returns `handledBy=lmstudio`.
- Only known read-only capabilities `system-inventory` and `hovedpc-local-status` may use `POST /agent/run` after `/agent/jobs` is missing. Response must attest `read_only=true`, `files_modified=false`. Any other queued capability still rejects missing routes; no arbitrary shell path added.
- `tests/test_raven_gold_worker_compat.py` adds seven mocked-HTTP regression cases, and the GitHub workflow tests both those cases and the real worker against an isolated Raven/AI mock.
- GitHub Actions exact head `3547ecf293788a1956aba61da693475b5c790cad`: runs [#38420931530](https://github.com/NilsRa73/rah-platform/actions/runs/38420931530) and [#38420931225](https://github.com/NilsRa73/rah-platform/actions/runs/38420931225) **SUCCESS** including Windows ephemeral queue runtime.
- These CI tests do not prove the new compatibility code was deployed on HOVED-PC; live proofs are from pre-existing local test runners, not the new candidate. This PR remains DRAFT and unmerged.

### Remaining production blocks

Production 18781 still OFFLINE, original token readability by intended scheduled-task identity and exact startup exception unknown. Raven's **queued** elevated Job Executor remains HTTP 404/not ready despite canonical **direct read-only** runner success. Lenovo authenticated node still unproven. OS and Stable Gate remain OPEN.

**No install, merge, production token/ACL task changes, service restart, paid API call, or manual test requested or performed by ChatGPT.** External report producer claims remain claims unless independently verified.
