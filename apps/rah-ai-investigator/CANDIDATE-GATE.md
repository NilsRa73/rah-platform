# RAH AI Investigator v1.0 RC1 — Candidate Gate

## Passed in build environment

- HTML/JavaScript syntax check: PASS
- local-first browser architecture retained
- self-recovery job schema enforced
- agent target caps retained
- offensive authentication/exploit workflows excluded
- ZIP archive extraction helper included
- Windows and Kali free-tool installers included
- Case export/import and tool-result import included

## Required before Stable

1. Run on a Windows 11 machine.
2. Import a small extracted archive folder.
3. Add identity seeds and aliases.
4. Export/import a Case JSON.
5. Export an Agent Job.
6. Run `CHECK-RAH-INVESTIGATOR.ps1`.
7. With optional tools installed, execute one owned username test and one owned phone-number test.
8. Import Sherlock/PhoneInfoga/SpiderFoot result files.
9. Confirm Account Matrix, Identity Clusters and Graph render without errors.
10. Re-run from a folder path containing spaces.

Stable status must not be declared until these runtime checks pass.
