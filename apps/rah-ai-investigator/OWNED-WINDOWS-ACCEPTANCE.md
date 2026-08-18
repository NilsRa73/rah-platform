# RAH AI Investigator RC2 — Owned Windows Acceptance

This support kit reduces the remaining manual Candidate checks without changing Investigator runtime authority or promoting Stable.

## One-click flow

1. Extract the GitHub Actions artifact `rah-ai-investigator-rc2-candidate`.
2. Double-click `ACCEPT-RC2-OWNED-WINDOWS.bat`.
3. Select one small folder containing data you own or are explicitly authorized to analyze.
4. Select one ZIP containing data you own or are explicitly authorized to analyze.
5. Type `YES` only after confirming both selections are authorized.
6. The script runs the bundled local checker, verifies operation from a path containing spaces, normalizes both inputs locally, checks that source evidence is unchanged and opens the local browser app.
7. Complete the four explicit UI review prompts.
8. For optional Sherlock / PhoneInfoga / SpiderFoot tools, type `NOTINSTALLED` if they are not installed, or `YES` only after separately running and reviewing the owned/public/passive tests described by the Candidate gate.

## Privacy boundary

The acceptance summary stores only booleans and identifier counts. It does **not** store selected paths, identifiers, Case JSON content or external-tool targets. Temporary Case JSON files are kept only while the acceptance script is running and are deleted on exit.

## Lifecycle boundary

A complete run may produce only:

```text
eligibleForStableReview: true
stablePromotion: BLOCKED
stablePromotionAutomated: false
```

This kit cannot modify Stable runtime files or promote Investigator to Stable. A separate Stable-readiness review is still required after successful owned-machine evidence.
