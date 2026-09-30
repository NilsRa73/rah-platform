# RAH Raven Agent Effect Pack v1

This folder is the first machine-readable control plane for Raven's active projects.

## What it adds

- `projects.json` — one source of truth for the current top-10 project queue.
- `agents.json` — clear agent roles and safety boundaries.
- `raven_registry.py` — validates the registry, checks declared repo paths, and can probe loopback-only health endpoints.
- `tests/test_registry.py` — basic registry acceptance tests.
- repository-root `START-RAVEN.cmd` — one visible launcher that runs registry checks, verifies/repairs a stale local Bridge `.venv`, then starts the existing Raven Vision local chain. Broken virtual environments are archived as `.venv-broken-<timestamp>` and never deleted automatically.

The pack is intentionally conservative. It does **not** delete files, move projects, install software, publish releases, or promote a candidate to STABLE.

## Run

From the repository root:

```bat
START-RAVEN.cmd
```

Registry only:

```bat
py raven\raven_registry.py
py raven\raven_registry.py --json
py raven\raven_registry.py --probe-local
```

Tests:

```bat
py -m unittest discover -s raven\tests -v
```

## Agent workflow

1. **Raven Supervisor** selects the highest-priority actionable project.
2. **Huginn Scout** inspects current files, versions, services and blockers.
3. **Muninn Memory** records decisions, known-good versions and recovery points.
4. **Brokkr Builder** changes candidate code only.
5. **Heimdall Tester** runs syntax/unit/startup/health checks.
6. **Mimir Analyst** diagnoses failures and compares options.
7. **Skuld Release** prepares candidate/stable metadata and rollback information.
8. **Raven Archivist** may archive superseded copies only after approval.

## Next increment

The next useful increment is to let the Command Center read `projects.json` and display:
- top-10 project status
- stable/candidate labels
- blockers
- last health check
- one **Continue** action that starts a resumable mission for the selected project

Command Center registry integration is now included in the Candidate. The remaining local gate is the machine-specific Desktop Bridge/capture/Doctor chain. The Windows launcher now detects stale virtual environments left by an old Windows account and rebuilds them non-destructively before startup.
