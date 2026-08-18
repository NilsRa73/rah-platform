# RAH Candidate Acceptance Center

One Windows entry point for the three current Raven candidates that still require owned-machine acceptance before any separate Stable review.

## Start

Double-click:

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

The PowerShell center also supports an explicit target:

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

The child acceptance kits retain their own stricter rules and evidence formats. A successful child acceptance means only that its evidence may be eligible for a **separate manual Stable review**. It never means automatic promotion.
