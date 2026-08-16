# RAH Raven Capability & Approved Action Allowlist

Baseline: Raven 2.0.32 · Command Center 1.3.0 Stable · Node Agent 0.9.0 Stable · Actions protocol v4 · policy `rah-capability-allowlist-v1`

Rollback runtime remains intact: Command Center 1.2.0 + Node Agent 0.8.0 + actions protocol v3.

## 1. Execution chain

Every executable Node Agent action must pass the same closed chain:

1. The action ID exists in the fixed catalog.
2. The Node Agent advertises that exact action.
3. The Node Agent advertises the capability required by that action.
4. Command Center has an explicit local approval for that action on that enrolled device.
5. The request carries the current in-memory bearer token for the running Node Agent process.
6. The enrolled Node Agent session still matches the running process.
7. Command Center fetches a fresh `/actions` catalog for that same session.
8. The catalog carries the exact policy ID `rah-capability-allowlist-v1`.
9. The request carries the fresh action-bound one-time challenge returned for that exact action.
10. The Node Agent consumes the challenge once.

Failure at any step means no execution.

## 2. Fixed capabilities

Stable recognizes only:

- `compute`
- `storage`
- `display`
- `remote-desktop`

A capability is descriptive permission scope. It is not itself executable authority.

## 3. Fixed actions and routes

Stable recognizes exactly three executable action IDs:

- `storage-summary.read` → `storage` → `GET /storage`
- `rustdesk.launch` → `remote-desktop` → `POST /launch/rustdesk`
- `rustdesk.connect` → `remote-desktop` → `POST /handoff/rustdesk`

The complete Node Agent route surface remains exactly:

- `/health`
- `/actions`
- `/storage`
- `/launch/rustdesk`
- `/handoff/rustdesk`

`rustdesk.connect` accepts only one typed `peerId` field. The Node Agent owns executable lookup and fixed RustDesk invocation. Command Center cannot supply an executable path, generic command line, server/key URL, password, arbitrary argument list, shell text or alternate endpoint.

## 4. Approved Action Allowlist

Approval is local, per device and per action ID. Approval cannot invent an action, substitute a capability, alter method/path/scope, bypass policy ID or challenge validation, survive a changed Node Agent session without re-enrollment, or enable commands/files/shell/native remote control.

The enrolled registry may persist sanitized action IDs and approval IDs only. It must not persist bearer tokens, challenges, RustDesk target IDs, passwords, executable paths or action results.

## 5. Token and challenge boundary

The bearer token is generated in memory by each Node Agent process and is required on authenticated requests. Stable 0.9 has no network token-renewal endpoint. Rotation remains: restart Node Agent and use the newly displayed console token. Restart also creates a new non-secret session ID and therefore forces re-verification.

`/actions` issues fresh action-bound challenges with a 60-second TTL. Challenges are single-use. Policy ID, approval, bearer token, session and challenge are independent gates.

No token or challenge is written to browser or Node Agent persistent storage.

## 6. Stable runtime and rollback

Current Stable runtime:

- `RAH-COMMAND-CENTER-V1.3.html`
- `rah-command-center-core-v1.3.js`
- `rah-node-agent-v0.9.py`

Immutable rollback runtime retained in parallel:

- `RAH-COMMAND-CENTER-V1.2.html`
- `rah-command-center-core.js`
- `rah-node-agent.py`

The v1.3/v0.9 layer reuses the frozen v1.2/v0.8 implementation for the unchanged action and route authority and adds only versioned protocol/policy enforcement. The device registry key remains `rah.cc.devices.v1`; rollback requires no data migration or secret migration.

## 7. Forbidden runtime authority

The capability/allowlist system must not add shell endpoints, generic command execution, arbitrary process launch, caller-controlled executable paths or generic argument arrays, generic file APIs, generic endpoint dispatch, Raven-native remote-control APIs, password storage, bearer-token storage, challenge storage, RustDesk peer-ID storage or a network token-renewal endpoint.

## 8. Stable and master-sync boundary

`RAH-CAPABILITY-ALLOWLIST-CONTRACT.json` is the canonical machine-readable current Stable contract.

Changing any capability ID, action ID, method, path, scope, policy/token rule, persistence rule or forbidden-power boundary requires an explicit new version and separate Stable gate. A normal Raven master metadata sync must not silently broaden the contract.

The old v1.2/v0.8 files remain rollback references; their existence is not authority for master-sync to downgrade or expand runtime automatically.

## 9. Council review

Technical: v1.3/v0.9 adds explicit policy identity while retaining exact schemas and endpoint shapes.

Security: capability, advertisement, local approval, bearer token, session, policy ID and one-time challenge remain independent gates.

Economy: the layer reuses the frozen implementation and adds no external dependency.

Research: future capabilities remain candidates until separately versioned and gated.

Critic: versioned wrappers deliberately preserve rollback and reduce the risk of in-place Stable mutation.

Planner: treat 1.3/0.9 as frozen Stable after promotion; all future authority changes require a new Candidate and Stable gate.
