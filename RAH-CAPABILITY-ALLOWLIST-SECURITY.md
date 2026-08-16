# RAH Raven Capability & Approved Action Allowlist

Baseline: Raven 2.0.32 · Command Center 1.2.0 Stable · Node Agent 0.8.0

## 1. Execution chain

Every executable Node Agent action must pass the same closed chain:

1. The action ID exists in the fixed catalog.
2. The Node Agent advertises that exact action.
3. The Node Agent advertises the capability required by that action.
4. Command Center has an explicit local approval for that action on that enrolled device.
5. The request carries the current in-memory bearer token for the running Node Agent process.
6. Command Center fetches a fresh `/actions` catalog for the same enrolled agent session.
7. The request carries the fresh action-bound one-time challenge returned for that exact action.
8. The Node Agent consumes the challenge once.

Failure at any step means no execution.

## 2. Fixed capabilities

The Stable baseline recognizes only:

- `compute`
- `storage`
- `display`
- `remote-desktop`

A capability is descriptive permission scope. It is not itself executable authority.

## 3. Fixed actions

The Stable baseline recognizes exactly three executable action IDs:

- `storage-summary.read` → `storage` → `GET /storage`
- `rustdesk.launch` → `remote-desktop` → `POST /launch/rustdesk`
- `rustdesk.connect` → `remote-desktop` → `POST /handoff/rustdesk`

`rustdesk.connect` accepts only one typed `peerId` field. The Node Agent owns the executable lookup and the fixed RustDesk invocation. Command Center cannot supply an executable path, generic command line, server/key URL, password, arbitrary argument list, shell text or alternate endpoint.

## 4. Approved Action Allowlist

Approval is local, per device and per action ID.

Approval cannot:

- invent an action the Node Agent did not advertise;
- substitute a different capability;
- alter method, path or scope;
- survive a changed Node Agent session without re-enrollment;
- enable commands, files, shell or native remote control.

The enrolled registry may persist sanitized action IDs and approval IDs only. It must not persist bearer tokens, challenges, RustDesk target IDs, passwords, executable paths or action results.

## 5. Token boundary

The bearer token is generated in memory by the Node Agent process and is required on authenticated Node Agent requests.

Stable v1.2 has no network token-renewal endpoint. Renewal/rotation is intentionally outside the action API: restart the Node Agent and use the newly displayed console token. The new process also creates a new non-secret session ID, forcing Command Center re-verification before an approved action can execute.

No token is written to browser storage or Node Agent persistent storage.

## 6. Challenge boundary

`/actions` issues fresh action-bound challenges with a 60-second TTL. Challenges are single-use. Command Center discards challenges after use and does not persist them.

A challenge is not an approval and is not a bearer token. All three conditions remain independently required.

## 7. Forbidden runtime authority

The capability/allowlist system must not add:

- shell endpoints;
- generic command execution;
- arbitrary process launch;
- caller-controlled executable paths;
- caller-controlled generic argument arrays;
- generic file APIs;
- generic endpoint dispatch;
- Raven-native remote-control APIs;
- password storage;
- RustDesk peer-ID storage.

## 8. Stable and master-sync boundary

`RAH-CAPABILITY-ALLOWLIST-CONTRACT.json` is the canonical machine-readable guard for the current Stable baseline.

Changing a capability ID, action ID, method, path, scope, token rule, persistence rule or forbidden-power boundary requires an explicit new version and a separate Stable gate. A normal Raven master metadata sync must not silently broaden this contract.

The guard may be strengthened without adding runtime authority. Stable runtime files remain frozen unless a separately reviewed version explicitly promotes replacement runtime files.

## 9. Council review

Technical: exact schemas and endpoint shapes reduce accidental drift.

Security: independent capability, advertisement, approval, token, session and challenge checks provide defense in depth.

Economy: the policy is small, dependency-free and cheap to validate in CI.

Research: future capabilities can be studied without being added to the Stable catalog.

Critic: duplicated catalogs in Command Center and Node Agent remain a drift risk; the CI contract guard is the first mitigation, not permission to expand runtime power.

Planner: keep v1 fixed, enforce it in CI, then version any future capability/action change as a separate candidate before Stable promotion.
