# RAH OS acceptance tests

- `test_raven_agent.py` validates the local Raven HTTP handler and read-only hardware diagnostics.
- `test_profiles.sh` validates all five v0.3 boot profiles, safe fallback behavior, dry-run session activation, Nova VI Python compilation, BIOS/UEFI profile menu contracts, and Ghost restore safety gates.

The GitHub ISO workflow additionally opens the finished ISO, checks both BIOS and UEFI boot payloads, verifies all five profile parameters in the generated menus, inspects the SquashFS runtime payload and verifies SHA-256.
