# RAH Raven OS v0.7 Gold Shell candidate

This candidate adds a visual RAH OS shell without changing the stable v0.6 acceptance engine.

## Visual direction
- Near-black base with layered metallic gold accents.
- Permanent left navigation rail.
- RAH / RAVEN OS / GOLD SHELL identity block.
- Large launch deck instead of a wall of equal buttons.
- Live status strip for Raven Core, Local AI, Desktop Bridge, and Node Agent.
- Separate pages for Overview, AI + Raven, Grid + Network, System + Acceptance, and Tools + Files.

## Functional additions
- Five-second optional live status refresh.
- One-click Start Local Core, Command Center, Raven Workspace, AI Self-Check, Core 7 diagnostics, 2-PC Grid, verification, Worker Proof, Safe Repair, and HOVED-PC acceptance.
- Open RAH root, logs, and state directories.
- Copy the current status feed to the clipboard for support/debugging.

## Safety boundary
- The candidate only launches fixed known local files.
- It does not add arbitrary shell input.
- It does not change firewall rules.
- It does not perform background network discovery.
- It does not auto-start the Node Agent.
- The stable v0.6 acceptance files remain unchanged.

## Safe preview
Run `TRY-RAH-OS-v0.7-GOLD.cmd`.

The preview downloads a pinned copy of `RAH-OS-CONTROL-v0.7-GOLD.ps1` into the user's temporary directory and launches it. It does not replace files under `C:\RAH\RavenOS`.

## Promotion plan
After the preview passes on HOVED-PC:
1. Promote the candidate UI into `RAH-OS-CONTROL.ps1`.
2. Keep the v0.6 acceptance engine unchanged.
3. Run the existing Front Door self-test and HOVED-PC acceptance.
4. Only then make Gold Shell the normal double-click RAH OS experience.
