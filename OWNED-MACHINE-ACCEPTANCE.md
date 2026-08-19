# RAH Raven Daily Driver — Owned-Machine Acceptance Companion

This companion exists only to make the final **manual owned Windows 10/11 acceptance** easier. It does not change the immutable 37-file Daily Driver Candidate runtime package and it cannot promote Stable or Frozen.

## One-click use

1. Install/extract the normal `RAH-Raven-Daily-Driver-v1.0-Candidate-Windows` artifact.
2. Extract the `RAH-Raven-Daily-Driver-Owned-Machine-Acceptance` companion into the **same package root**, preserving folders.
3. Start LM Studio locally, load a model, and enable its OpenAI-compatible server on loopback.
4. Double-click `ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat`.
5. Confirm the verified desktop shortcut actually launches Daily Driver.
6. Select your own Facebook/archive ZIP when prompted.
7. Let the existing Runtime Gate, privacy-safe Evidence exporter and Evidence validator finish.
8. The acceptance runner then starts the local owned-tool review helper. Select, in order:
   - your own/authorized Sherlock CSV export;
   - your own/authorized PhoneInfoga TXT/JSON export;
   - your own/authorized SpiderFoot **passive-mode** JSON/CSV export.
9. For each selected export, review the visible counts and type `YES` only if the source is owned/authorized and the parsed result looks plausible. For SpiderFoot, type `PASSIVE` only if that export really came from a passive-mode test.
10. The final acceptance summary is eligible for a separate Stable review only when every required machine check and every owned-tool review has passed.

You may also pass an explicit owned archive path:

```text
ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat "C:\path\to\your-own-facebook-export.zip"
```

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

The canonical final local acceptance summary is written under:

`apps\rah-raven-daily-driver\runtime\state\owned-machine-acceptance.json`

The archive path and archive contents are not copied into this acceptance summary.

## Lifecycle boundary

Even when every acceptance check is complete, the summary says only:

`eligibleForStableReview: true`

It always says:

`stablePromotion: BLOCKED`

A human/manual Stable review is still required. No acceptance script, runtime evidence validator, GitHub workflow, or companion artifact may promote Stable or Frozen.
