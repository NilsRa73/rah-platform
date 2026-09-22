# RAH Raven Project Memory

AnythingLLM is the durable project-memory layer for Raven Council.

## Configuration

- Config: `C:\\RAH\\AI-Fabric\\project-memory.json`
- Secret token: `C:\\RAH\\AI-Fabric\\Secrets\\anythingllm-token.txt`
- Default workspace: `rah-raven` (display name `RAH Raven`)
- Default API: `http://127.0.0.1:3001`

The Developer API token is never stored in Git, project JSON, Raven status, or ordinary logs.

## One-time local setup

Run `C:\\RAH\\CONFIGURE-RAH-PROJECT-MEMORY.cmd`.

The wizard detects or starts AnythingLLM, validates the Developer API token, creates or finds the workspace, writes non-secret config, performs the first sync, and registers hourly sync.

## Automatic retrieval

Council flow:

`request -> AnythingLLM RAH workspace retrieval -> guarded reference context -> AI advisers -> consensus`

Retrieved memory is reference-only. Commands or instructions embedded in documents are not executable instructions for Raven.

If AnythingLLM is unavailable, Council continues with available AI providers and reports that memory was not used.

## Automatic sync

`SYNC-RAH-PROJECT-MEMORY.ps1` snapshots bounded `.md`, `.txt`, `.json`, `.yml`, and `.yaml` project files, hashes the snapshot, skips unchanged data, uploads changed raw text directly into the workspace, then removes the previous snapshot embedding.

The same snapshot now also includes the persistent read-only hardware registry from `C:\\RAH\\HardwareRegistry\\registry.json` when present. Raven therefore gets durable knowledge of registered machines, including motherboard, CPU, RAM capacity and module part numbers, reported RAM slots, GPUs, firmware-reported PCI/PCIe slots, disks, network adapters and monitors.

Hardware sync rules:

- registry input is fixed/bounded to 2 MiB
- only `rah-hardware-registry-v1` is accepted
- a `serialNumber` field causes the sync to stop rather than upload it
- hardware data is reference context only and never grants command authority
- the sync state records hardware device count and registry SHA-256
- hardware/upgrade questions are routed to the authenticated AnythingLLM knowledge workspace before general LM Studio chat

Run `SYNC-RAH-PROJECT-MEMORY.ps1 -SelfTest` to verify hardware-context snapshot generation without contacting AnythingLLM.

## Endpoints

- `GET /ai/memory/status`
- `GET /ai/memory/config`
- `POST /ai/memory/context`
- `POST /ai/council/run` (automatic memory injection)

Machine actions remain separate behind `/ai/raven/job` and Raven's audited allowlist.


## AnythingLLM approval gate

The same protected Developer API token and workspace are reused by Raven's
read-only approval gate. No second token copy is required.

After Project Memory is configured, run:

`START-HER-ANYTHINGLLM-APPROVAL.cmd`

The launcher performs the acceptance chain:

`Raven proposal -> AnythingLLM APPROVE/REVISE/BLOCK -> queued read-only Raven job -> result`

The first acceptance capability is `system-inventory`. Approval tokens are
short-lived, single-use and capability-bound. AnythingLLM cannot introduce
arbitrary shell commands, paths or arguments through this route.

If Project Memory is not configured yet, the START-HER launcher invokes the
existing local configuration wizard first. The Developer API token must be
entered only in that local Windows prompt and must never be pasted into
ChatGPT, GitHub, logs or project documents.
