# RAH Raven Capability & Approved Action Allowlist

Baseline: Raven 2.0.32 · Command Center 1.4.0 Stable · Node Agent 0.9.0 Stable · Actions protocol v4 · policy `rah-capability-allowlist-v1`

Direct rollback remains intact: Command Center 1.3.0 Stable + Node Agent 0.9.0 Stable.

## 1. Execution chain

Every executable Node Agent action must pass the same closed chain:

1. The action ID exists in the fixed catalog.
2. The Node Agent advertises that exact action.
3. The Node Agent advertises the capability required by that action.
4. Command Center has an explicit ephemeral local approval for that action on that enrolled device in the current browser session.
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

## 4. Ephemeral Approved Action Allowlist

Approval remains local, per device and per action ID, but in Stable 1.4 it is an execution grant that exists only in the active Command Center browser session.

An approval cannot invent an action, substitute a capability, alter method/path/scope, bypass policy ID or challenge validation, survive a reload/new tab without explicit re-approval, survive a changed Node Agent session without re-enrollment, or enable commands/files/shell/native remote control.

`approvedActions` is forbidden persistent metadata. On startup, Command Center normalizes any existing registry and immediately writes it back through the persistence redactor before normal UI interaction. Old, stale or injected approval IDs are therefore both ignored for execution and scrubbed from browser storage. Normal saves also strip approvals.

The registry may persist only non-secret enrollment metadata: private node IP, non-secret agent session ID, sanitized capability IDs, sanitized advertised action IDs and non-secret device metadata.

## 5. Token and challenge boundary

The bearer token is generated in memory by each Node Agent process and is required on authenticated requests. Stable Node Agent 0.9 has no network token-renewal endpoint. Rotation remains: restart Node Agent and use the newly displayed console token. Restart also creates a new non-secret session ID and therefore forces re-verification.

`/actions` issues fresh action-bound challenges with a 60-second TTL. Challenges are single-use. Policy ID, ephemeral local approval, bearer token, session and challenge are independent gates.

No token or challenge is written to browser or Node Agent persistent storage.

## 6. Stable runtime and rollback

Current Stable runtime:

- `RAH-COMMAND-CENTER-V1.4.html`
- `rah-command-center-core-v1.4.js`
- `rah-node-agent-v0.9.py`

Direct rollback runtime retained in parallel:

- `RAH-COMMAND-CENTER-V1.3.html`
- `rah-command-center-core-v1.3.js`
- `rah-node-agent-v0.9.py`

The v1.4 layer reuses the Stable 1.3 policy-bound action model and only reduces persistence authority. Node Agent 0.9 is byte-identical across promotion and rollback. The device registry key remains `rah.cc.devices.v1`; no data or secret migration is required. Stable 1.4 startup scrub removes legacy persisted approvals before normal operation, preventing a normal rollback from reviving stale grants.

The older 1.2/0.8 runtime remains historical rollback evidence but is no longer the direct Stable rollback target.

## 7. Forbidden runtime authority

The capability/allowlist system must not add shell endpoints, generic command execution, arbitrary process launch, caller-controlled executable paths or generic argument arrays, generic file APIs, generic endpoint dispatch, Raven-native remote-control APIs, password storage, bearer-token storage, challenge storage, RustDesk peer-ID storage, persistent approved-action IDs or a network token-renewal endpoint.

## 8. Stable and master-sync boundary

`RAH-CAPABILITY-ALLOWLIST-CONTRACT.json` is the canonical machine-readable current Stable contract.

Changing any capability ID, action ID, method, path, scope, policy/token rule, approval-persistence rule or forbidden-power boundary requires an explicit new version and separate Stable gate. A normal Raven master metadata sync must not silently broaden the contract or make ephemeral approvals persistent again.

Stable runtime files remain versioned. Master-sync may describe the current Stable release but is not authority to mutate its execution surface.

## 9. Council review

Technical: 1.4 reuses the 1.3 policy core and adds a small persistence boundary rather than duplicating the execution stack.

Security: capability, advertisement, ephemeral local approval, bearer token, session, policy ID and one-time challenge remain independent gates. Startup scrub additionally removes stale browser-persisted grants.

Economy: Node Agent is unchanged and no external dependency or migration is introduced.

Research: Node-verifiable proof of local approval remains a separate future research candidate; it is not silently added to Stable 1.4.

Critic: local browser approval is still enforced on the Command Center side, so a future design may strengthen Node-side proof without expanding the fixed action surface.

Planner: freeze 1.4/0.9 after the Stable gate. Any future authority or approval-proof change starts as a separate Candidate and must retain the exact 4-capability, 3-action and 5-route boundary unless an explicit future policy version separately authorizes otherwise.
