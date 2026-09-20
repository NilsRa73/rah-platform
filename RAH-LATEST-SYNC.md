# RAH Raven Latest Green Main Sync

Use **START-HER-RAH-LATEST.cmd**.

This flow exists for the multi-account / multi-agent workflow where more than one
ChatGPT session may modify the same repository.

It:

1. Resolves `main` to a concrete 40-character Git SHA.
2. Reads GitHub Actions for that exact SHA.
3. Stops if any discovered run is red.
4. Waits for active runs to finish.
5. Re-checks `main`; if it moved, the verification restarts.
6. Downloads the AI Fabric installer from the immutable SHA.
7. Runs `INSTALL-RAH-AI-FABRIC.ps1 -Mode Repair -Ref <sha>`.
8. Runs Raven AI Self-Check with `-NoRepair`.
9. Writes the installed baseline to:
   - `C:\RAH\Status\RAVEN-BASELINE-LATEST.json`
   - `C:\RAH\Status\RAVEN-BASELINE-LATEST.txt`
10. Installs persistent launchers:
   - `C:\RAH\UPDATE-RAH-LATEST.ps1`
   - `C:\RAH\START-HER-LATEST.cmd`

Safety boundaries:

- no arbitrary shell endpoint is enabled;
- no firewall rule is created;
- no API token is printed or scraped;
- no model is downloaded by this sync script;
- a red or unfinished main is not installed;
- the actual repair is pinned to one immutable commit SHA.
