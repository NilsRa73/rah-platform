# RAH OS v0.9 ISO prototype — 14 October 2026

This is an **isolated buildability candidate**, not a full v0.9 feature release or Stable promotion. It retains the v0.4 Debian 13 Linux boot source, five profiles, Raven local service, KDE black/gold desktop and v0.3 stable core. The v0.8/v0.9 **Windows integrations are not yet ported to Linux**.

CI validates scripts, the read-only Windows USB-prep contract, Debian live image build, BIOS and UEFI payloads, SquashFS, SHA-256 and uploads a temporary ISO artifact. It does not publish or replace a GitHub release, change HOVED-PC, flash USB or alter existing stable services.

**Stable Gate: OPEN.** Real v0.9 Live USB tests on OMEN and Lenovo, graphics, wireless, audio, Bluetooth, real model inference and authenticated multi-PC worker jobs are still PENDING. Use Live mode only and collect RAH Live Acceptance JSON. Do not automatically install or promote.

## Prototype R2 genuine Linux-side change

Added an installed **RAH Node Readiness** desktop shortcut and `rah-node-readiness` utility. It tests local Raven / LM Studio / Ollama / AnythingLLM listening status, attempts a limited Raven health JSON read, and creates a privacy-safe local JSON+HTML dashboard. It does not send jobs or pretend TCP probes are real inference.

Release automation only publishes an **immutable SHA-tagged prerelease** when the Linux ISO build and checksum checks succeed. The Windows download CMD assembles three parts and verifies the full ISO checksum. No v0.4 assets or stable branches are modified. Physical boot still pending.
