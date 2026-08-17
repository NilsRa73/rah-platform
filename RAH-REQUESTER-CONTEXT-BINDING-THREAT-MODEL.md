# RAH Requester Context Binding — Research Threat Model

Stage: **Research only**  
Runtime authority delta: **none**  
Stable runtime under protection: **Command Center 1.5 / Node Agent 1.1 / Actions v5**

## 1. Problem

Node Agent 1.1 binds a locally approved mutating action to the actual IPv4 socket source. That prevents a different LAN source from consuming the pair, but source IP is not unique client identity. Multiple processes can share loopback, and proxies/NAT can collapse multiple clients to one apparent source.

The research question is whether one additional ephemeral requester context can reduce accidental or opportunistic cross-client reuse without broadening the action surface.

## 2. Proposed research grammar

If later implemented, the protocol would advance explicitly to `rah-node-actions-v6` and add exactly one fixed security header:

`X-RAH-Requester-Context`

It would be accepted only on:

- the existing `GET /actions` request when it is explicitly a mutating Node-local approval intent; and
- the existing fixed mutating execution routes `POST /launch/rustdesk` and `POST /handoff/rustdesk`.

No new route, action, capability, generic metadata object, generic header name, command channel, process launcher or file API is proposed.

## 3. Context lifecycle

The Command Center would generate a high-entropy context with a cryptographically secure RNG for one mutating approval/execution flow. The raw context would remain only in Command Center memory long enough to request the local approval and submit the selected fixed action.

The Node would validate the fixed format and retain only `SHA-256(context)` inside the active in-memory approval pair. The raw context would not be echoed, logged or persisted by the Node. A reload or new flow would require a new context and a new local approval.

## 4. Pair binding

A proposed mutating pair would be bound to all of:

- exact fixed action;
- current Node process session;
- canonical fixed-action input digest;
- actual requester IPv4 socket source;
- requester-context digest;
- fresh single-use action challenge;
- fresh single-use Node-local approval proof; and
- short expiry.

Context mismatch and requester-source mismatch are independent checks. Neither mismatch should consume a still-valid pair belonging to the correct flow.

## 5. Security value

The context is an **anti-cross-client flow binding**, not a new authentication system. It is useful when another process shares the same source IP but does not know the ephemeral context used by the approved Command Center flow.

It does not replace or weaken any existing requirement: advertised action, capability, ephemeral CC approval, bearer token, Node session, exact policy ID, Node-local human confirmation, requester-source match, challenge or proof.

## 6. Explicit non-claims

This mechanism does **not** claim to protect against an attacker that can read Command Center process memory, observe all transient request values, or otherwise obtain the bearer token, approval proof, challenge and requester context together. It is also not a substitute for transport security.

The requester context is not a password and not durable identity. Calling it a client identity token would overstate the property it provides.

## 7. Persistence boundary

Never persist:

- bearer token;
- action challenge;
- Node-local approval proof;
- raw requester context;
- password;
- RustDesk peer ID; or
- action result.

A context digest may exist only inside the short-lived active pair and must disappear when the pair is consumed, expires or is replaced.

## 8. Compatibility boundary

A fixed-header grammar change must not silently appear inside Actions v5. If implemented, CC and Node Candidate must both require Actions v6 and reject mismatched v5/v6 catalogs fail-closed.

Stable 1.5/1.1 remains untouched during research and any later Candidate work.

## 9. Council review

**Technical:** fits existing fixed `/actions` approval intent and the two fixed execution routes; no endpoint expansion is needed.

**Security:** useful only as an additive flow binding. Source, token, session, policy, human confirmation, challenge and proof stay mandatory.

**Economy:** requires only local CSPRNG and SHA-256; no service, subscription or infrastructure dependency.

**Research:** test same-source/wrong-context, wrong-source/correct-context, replay, expiry and snapshot leakage.

**Critic:** same-source protection is conditional on context secrecy during the short flow. Do not market this as cryptographic device identity.

**Planner:** research evidence → separate implementation-readiness gate → separate CC 1.6 / Node 1.2 Candidate, only if all frozen Stable gates remain green.
