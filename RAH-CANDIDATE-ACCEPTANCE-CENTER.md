# RAH Candidate Acceptance Center

One fixed Windows entry point for the current Raven Candidate that still requires owned-machine acceptance before any separate Stable review.

## Simplest start — one ZIP, one BAT

Use the GitHub Actions artifact named `RAH-Raven-Candidate-Acceptance-Suite-Windows`.

Extract the ZIP and double-click `START-RAH-CANDIDATE-SUITE.bat`.

The suite now launches the only current target directly:

- **RAH Raven Studio 2.9 Candidate**
- launcher: `ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.bat`
- manifest: `RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json`
- expected stage/version: `candidate / 2.9.0`

The starter has no arbitrary path/command input and cannot promote Stable.

For CI verification only, run `START-RAH-CANDIDATE-SUITE.bat --self-test`. This does not install or launch the Candidate.

## Graduated products

- **RAH Raven Daily Driver 1.0** — Stable since 2026-09-18. Use `START-HER-RAH-RAVEN-DAILY-DRIVER.cmd`.
- **RAH AI Investigator 1.0** — Stable. It is no longer launched by the Candidate suite.

Stable products are intentionally excluded so the center cannot force them back through Candidate-stage assumptions.

## Direct center start

Double-click `RAH-CANDIDATE-ACCEPTANCE-CENTER.bat`, or run the fixed Studio target:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1 -Target studio

CI/static verification only:

    powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1 -SelfTest

## Security and lifecycle boundary

The Acceptance Center:

- reads only the fixed Studio Candidate manifest;
- starts only the fixed Studio Candidate acceptance launcher;
- performs no network requests;
- writes no files and changes no Candidate or Stable manifest;
- has no shell-command input field or arbitrary path execution;
- cannot promote Stable, merge a PR, push Git, or change GitHub state;
- refuses to launch Studio if its manifest no longer proves that Stable promotion is blocked.

The suite packaging workflow creates one ZIP plus SHA-256 checksum and verifies the staged suite on Windows. A successful child acceptance means only that Studio evidence may be eligible for a separate manual Stable review; the center itself cannot promote Stable.
