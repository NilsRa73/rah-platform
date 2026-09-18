# RAH Raven Daily Driver v1.0 — Stable Gate

Daily Driver 1.0 is a Stable local-first sidecar. The release gate proves the application itself without requiring private user data or a live AI model.

## Required release checks

- Python syntax and full unit/smoke suite: PASS
- deterministic synthetic archive/import tests: PASS
- Windows installer + isolated venv + desktop shortcut: PASS
- deterministic runtime gate: `PASS / Stable`
- read-only loopback bridge on `127.0.0.1:18767`: PASS
- OpenAI cloud disabled by default: PASS
- Command Center dependency: Stable 2.4 / generation 9
- Node Agent reference: Stable 1.4
- Chronicle reference: Stable 1.7.1
- authority delta: none
- runtime data root: `C:\RAH\DailyDriver\runtime`

## Optional live integration checks

These are useful user tests, but they do not gate the Stable release:

- load a real LM Studio model and test local Council roles;
- import a user-selected Facebook/archive ZIP;
- import user-selected Sherlock / PhoneInfoga / passive SpiderFoot exports;
- explicitly enable OpenAI cloud with an API key and test one request.

No private archive, identifier, or external-tool export is required in CI.

## One-click Stable path

Run:

`START-HER-RAH-RAVEN-DAILY-DRIVER.cmd`

It performs contract checks, install/repair, unit tests, the deterministic runtime gate, and then starts Daily Driver. The latest report is written to:

`C:\RAH\Logs\RAVEN-DAILY-DRIVER-FINAL-LATEST.json`

## Evidence tools

The older Runtime Evidence exporter/validator and owned-machine review helpers remain available as privacy-safe diagnostics. They are fail-closed and cannot mutate or promote the Stable release.
