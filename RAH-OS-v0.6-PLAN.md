# RAH OS v0.6 implementation plan

## Release goal

RAH OS v0.6 is the first candidate where Front Door, Raven Core 7, local AI, AnythingLLM approval and Worker Proof converge into one machine-readable acceptance result before a new ISO is promoted.

## Priority order

| Priority | Gate | Dependency | Exit condition |
| --- | --- | --- | --- |
| P0 | Front Door v0.6 | v0.5.1 | Installer/self-test/repair/acceptance launchers validate on Windows CI |
| P0 | Unified acceptance state | Front Door | RAH-OS-ACCEPTANCE.json reports all five areas independently |
| P1 | Raven Core 7 | Core 7 runtime | PASS evidence or verified loopback Raven Core |
| P1 | Local AI | Raven Core | Raven AI Self-Check PASS |
| P1 | AnythingLLM | Raven Core + Project Memory | approval acceptance PASS with read-only system-inventory |
| P1 | Worker Proof | 2-PC Grid evidence | accepted immutable real-hardware Worker Proof PASS |
| P2 | ISO v0.6 candidate | all above | ISO build + BIOS/UEFI inspection + checksum + runtime inspection PASS |
| P2 | Real hardware ISO gate | ISO candidate | reviewed live-boot acceptance PASS |
| P2 | Stable distribution | hardware gate | immutable release identity + durable download location |

## Current batch

This branch implements the first two rows and wires the remaining runtime gates into the same acceptance model.

## ISO rule

Do not relabel the existing validated v0.3 ISO as v0.6. A v0.6 ISO must be rebuilt from v0.6 sources, produce its own checksum and pass both automated ISO inspection and a new real-hardware boot acceptance.
