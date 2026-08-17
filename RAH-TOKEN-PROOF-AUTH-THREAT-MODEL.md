# RAH Token-Proof Authentication — Research Threat Model

Stage: research only. Runtime mutation is not authorized by this document.

## Goal

Remove the current-process Node Agent bearer token from LAN traffic without adding a sixth business route or weakening CC 1.6 / Node 1.2 requester-context, requester-source, local-human-confirmation, capability, advertised-action, session, policy, challenge or proof gates.

## Proposed bootstrap

`GET /health` has one fixed challenge-only mode selected by `X-RAH-Auth-Init: 1`. This mode accepts no `Authorization` header, no requester context and no action security fields. It returns only auth protocol, challenge status, non-secret current Node session ID, random nonce and TTL. It never returns normal hostname, platform, capability or action information.

The existing five business paths remain the only paths. OPTIONS remains CORS/preflight behavior and must never allocate a nonce or create action authority.

## Proof

Command Center keeps the fresh Node token locally and computes HMAC-SHA256 with WebCrypto. The proof transcript is fixed-version and binds: Node session, single-use nonce, HTTP method, exact path, SHA-256 of exact body bytes, approval action, approval target, requester context, action challenge and Node-local approval proof.

Only the fixed fields relevant to Raven's existing routes are canonicalized. There is no generic header map, arbitrary query string or caller-defined canonical field.

## Nonce boundary

Nonce state is Node-memory-only, 30 seconds, source-IP-bound and single-use. It is bounded to 8 outstanding nonces per allowed requester source and 64 globally. Expired values are pruned before allocation. Wrong requester source does not consume another source's nonce. A proof attempt from the correct requester source consumes the nonce before HMAC comparison, so failed HMAC attempts cannot reuse it.

## Existing gates remain independent

A valid auth proof means only that the caller demonstrated knowledge of the fresh Node token for one exact HTTP request. It does not approve an action. Mutating actions still need: advertised fixed action, capability, ephemeral CC approval, session/policy match, Node-local human confirmation, actual socket requester-source match, requester-context match, fresh action challenge and fresh Node-local approval proof.

## Attacks addressed

- Passive LAN observation no longer reveals the reusable bearer token.
- Captured HMAC proof cannot be replayed after nonce consumption.
- Changing method, path, handoff body, action intent, target, requester context, action challenge or local approval proof invalidates HMAC verification.
- A v1.6 bearer client cannot silently authenticate to a no-fallback v1.7/Node1.3 candidate.

## Not claimed

This is not transport encryption. An observer may still see non-secret metadata and transient requester context/challenge/proof values. The design does not protect against an attacker that can read Command Center process memory or already knows the current Node token. It does not prevent denial of service by a LAN attacker.

## Implementation hazards that must be gated

The handoff body must be hashed from the exact bytes that are later parsed, without double-reading the HTTP stream. Auth verification must happen before any action challenge or Node-local approval pair is consumed. The `Authorization` header must be rejected with no bearer fallback. CORS preflight must never issue nonces. Challenge-only `/health` mode must never leak normal health payload fields. All nonce collections must remain bounded.
