# RAH Candidate Acceptance Center

The owned-machine Candidate queue is currently **empty**.

This is deliberate. Products that have already reached Stable or have been superseded are not kept in a fake Candidate queue.

## Current lifecycle status

- **RAH Raven Studio 2.9** — Retired; superseded by Studio 3.0.
- **RAH Raven Studio 3.0** — Stable; release gate passed.
- **RAH Raven Daily Driver 1.0** — Stable; Stable gate passed.
- **RAH AI Investigator 1.0** — Stable; Stable release gate passed.

## Status check

Double-click:

`START-RAH-CANDIDATE-SUITE.bat`

or:

`RAH-CANDIDATE-ACCEPTANCE-CENTER.bat`

The center now reports lifecycle status only. It exposes **no Candidate launcher** while the queue is empty.

CI-only self-test:

`START-RAH-CANDIDATE-SUITE.bat --self-test`

## Historical Studio 2.9 entry point

If an old shortcut calls:

`ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.bat`

it is retained as a compatibility entry point and forwards to the canonical Studio 3.0 Stable finalizer. It cannot promote Studio 2.9.

Current Studio launcher:

`START-HER-RAH-RAVEN-STUDIO.cmd`

## Boundary

The Candidate Center is read-only and network-free. It reads fixed lifecycle manifests, writes no files, accepts no arbitrary path/command, performs no promotion, and launches nothing while there is no current Candidate.

When a future Candidate is intentionally introduced, it should be added explicitly with a fixed manifest, fixed launcher, fail-closed lifecycle checks, and dedicated CI.
