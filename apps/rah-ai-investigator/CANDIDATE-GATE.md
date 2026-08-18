# RAH AI Investigator v1.0 RC2 — Candidate Gate

## Automated Candidate gate

The RC2 Candidate may merge only when GitHub CI proves all of the following against the reviewed source and the package generated from it in the same workflow run:

- the source manifest remains `stage: candidate`, `authority_delta: none`, with Stable release gate false;
- platform references match Raven 2.0.32, canonical Command Center 2.3.0 package generation 8 and Node Agent 1.3.0;
- the Candidate bundle contains exactly 13 reviewed files: the ten original source/documentation files plus the owned-Windows acceptance PowerShell, launcher and documentation;
- the bundle is built twice independently and both ZIP byte streams are identical;
- the generated SHA-256 equals the exact tested bundle bytes;
- the ZIP is CRC-clean and contains no absolute or `..` path;
- extraction works from a path containing spaces;
- HTML/JavaScript static syntax check passes;
- HTML core contains no network-fetch/WebSocket/XHR/CDN dependency;
- Python standard-library helper compiles and its deterministic local self-test passes;
- malicious ZIP path traversal is rejected by the Python self-test;
- Windows PowerShell checker parses and passes on `windows-latest` using the generated bundle;
- the bundled owned-Windows acceptance runner parses and completes its deterministic `-SelfTest` on `windows-latest`;
- Linux/Kali-compatible checker parses and passes on `ubuntu-latest` using the generated bundle;
- checker/acceptance scripts contain no download/install primitives;
- the acceptance runner cannot promote Stable and persists no selected paths, identifiers, Case content or external-tool targets in its summary;
- the generated ZIP and SHA-256 are delivered only as a GitHub Actions Candidate artifact, not treated as canonical repository source;
- no Command Center, Node Agent, capability/action/route or Stable runtime changes are introduced.

## Required before any later Stable promotion

The bundled `ACCEPT-RC2-OWNED-WINDOWS.bat` guides these checks and can only mark the Candidate eligible for a separate Stable-readiness review.

1. Run the merged Candidate on an owned Windows 11 machine.
2. Normalize a small user-owned extracted archive folder and a user-owned ZIP; confirm the source inputs remain unchanged.
3. Import the temporary Case JSON results and review plausible owned identifiers.
4. Add identity seeds/aliases and verify Account Matrix, timeline and relationship graph.
5. Export and re-import Case JSON.
6. Export identifiers CSV and confirm expected rows.
7. Export one authorized fixed Agent Job JSON and verify `autoExecute:false`.
8. If optional external tools are installed separately, run and manually review one owned username test, one owned phone-number test and one SpiderFoot passive test outside the browser app.
9. Verify the package/checker operates from a Windows folder path containing spaces.

Stable status must not be declared until these owned-machine checks are actually evidenced. Automated CI and the acceptance helper authorize at most `eligibleForStableReview: true`; neither can promote Stable.
