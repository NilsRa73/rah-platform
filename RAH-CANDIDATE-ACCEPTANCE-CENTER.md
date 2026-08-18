# RAH Candidate Acceptance Center

One Windows entry point for the three current Raven candidates that still require owned-machine acceptance before any separate Stable review.

## Simplest start — one ZIP, one BAT

Use the GitHub Actions artifact named:

`RAH-Raven-Candidate-Acceptance-Suite-Windows`

Extract the ZIP and double-click:

`START-RAH-CANDIDATE-SUITE.bat`

The suite starter uses only two fixed entry points:

1. `INSTALL-RAH-RAVEN.bat` — only when the Daily Driver isolated Python environment or verified desktop shortcut is missing. It is run with `RAH_RAVEN_INSTALL_NO_START=1`, so installation can finish without automatically starting Daily Driver.
2. `RAH-CANDIDATE-ACCEPTANCE-CENTER.bat` — opens the fail-closed three-target acceptance menu.

The suite starter has no arbitrary path/command input and cannot promote Stable.

For CI verification only:

`START-RAH-CANDIDATE-SUITE.bat --self-test`

This does not install or launch a Candidate. It runs only the fixed Acceptance Center manifest/lifecycle self-test.

## Direct center start

When already working from a complete current `rah-platform` tree, double-click:

`RAH-CANDIDATE-ACCEPTANCE-CENTER.bat`

The center validates the current candidate manifest before it offers or starts a child acceptance kit. It fails closed if the expected version, candidate stage, launcher path, or Stable-promotion boundary has drifted.

## Current targets

1. **RAH Raven Studio 2.9 Candidate**
   - launcher: `ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.bat`
   - expected manifest: `RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json`
   - expected stage/version: `candidate / 2.9.0`

2. **RAH Raven Daily Driver 1.0 Candidate**
   - launcher: `ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat`
   - expected manifest: `RAH-RAVEN-DAILY-DRIVER-VERSION.json`
   - expected stage/version: `candidate / 1.0.0`

3. **RAH AI Investigator 1.0 RC2 Candidate**
   - launcher: `apps/rah-ai-investigator/ACCEPT-RC2-OWNED-WINDOWS.bat`
   - expected manifest: `apps/rah-ai-investigator/RAH-INVESTIGATOR-VERSION.json`
   - expected stage/version: `candidate / 1.0-RC2`

## Direct target mode

The PowerShell center also supports an explicit fixed target:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1 -Target studio
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1 -Target daily-driver
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1 -Target investigator
```

For CI/static verification only:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\RAH-CANDIDATE-ACCEPTANCE-CENTER.ps1 -SelfTest
```

## Security and lifecycle boundary

The Acceptance Center itself:

- reads only the three fixed candidate manifests;
- starts only the three fixed local `.bat` launchers above;
- performs no network requests;
- writes no files and changes no candidate or Stable manifest;
- has no shell-command input field or arbitrary path execution;
- cannot promote Stable, merge a PR, push Git, or change GitHub state;
- refuses to launch a target if its manifest no longer proves that Stable promotion is blocked.

The suite packaging workflow copies only tracked repository files into a temporary staging directory, verifies the staged suite on `windows-latest`, creates one ZIP plus SHA-256 checksum, and uploads them as a GitHub Actions artifact. The ZIP is a delivery artifact only; it is not committed as a binary source of truth.

The child acceptance kits retain their own stricter rules and evidence formats. A successful child acceptance means only that its evidence may be eligible for a **separate manual Stable review**. It never means automatic promotion.
