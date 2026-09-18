# RAH AI Investigator v1.0 Stable

RAH AI Investigator is a local-first tool for personal account recovery and authorized personal OSINT.

The Stable core reads only paths explicitly selected by the operator. It does **not** perform network requests, auto-run external OSINT tools, guess credentials, or modify the selected source archive.

## Canonical one-click Windows path

From the repository or Stable bundle, run:

`START-HER-RAH-AI-INVESTIGATOR.cmd`

The finalizer installs the transparent runtime under:

`C:\RAH\Investigator`

and writes its latest machine-readable result to:

`C:\RAH\Logs\RAH-AI-INVESTIGATOR-FINAL-LATEST.json`

## Stable core

- `RAH-AI-INVESTIGATOR.html` — local browser review UI
- `rah_investigator.py` — deterministic local archive/file/directory normalizer
- `IMPORT-ARCHIVE-TO-RAH-INVESTIGATOR-v1.0.ps1` — explicit local import helper
- Windows and Kali-compatible local checkers
- ZIP path-traversal protection and bounded archive processing
- source files are never modified or deleted

## Optional external-tool handoff

Sherlock, PhoneInfoga and passive SpiderFoot outputs may be imported when they come from an authorized/user-owned investigation. Investigator does not install or execute those tools automatically.

## Platform references

Stable 1.0 is authority-neutral relative to the RAH platform and references Command Center 2.4 / generation 9, Node Agent 1.4 and Chronicle 1.7.1. It does not modify those canonical runtimes.

## Delivery

CI builds a deterministic 12-file source-transparent Stable ZIP and a separate Windows one-file EXE from the same Python source. Both are self-tested. The EXE is a delivery artifact; reviewed source remains canonical.

Historical RC2 acceptance/freeze files remain in the repository for provenance only.
