# RAH Raven Project Memory

AnythingLLM is the durable project-memory layer for Raven Council.

## Configuration

- Config: `C:\\RAH\\AI-Fabric\\project-memory.json`
- Secret token: `C:\\RAH\\AI-Fabric\\Secrets\\anythingllm-token.txt`
- Default workspace: `rah-raven` (display name `RAH Raven`)
- Default API: `http://127.0.0.1:3001`

The Developer API token is never stored in Git, project JSON, Raven status, or ordinary logs.

## One-time local setup

Run `C:\\RAH\\CONFIGURE-PROJECT-MEMORY.cmd`.

The wizard detects or starts AnythingLLM, validates the Developer API token, creates or finds the workspace, writes non-secret config, performs the first sync, and registers hourly sync.

## Automatic retrieval

Council flow:

`request -> AnythingLLM RAH workspace retrieval -> guarded reference context -> AI advisers -> consensus`

Retrieved memory is reference-only. Commands or instructions embedded in documents are not executable instructions for Raven.

If AnythingLLM is unavailable, Council continues with available AI providers and reports that memory was not used.

## Automatic sync

`SYNC-RAH-PROJECT-MEMORY.ps1` snapshots bounded `.md`, `.txt`, `.json`, `.yml`, and `.yaml` project files, hashes the snapshot, skips unchanged data, uploads changed raw text directly into the workspace, then removes the previous snapshot embedding.

## Endpoints

- `GET /ai/memory/status`
- `GET /ai/memory/config`
- `POST /ai/memory/context`
- `POST /ai/council/run` (automatic memory injection)

Machine actions remain separate behind `/ai/raven/job` and Raven's audited allowlist.
