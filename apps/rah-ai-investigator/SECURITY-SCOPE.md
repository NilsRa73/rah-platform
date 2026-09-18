# RAH AI Investigator v1.0 Stable — Security Scope

## Core authority

Investigator Stable is local-first and authority-minimal:

- explicit local file, directory or ZIP input only;
- no network requests in the core;
- no external-tool auto execution;
- no shell, arbitrary process dispatch, credential collection or remote-control authority;
- no source mutation;
- bounded file/member/aggregate sizes;
- ZIP path traversal is rejected.

## External-tool results

The application may review exported results from Sherlock, PhoneInfoga or passive SpiderFoot only when the operator explicitly supplies those files for an authorized/user-owned investigation. Installation and execution of those tools are separate actions outside Investigator.

## Platform isolation

Investigator 1.0 references Command Center 2.4 / generation 9, Node Agent 1.4 and Chronicle 1.7.1 but adds no platform authority. `authority_delta` remains `none`.

## Release evidence

Stable CI requires static no-network/no-process checks, deterministic Python self-test, a deterministic 12-file source bundle, Windows and Kali-compatible checker runs, and a separately built Windows EXE self-test. Personal archives and owned identifiers are not required for release validation.
