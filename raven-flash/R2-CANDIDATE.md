# RAH OS R2.0 · Pharaoh Desktop Candidate
Dato: 14. november 2026.

This is a **new candidate branch based on the R1.5 draft branch**, not a deployment
and not a merge to `main`. It replaces only the first local browser desktop
and ISO build output name on this isolated branch.

## New implementation
- Four keyboard-switchable themes (F1–F4): Pharaoh Gold, Aurora, Neo Cobalt, Sandstone.
- Desktop app shell with local file preview, Idea Board JSON export, optional
  LM Studio model discovery + chat, manual online AI links, truthful status,
  strict user-evidence gate and diagnostics.
- R2 GUI has clearly labeled boot/login *simulation* when viewed in Windows;
  on real Linux live session the desktop opens directly via `?mode=live`.
- Existing Debian 13 live-build, Openbox/LightDM, NetworkManager and
  local Raven status generator are retained from R1.5.
- New ISO artifact name `RAH-OS-R2.0-Pharaoh-Candidate-amd64.iso`
  avoids overwriting any R1.5 artifacts.

## Acceptance
- [x] New R2 source committed in isolated branch.
- [x] Windows HTML prototype independently exercised: 15 browser GUI checks PASS
  in the downloadable package; no physical Windows batch run claimed.
- [x] New local R2 session URL; R1.5 untouched.
- [ ] GitHub Actions ISO build + SHA-256 + BIOS and UEFI QEMU result.
- [ ] VirtualBox boot, login, Openbox, Chromium GUI test.
- [ ] Existing Ventoy USB/NVMe manual copy and real boot test.
- [ ] Physical HOVED-PC/OMEN graphics, network, sound, persistence checks.
- [ ] Independent LM Studio model-response test.

**Release gate: HOLD.** CI PASS does not prove VirtualBox or real hardware PASS.
No changes to Windows, EFI, BCD, partitions, Ventoy, RAH GOLD or R1.5 stable source.
