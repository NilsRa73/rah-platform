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
