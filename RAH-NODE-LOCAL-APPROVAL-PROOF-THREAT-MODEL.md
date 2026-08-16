# RAH Raven — Node-local approval proof threat model

Stage: **Research only**. This document authorizes no runtime change.

Baseline under analysis: Raven 2.0.32 · Command Center 1.4.0 Stable · Node Agent 0.9.0 Stable · Actions Protocol v4 · policy `rah-capability-allowlist-v1`.

## 1. Security problem

Stable 1.4 correctly requires Command Center-side ephemeral local approval, current process bearer token, Node session match, exact policy ID and a fresh action-bound single-use challenge. The Node Agent itself cannot independently know whether the Command Center approval click occurred.

If a client obtains the current bearer token, it can imitate an allowed origin, call the existing `/actions` route, obtain a fresh challenge and then invoke one of the fixed action routes. The attack remains limited to the existing fixed catalog, but it can bypass the browser-local approval gate.

The goal of the next research Candidate is therefore **not more remote-control capability**. It is an additional Node-side denial gate for the two existing mutating actions.

## 2. Assets and trust boundaries

Protected assets:

- ability to launch the fixed RustDesk executable;
- ability to start the fixed RustDesk handoff to one typed peer ID;
- current Node Agent bearer token;
- action challenges;
- future local approval proofs;
- human intent at the Node Agent host.

Trust boundaries:

- Command Center browser memory is not sufficient proof of Node-local human consent;
- bearer token possession authenticates the process session but does not prove human intent;
- an action challenge proves freshness and action binding but does not prove local intent;
- Node-host keyboard/OS confirmation is the new independent trust boundary under research.

## 3. Non-negotiable authority boundary

Research must preserve exactly:

- capabilities: `compute`, `storage`, `display`, `remote-desktop`;
- actions: `storage-summary.read`, `rustdesk.launch`, `rustdesk.connect`;
- routes: `/health`, `/actions`, `/storage`, `/launch/rustdesk`, `/handoff/rustdesk`.

No shell, generic command/process execution, generic files, caller executable paths, generic argument arrays, generic endpoint dispatch or Raven-native remote-control API may be introduced.

Node-local proof is an **additional requirement**. It never replaces Command Center ephemeral approval, bearer token, session match, policy ID or action challenge.

## 4. Recommended protocol shape

Use the existing authenticated `GET /actions` route as a fixed approval-intent surface. Do not add an endpoint.

For a mutating action, Command Center may send a strict `X-RAH-Approval-Action` header whose value must be exactly `rustdesk.launch` or `rustdesk.connect`.

For `rustdesk.connect`, a dedicated `X-RAH-Approval-Target` may carry only a peer ID that already passes the existing fixed peer-ID validator. This field is not a generic argument channel.

Before displaying any prompt, Node Agent must validate bearer token, origin, action ID, advertised action, capability, Node session context and typed target shape. Invalid intent is rejected before human interaction.

Node Agent permits at most one pending local confirmation. A second request receives a fixed busy/rate-limit response rather than creating another prompt.

After the human confirms locally, Node Agent generates two distinct random values as one pair:

- the existing fresh action challenge;
- a new local approval proof with at least 192 bits of randomness.

The pair is bound in memory to the fixed action ID, current Node session and canonical input digest. Both expire quickly and are single-use. The action request carries the proof in a dedicated `X-RAH-Local-Approval` header in addition to the normal bearer token and action challenge.

The Node Agent validates and consumes the challenge/proof pair atomically. A mismatch in action, input, session, challenge, proof, expiry or replay fails closed.

## 5. Input binding for RustDesk connect

Action-only proof is insufficient for `rustdesk.connect`: a proof approved for peer A must not authorize peer B.

The local confirmation surface must display the validated target peer ID to the human. After confirmation, proof state must retain only a cryptographic digest of the canonical peer ID, not the raw peer ID. At execution time the Node Agent validates the submitted peer ID again, recomputes the digest and compares it to the bound digest before consuming the pair.

The raw peer ID must not be written to files, browser storage, Node Agent persistent storage, logs, manifests or approval state.

## 6. Local confirmation channel

The first implementation Candidate should prefer a dependency-free Node-host confirmation mechanism.

Recommended minimal Candidate: a bounded console-mediated confirmation queue when an interactive local console is available. The request waits for a short fixed interval while the Node host displays the exact action and target. The human confirms on the Node host; the network caller never receives a local confirmation secret before that confirmation occurs.

If no safe local confirmation channel is available, mutating action execution must fail closed. Headless operation is not justification for bypassing Node-local proof.

A later Candidate may study a fixed OS-native confirmation surface, but it must not use caller-controlled executable paths, generic process launch or arbitrary arguments.

## 7. Threats and mitigations

**Leaked bearer token.** Token alone cannot execute mutating actions because Node-local proof is independently required.

**Challenge theft/replay.** Challenge remains short-lived, action-bound and single-use; it is also paired with the separate approval proof.

**Approval-proof theft/replay.** Proof is short-lived, random, single-use and paired with one challenge, action, session and input digest.

**Mix-and-match attack.** Challenge and proof created in different confirmation events cannot be combined because the Node stores them as one pair and consumes them atomically.

**Target substitution.** `rustdesk.connect` proof binds to the digest of the validated peer ID.

**Prompt spam / approval fatigue.** One pending prompt per Node plus cooldown/rate limiting. Invalid actions/capabilities/targets are rejected before a prompt.

**Prompt ambiguity.** Local prompt shows fixed action label and, for connect, the exact target. It must never render attacker-supplied free text.

**Persistence recovery.** Proof, challenge, bearer token and raw peer ID are process-memory only and never logged or persisted.

**Protocol downgrade.** A future v5 Candidate must reject v4 action catalogs when operating in the proof-required mode; Stable 1.4/0.9 remains separate rollback runtime until a later explicit Stable gate.

**Local console unavailable.** Mutating action fails closed; no remote fallback silently bypasses consent.

## 8. Council assessment

Technical agent: the design can reuse `/actions` and the existing fixed action catalog; the new state is a bounded in-memory proof pair rather than a new execution API.

Security agent: the strongest gain is independence from browser-local state. Input-digest binding and atomic pair consumption are mandatory.

Economic agent: console-mediated confirmation is dependency-free and avoids introducing a GUI framework into Node Agent. It costs convenience but keeps the first Candidate small.

Research agent: OS-native confirmation and accessibility can be studied after the protocol invariant is proven.

Critic: bearer-token theft can still cause prompt spam. Rate limiting and one pending confirmation are required; local proof reduces execution risk but does not make token leakage harmless.

Planner: next step is a test-only protocol model. Do not touch Stable runtime. Only after model tests prove fixed routes/actions/capabilities, replay resistance, target binding and fail-closed behavior should a separate Node Agent 1.0 / CC 1.5 Candidate implementation PR be considered.

## 9. Research exit gate

Research may advance to implementation Candidate only if tests prove:

- exact 4/3/5 authority surface unchanged;
- no new route or generic dispatch;
- proof required only as an additional gate for the two existing mutating actions;
- proof and challenge independently random and paired;
- action, session and input digest binding;
- single-use and expiry behavior;
- no raw peer-ID persistence;
- no token/challenge/proof/password persistence;
- one pending confirmation and abuse throttling;
- no runtime file is modified by the research-model PR itself.
