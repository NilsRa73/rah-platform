# RAH OS v0.8 consolidation candidate

## Goal

v0.8 turns the Windows-side RAH OS Front Door into one coherent Daily Driver candidate instead of another parallel script set.

## P0 fixes in this batch

- Keep RAH OS v0.3 Stable untouched.
- One-click HOVED-PC bootstrap with backup before replacement.
- Fixed candidate allowlist installed to C:\RAH\RavenOS.
- Include the four runtime scripts that v0.6 acceptance expected but did not install:
  - RAVEN-CORE-7.ps1
  - RAVEN-AI-SELF-CHECK.ps1
  - TEST-ANYTHINGLLM-APPROVAL.ps1
  - RAVEN-CORE-7-WORKER-PROOF.ps1
- Black/gold WPF control center.
- One ordered acceptance report with PASS / PENDING / FAIL.
- Node Agent remains explicit; no automatic remote-node startup.
- No USB, disk partition or firewall changes.

## Acceptance order

1. Front Door package contract
2. Raven Core diagnostics
3. Local AI self-check
4. AnythingLLM approval
5. Worker Proof

A missing required script is FAIL. A service or one-time approval that is installed but not ready is PENDING. Full PASS requires all five areas to pass.

## User entry point

Download and double-click:

RAH-OS-v0.8-HOVED-PC-ONE-CLICK.cmd

Expected destination:

C:\RAH\RavenOS

Expected report:

C:\RAH\RavenOS\state\RAH-OS-v0.8-ACCEPTANCE.json

## Not part of this candidate

- no internal-disk OS installation
- no USB flashing
- no automatic Node Agent enablement
- no Stable promotion
