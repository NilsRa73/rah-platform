# RAH Raven Daily Driver — Owned-Machine Acceptance Companion

This companion exists only to make the final **manual owned Windows 10/11 acceptance** easier. It does not change the immutable 37-file Daily Driver Candidate runtime package and it cannot promote Stable or Frozen.

## One-click use

1. Install/extract the normal `RAH-Raven-Daily-Driver-v1.0-Candidate-Windows` artifact.
2. Extract the `RAH-Raven-Daily-Driver-Owned-Machine-Acceptance` companion into the **same package root**, preserving folders.
3. Double-click **`ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat`**. This is the only launcher you need.
4. The launcher performs `PRECHECK -> SAFE REPAIR -> RUNTIME TEST -> FINAL REPORT`:
   - validates the Candidate/Stable lifecycle boundary and exact 37-file runtime package contract;
   - detects Python and the Daily Driver venv;
   - runs the existing installer automatically in no-start mode only when the venv or desktop shortcut needs repair;
   - verifies the desktop shortcut target/working directory and launches that verified shortcut for the required human UI confirmation;
   - checks LM Studio only on `127.0.0.1:1234`; if LM Studio is installed but not running, the runner may start the installed app and wait briefly for the local endpoint;
   - stops with a clear `PENDING` report rather than a generic failure when LM Studio/model configuration is the only missing prerequisite;
   - asks you to select your own Facebook/archive ZIP when required;
   - runs the existing Runtime Gate, privacy-safe Evidence exporter and validator;
   - runs the existing owned-tool review for your own/authorized Sherlock, PhoneInfoga and SpiderFoot-passive exports;
   - writes one human-readable `PASS`, `PENDING` or `FAIL` summary to your Desktop evidence folder.
5. If the result is `PENDING`, fix the single printed prerequisite and rerun the **same BAT**. No scattered command sequence is required.

The human-readable summary is written to:

`Desktop\RAH Daily Driver Evidence\FINAL-ACCEPTANCE-SUMMARY.txt`

The canonical machine-readable acceptance summary remains:

`apps\rah-raven-daily-driver\runtime\state\owned-machine-acceptance.json`

You may also pass an explicit owned archive path:

```text
ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat "C:\path\to\your-own-facebook-export.zip"
```

A non-mutating static contract self-test is available for CI/development:

```text
ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat --self-test
```

## What is repaired automatically

The acceptance runner may run the already-existing `INSTALL-RAH-RAVEN.bat` with `RAH_RAVEN_INSTALL_NO_START=1` when the isolated venv or desktop shortcut is missing/incorrect. It does **not** install Python, install LM Studio, enable an LM Studio server, select private evidence for you, or attest manual UI/export review on your behalf.

That boundary is deliberate: prerequisites that can be verified and repaired mechanically are automated; ownership/authorization and human UI review remain explicit.

## What the owned-tool review does

`apps\rah-raven-daily-driver\FINAL-OWNED-TOOL-REVIEW.py` does **not** launch Sherlock, PhoneInfoga or SpiderFoot. It only reads export files that you explicitly select.

For each export it:

- checks the allowed format;
- refuses empty files and files above the review limit;
- hashes the source before and after parsing to prove the source file was not modified;
- imports the export through Daily Driver's existing local `Investigator.import_tool_export()` path using a temporary Chronicle database;
- displays only counts and entity-kind summaries for review;
- requires explicit owned/authorized and plausibility confirmation;
- requires an additional `PASSIVE` confirmation for SpiderFoot;
- writes no source file path, source hash, or identifier value into the privacy-safe summary;
- performs no automatic external-tool execution.

Its privacy-safe summary is written under the user's actual Windows Desktop folder:

`RAH Daily Driver Evidence\OWNED_TOOL_REVIEW_SUMMARY.json`

You can rerun only this component with:

`apps\rah-raven-daily-driver\FINAL-OWNED-TOOL-REVIEW.bat`

## What the LM Studio live check does

- reads the existing Daily Driver agent configuration;
- accepts enabled `lmstudio` agents only;
- requires at least two enabled local LM Studio Council roles;
- rejects any LM Studio base URL that is not loopback (`127.0.0.1`, `localhost`, or `::1`);
- sends one fixed, harmless health prompt to each role;
- requires a non-empty answer;
- records only role metadata, model name, PASS/FAIL and answer character count;
- **does not persist the model answer text**;
- makes no OpenAI/cloud request.

The privacy-safe LM summary is written under:

`apps\rah-raven-daily-driver\runtime\state\owned-machine-lm-acceptance.json`

The archive path and archive contents are not copied into the acceptance summary.

## Exit codes

- `0` — all required owned-machine checks passed; eligible for separate manual Stable review.
- `2` — valid but incomplete; the report identifies the next prerequisite. Stable remains blocked.
- `1` — a hard contract/integrity/repair failure occurred. Stable remains blocked.

## Lifecycle boundary

Even when every acceptance check is complete, the summary says only:

`eligibleForStableReview: true`

It always says:

`stablePromotion: BLOCKED`

A human/manual Stable review is still required. No acceptance script, runtime evidence validator, GitHub workflow, or companion artifact may promote Stable or Frozen.
