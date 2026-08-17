# RAH AI Investigator v1.0 RC2

Local-first personal account-recovery and authorized personal-OSINT module for RAH Raven.

## Status

**Candidate / RC2 — not Stable.** RC2 replaces the unusable RC1 binary bundle with transparent source files plus a reproducible bundle generated from those sources. Stable promotion remains blocked until the automated Candidate gate is green and the separate manual owned-target/UI/tool-result checks are completed.

## Core capabilities

- import user-selected extracted Facebook/Google/Yahoo and other personal archive data
- normalize a local ZIP, directory, or supported text/JSON/HTML/CSV/Markdown/log file into Case JSON
- extract emails, phone numbers, URLs and usernames from local evidence
- identity seeds and aliases
- Account Matrix with recovery status
- local relationship graph
- source-file evidence list and observed-date timeline
- Case JSON and identifiers CSV export
- fixed local Agent Job JSON export

## Fixed optional agent-job profiles

The browser application **does not execute these tools automatically**. It only exports a reviewable job JSON after explicit authorization confirmation.

- Sherlock — public username discovery
- PhoneInfoga — own-number public-footprint / metadata workflow
- SpiderFoot — passive mode only

The Investigator excludes password guessing, credential stuffing, phishing, session theft, 2FA bypass, exploit scanning, active offensive scanning, hidden collection and automatic external-tool execution.

## Transparent source

Auditable RC2 source is under `source/`:

- `RAH-AI-INVESTIGATOR.html` — local browser application; no network requests
- `rah_investigator.py` — Python standard-library archive normalizer and self-test
- `CHECK-RAH-INVESTIGATOR.ps1` — Windows local self-check
- `CHECK-RAH-INVESTIGATOR-KALI.sh` — Linux/Kali-compatible local self-check
- `RUN-ME-FIRST-RAH-INVESTIGATOR.bat` — fixed Windows launcher
- `IMPORT-ARCHIVE-TO-RAH-INVESTIGATOR-v1.0-RC2.ps1` — explicit local archive-to-Case-JSON helper

## Package

The Candidate packaging workflow generates `RAH-AI-Investigator-v1.0-RC2-Full-Bundle.zip` deterministically from the reviewed source and documentation. The accompanying SHA-256 file must match the exact ZIP bytes before runtime smoke tests run.

On Windows, extract the RC2 bundle and double-click `RUN-ME-FIRST-RAH-INVESTIGATOR.bat`. The launcher runs the local self-check first and opens only the bundled HTML application.

For archive normalization without the browser UI:

```text
python rah_investigator.py normalize <local-file-directory-or-zip> --out rah-investigator-case.json
```

No original input file is deleted or modified.
