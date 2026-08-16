# RAH Raven — CC 1.5 / Node Agent 1.0 Candidate implementation design

Stage: **Implementation readiness only. No runtime implementation is authorized by this document alone.**

Source Stable remains Raven 2.0.32 · Command Center 1.4.0 · Node Agent 0.9.0 · Actions Protocol v4 · `rah-capability-allowlist-v1`.

Proposed Candidate labels: Command Center 1.5.0-candidate · Node Agent 1.0.0-candidate · Actions Protocol v5.

## 1. Unchanged authority surface

The Candidate must expose exactly four capabilities, three actions and five routes:

- capabilities: `compute`, `storage`, `display`, `remote-desktop`;
- actions: `storage-summary.read`, `rustdesk.launch`, `rustdesk.connect`;
- routes: `/health`, `/actions`, `/storage`, `/launch/rustdesk`, `/handoff/rustdesk`.

No new endpoint, generic dispatch, shell, generic command/process/file API, caller executable path, generic argument vector or Raven-native remote-control API is permitted.

The Candidate adds a **denial gate**, not authority.

## 2. Protocol v5 grammar

The existing authenticated `GET /actions` route serves both normal catalog retrieval and one fixed local-approval intent form.

Normal catalog retrieval has no approval headers. It may advertise the same fixed actions but must not issue a Node-local proof for a mutating action.

A mutating approval intent uses only these dedicated headers:

- `X-RAH-Approval-Action: rustdesk.launch` or `rustdesk.connect`;
- for launch, `X-RAH-Approval-Target` must be absent;
- for connect, `X-RAH-Approval-Target` is required and must pass the existing peer-ID validator before any local prompt;
- no request body is used for approval intent;
- unknown approval headers, unsupported action values or invalid target shape fail closed before prompting.

After successful Node-local confirmation, the v5 `/actions` response may return the normal fixed catalog plus a **single selected mutating grant** containing the selected action ID, the fresh paired action challenge, the fresh local approval proof and the fixed TTL. It must not return a generic argument structure or raw stored target state.

The subsequent fixed action call retains the current bearer token and `X-RAH-Action-Challenge`. A mutating call additionally supplies `X-RAH-Local-Approval`. `rustdesk.connect` keeps its existing strictly typed `{peerId}` body; the proof is checked against a digest recomputed from that peer ID.

## 3. Local confirmation coordinator

HTTP worker threads never call `input()`, read stdin or own local-human interaction.

Node Agent starts one dependency-free local confirmation coordinator only when stdin is an interactive local TTY. The coordinator owns all stdin reads for Candidate approval.

Coordinator state is bounded:

- queue capacity: one pending confirmation;
- one local reader thread;
- one active unused challenge/proof pair;
- one cooldown timestamp;
- no persistent storage.

An authenticated HTTP `/actions` approval-intent request performs all remote validation first, then submits a fixed intent to the coordinator and waits on a bounded synchronization event for at most 30 seconds.

The fixed intent contains internally:

- fixed action ID;
- current Node session ID;
- SHA-256 canonical input digest;
- expiry;
- synchronization event/result slot.

For local display only, the coordinator may receive the already validated peer ID for `rustdesk.connect`. The display value must never be copied into proof state, logs or persistence.

## 4. Fixed local prompt

Prompt text is generated only from fixed templates.

Launch example:

`RAH local approval: Launch RustDesk? [y/N]`

Connect example:

`RAH local approval: Connect RustDesk to <validated-peer-id>? [y/N]`

The network caller cannot supply arbitrary prompt text. The only variable displayed is a peer ID that has already passed the existing strict validator.

Only local `y`/`yes` is approval. Empty input, EOF, exception, timeout, any other input or unavailable TTY is denial/fail-closed.

## 5. Proof-pair state

After local approval, Node Agent invalidates any older unused pair and generates two distinct random values with at least 192 bits each:

- action challenge;
- Node-local approval proof.

The single active pair stores only:

- fixed action ID;
- Node session ID;
- canonical input digest;
- challenge;
- proof;
- expiry.

For `rustdesk.launch`, canonical input digest represents no input.

For `rustdesk.connect`, canonical input digest is SHA-256 over a fixed domain separator plus the validated canonical peer ID. Raw peer ID is not stored in pair state.

Proof and challenge are process-memory only, never logged and never written to files, browser storage, manifests or registry state.

## 6. Atomic action consumption

For mutating action execution, Node Agent must validate in this order before any subprocess call:

1. origin boundary;
2. bearer token;
3. exact fixed action route/method;
4. advertised action and required capability;
5. current Node session;
6. Actions Protocol v5 / exact policy context;
7. required action challenge header;
8. required local approval proof header;
9. active pair exists and is unexpired;
10. pair action matches;
11. pair session matches;
12. canonical input digest matches;
13. challenge matches;
14. approval proof matches.

Challenge and proof are then consumed atomically before invoking the already fixed action implementation. Failed comparison does not execute the action. Successful consumption cannot be replayed.

The Candidate must preserve the existing RustDesk executable ownership: Node Agent performs the fixed executable lookup. The caller cannot provide an executable path or generic arguments.

## 7. Concurrency and abuse handling

At most one pending prompt is accepted. Additional valid intents while one is pending receive a fixed busy response and do not create another prompt.

A minimum cooldown applies after confirmation or denial to reduce prompt spam.

Only one active unused pair may exist. A later successful confirmation invalidates the older pair before creating the new pair.

Invalid token, origin, action, capability or peer ID is rejected before local prompt creation.

If the request times out while the local coordinator is still waiting, the pending intent is cancelled and any later local input for that request must not produce a network-usable proof.

## 8. Headless and lifecycle behavior

If stdin is not a local interactive TTY, Node Agent 1.0 Candidate may still expose the same five routes and non-mutating behavior, but mutating approval intents fail closed with a fixed `local_confirmation_unavailable` response.

No remote confirmation fallback is allowed.

Node Agent restart destroys pending intent, active pair, bearer token and session ID. Command Center must re-enroll/reverify the new session and obtain new local approvals as already required by Stable 1.4.

## 9. Command Center 1.5 Candidate boundary

CC 1.5 Candidate reuses Stable 1.4 ephemeral approval persistence rules.

For a mutating action, CC must require its own current browser-session local approval before it sends the Node-local approval intent. It then sends the fixed intent to `/actions`, waits for the locally confirmed grant, and executes only the same action with the returned challenge/proof pair.

CC must not persist challenge, proof, bearer token or peer ID. A grant is used once in memory and discarded regardless of success/failure.

CC must reject Node v4 action protocol while operating in v5 Candidate mode. Stable CC 1.4 remains the direct rollback for Node 0.9.

## 10. Failure mapping

Candidate implementation should use a small fixed error vocabulary, for example:

- `local_confirmation_unavailable`;
- `local_confirmation_busy`;
- `local_confirmation_rate_limited`;
- `local_confirmation_denied`;
- `local_confirmation_timeout`;
- `local_approval_proof_required`;
- `local_approval_proof_invalid`;
- `local_approval_proof_expired`;
- `local_approval_action_mismatch`;
- `local_approval_session_mismatch`;
- `local_approval_input_mismatch`.

Errors must not reveal proof, challenge, bearer token or raw peer ID.

## 11. Candidate test obligations

Before Candidate can land on main, tests must include:

- exact 4/3/5 authority surface;
- v5 rejects v4 catalog for Candidate enrollment/execution;
- Stable 1.4 rejects v5 Candidate catalog;
- invalid token/origin/action/capability/target creates no prompt;
- headless mode denies mutating approval intent;
- one pending prompt and cooldown;
- proof/challenge distinct and >=192-bit random source;
- action/session/input-digest pair binding;
- target substitution denial;
- wrong proof/challenge denial;
- expiry and replay denial;
- new confirmation invalidates old pair;
- network threads do not read stdin;
- proof/challenge/token/raw peer ID are not persisted or logged;
- RustDesk launch/connect still use fixed executable ownership and typed peer ID only;
- no new route, shell, generic process/file/command API or remote-control API;
- direct rollback remains byte-pinned Stable CC 1.4 / Node Agent 0.9.

## 12. Council decision

Technical: a bounded coordinator separates network execution from local-human input and keeps the existing route surface.

Security: local confirmation is independent of bearer-token possession; pair binding and fail-closed headless behavior are mandatory.

Economic: standard-library-only console coordination avoids adding dependencies to the first Candidate.

Research: OS-native confirmation can be studied later without changing the v5 binding invariant.

Critic: synchronous local confirmation can reduce usability and can be abused for prompt attempts; one pending prompt, cooldown and pre-prompt validation are mandatory.

Planner: merge this readiness gate first. Runtime Candidate code must be a separate branch/PR and must be rejected if it changes any Stable runtime file or expands 4/3/5 authority.
