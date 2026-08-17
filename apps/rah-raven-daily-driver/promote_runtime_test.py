import json
from pathlib import Path

from stable_gate import StableGate


APP_DIR = Path(__file__).resolve().parent
RESULT = APP_DIR / "runtime" / "state" / "runtime-gate.json"
STATUS = APP_DIR / "runtime" / "state" / "module_status.json"


def main():
    if not RESULT.exists():
        raise SystemExit("No runtime-gate.json. Run RUNTIME-GATE-RAH-RAVEN.bat first.")

    data = json.loads(RESULT.read_text(encoding="utf-8"))
    if data.get("overall") != "PASS":
        raise SystemExit(
            f"Promotion blocked: runtime gate is {data.get('overall')}. "
            "All required runtime checks must pass."
        )

    gate = StableGate(STATUS)
    for name, item in gate.components().items():
        if item.get("stage") == "Candidate" and not item.get("frozen"):
            gate.transition(name, "Runtime Test", reason="normal")

    print("Promotion complete: eligible Daily Driver components -> Runtime Test")
    print("Stable still requires an explicit final release decision after target-machine verification.")


if __name__ == "__main__":
    main()
