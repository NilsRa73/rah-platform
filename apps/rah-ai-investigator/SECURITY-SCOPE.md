# RAH AI Investigator v1.0 RC2 — Security Scope

## Allowed profile

Personal account recovery and analysis of data the operator owns or is explicitly authorized to investigate.

RC2 core is local-first and authority-minimal:

- the browser reads only files the user explicitly selects;
- the Python normalizer reads only an explicit local file, directory or ZIP;
- source evidence is never deleted or modified;
- browser Case state is memory-only until explicit export;
- no credential/password/session-token collection is required;
- no core network request is required;
- no external OSINT tool is automatically executed.

## Fixed optional Agent Job exports

RC2 can export one reviewable JSON job at a time after the operator checks the authorization confirmation box. The only job profiles are:

- `sherlock-public-username` — public username discovery;
- `phoneinfoga-own-number` — own-number public-footprint/metadata workflow;
- `spiderfoot-passive` — passive mode only.

The job file is a local instruction artifact with `autoExecute:false`. Installing or running any optional external tool is a separate explicit operator action outside the RC2 browser core.

## Deliberately excluded

Password guessing, credential stuffing, phishing, Evilginx, session/token capture, authentication bypass, 2FA bypass, exploit scanning, Nuclei, offensive Recon-ng profiles, CloudFox, BloodHound, active infrastructure scanning, hidden background collection, generic command execution and arbitrary executable/argument dispatch are outside Investigator RC2.

Those capabilities are not account-recovery authority and are not added by this Candidate.

## Archive safety

The Python normalizer:

- never extracts ZIP members to arbitrary filesystem paths;
- reads supported archive members directly;
- rejects absolute or `..` traversal paths;
- enforces member-count, per-file and total-text safety limits;
- accepts only supported text-like evidence types;
- runs without third-party Python dependencies.

## RAH platform isolation

Investigator RC2 does not modify RAH Command Center, Node Agent, Node capabilities, fixed actions, business routes, action protocols, authentication protocol or policy. The canonical CC2.1/Node1.3 authority surface remains unchanged.
