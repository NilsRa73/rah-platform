# RAH AI Investigator v1.0 RC2 — Candidate Gate

## Automated Candidate gate

The RC2 Candidate may merge only when GitHub CI proves all of the following against the reviewed source and the package generated from it in the same workflow run:

- the source manifest remains `stage: candidate`, `authority_delta: none`, with Stable release gate false;
- platform references match Raven 2.0.32, canonical Command Center 2.3.0 package generation 8 and Node Agent 1.3.0;
- the Candidate bundle is generated from exactly the expected transparent source/documentation set;
- the bundle is built twice independently and both ZIP byte streams are identical;
- the generated SHA-256 equals the exact tested bundle bytes;
- the ZIP is CRC-clean and contains no absolute or `..` path;
- extraction works from a path containing spaces;
- HTML/JavaScript static syntax check passes;
- HTML core contains no network-fetch/WebSocket/XHR/CDN dependency;
- Python standard-library helper compiles and its deterministic local self-test passes;
- malicious ZIP path traversal is rejected by the Python self-test;
- Windows PowerShell checker parses and passes on `windows-latest` using the generated bundle;
- Linux/Kali-compatible checker parses and passes on `ubuntu-latest` using the generated bundle;
- checker scripts contain no download/install primitives;
- the generated ZIP and SHA-256 are delivered only as a GitHub Actions Candidate artifact, not treated as canonical repository source;
- no Command Center, Node Agent, capability/action/route or Stable runtime changes are introduced.

## Required before any later Stable promotion

1. Run the merged Candidate on an owned Windows 11 machine.
2. Import a small user-owned extracted archive folder and a user-owned ZIP.
3. Add identity seeds and aliases.
4. Export and re-import Case JSON.
5. Export identifiers CSV and confirm expected rows.
6. Export one authorized fixed Agent Job JSON and verify `autoExecute:false`.
7. If optional external tools are installed separately, run one owned username test, one owned phone-number test and one SpiderFoot passive test outside the browser app.
8. Review those tool results manually; RC2 does not automatically execute or ingest arbitrary tool commands.
9. Confirm Account Matrix, timeline and relationship graph render correctly with representative owned data.
10. Re-run on Windows from a folder path containing spaces.

Stable status must not be declared until these manual runtime checks are actually evidenced. Automated CI alone authorizes Candidate merge, not Stable promotion.
