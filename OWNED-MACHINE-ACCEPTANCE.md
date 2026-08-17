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
8. Type `YES` only for representative owned Sherlock, PhoneInfoga and SpiderFoot-passive imports you have actually reviewed in the Daily Driver UI.

You may also pass an explicit owned archive path:

```text
ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat "C:\path\to\your-own-facebook-export.zip"
```

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

The final local acceptance summary is written under:

`apps\rah-raven-daily-driver\runtime\state\owned-machine-acceptance.json`

The archive path and archive contents are not copied into this acceptance summary.

## Lifecycle boundary

Even when every acceptance check is complete, the summary says only:

`eligibleForStableReview: true`

It always says:

`stablePromotion: BLOCKED`

A human/manual Stable review is still required. No acceptance script, runtime evidence validator, GitHub workflow, or companion artifact may promote Stable or Frozen.
