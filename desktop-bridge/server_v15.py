from __future__ import annotations

"""Retired RAH Raven Desktop Bridge v1.5 source entrypoint.

The historical v1.5 implementation remains available in Git history for audit,
but the current repository must not expose it as an alternative Flask server.
Use desktop-bridge/raven_bridge.py through start-bridge.bat instead.
"""

APP_VERSION = "1.5.0-retired"
DIRECT_RUN_DISABLED = True
RETIREMENT_REASON = (
    "RAH Raven Desktop Bridge v1.5 is retired. "
    "Use desktop-bridge/raven_bridge.py on 127.0.0.1:18765."
)


def main() -> int:
    print("RAH Raven Desktop Bridge v1.5 - RETIRED LEGACY ENTRYPOINT")
    print(RETIREMENT_REASON)
    print("No Flask listener, capture route, CORS policy or LM proxy was started.")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
