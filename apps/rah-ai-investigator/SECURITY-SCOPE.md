# RAH AI Investigator — Security Scope

## Allowed profile

Personal account recovery and analysis of data the operator owns or is authorized to investigate.

Agent jobs are scoped to `self-recovery` and capped at 25 usernames, 10 phone numbers and 25 passive OSINT targets.

## Automated recovery tools

- Sherlock: public username discovery.
- PhoneInfoga: own phone-number public-footprint/metadata workflow; RAH injects no paid API keys.
- SpiderFoot: passive use-case only.

## Deliberately excluded

Password guessing, credential stuffing, phishing, Evilginx, session/token capture, authentication bypass, 2FA bypass, exploit scanning, Nuclei, offensive Recon-ng profiles, CloudFox, BloodHound and active infrastructure scanning are outside the recovery agent.

Those capabilities belong in a separately authorized security lab, not account recovery.

## Data handling

The HTML app processes files selected locally in the browser. Agent results are written locally. Case exports and agent-job files remain local unless the operator deliberately moves them.
