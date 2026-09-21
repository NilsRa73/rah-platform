# RAH Raven OS — 2-PC Grid v1

A focused real-hardware proof for **HOVED-PC ↔ Lenovo** using the already-stable RAH Node Agent 1.4 / Command Center 2.4 security contract.

## Run

1. Double-click `START-HER-RAH-2PC-GRID.cmd`.
2. On Lenovo, use **START RAVEN CORE**, then **START LENOVO NODE**.
3. Copy the fresh Node token shown locally on Lenovo.
4. On HOVED-PC, use **TEST 2-PC LINK**, paste the token, then **RUN SYSTEM INVENTORY**.
5. When inventory shows PASS, press **FINAL REAL-HARDWARE ACCEPTANCE**.

The GUI defaults to the Lenovo LAN hostname `DESKTOP-R2HTAGJ` and can fall back to the last known private LAN address when necessary, because Node Agent 1.4 Stable intentionally accepts requester sources only from loopback and RFC1918 private LAN ranges. Tailscale's 100.64/10 range is therefore not used for this proof; extending that allowlist is a separate future security gate.

## What PASS means

A PASS proves that HOVED-PC authenticated to Lenovo using the Node 1.4 single-use nonce + HMAC-SHA256 proof and received a validated result from:

`GET /raven/status -> local 127.0.0.1:18765 -> fixed system-inventory`

The returned JSON is saved under:

`C:\RAH\2PCProof\results\last-inventory.json`

Final real-hardware evidence is written to:

`C:\\RAH\\2PCProof\\results\\REAL-HARDWARE-ACCEPTANCE.json`

Diagnostics and GUI logs are stored under:

`C:\RAH\2PCProof\logs\`

## Safety boundary

- read-only system inventory only
- fixed remote route: `/raven/status`
- fixed remote port: `18766`
- fixed Raven capability: `system-inventory`
- no arbitrary shell
- no caller-controlled remote path
- no caller-controlled remote arguments
- fresh Node token is passed through stdin and is never written to disk
- GUI does not silently create firewall rules
- Node-to-Raven hop remains localhost-only on Lenovo

## Package checklist

**Package/version:** RAH Raven OS 2-PC Grid v1

**Run first:** `START-HER-RAH-2PC-GRID.cmd`

**Optional verification:** `VERIFY-RAH-2PC-GRID.cmd`

**Final acceptance:** `COMPLETE-RAH-2PC-GRID.cmd` (or the GUI button)

**Success:** GUI shows `RAH RAVEN 2-PC INVENTORY · PASS` and a Lenovo inventory JSON exists under `C:\RAH\2PCProof\results\`.

**Do not run:** older generic remote-shell experiments or anything that exposes arbitrary command execution. This proof intentionally uses Node Agent 1.4 Stable's narrow read-only route.
