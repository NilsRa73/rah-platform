import json
from pathlib import Path

from stable_gate import StableGate


APP_DIR = Path(__file__).resolve().parent
RESULT = APP_DIR / "runtime" / "state" / "runtime-gate.json"
STATUS = APP_DIR / "runtime" / "state" / "module_status.json"
REQUIRED_RUNTIME_CHECKS = {
    "Python 3",
    "requests",
    "Chronicle persistence",
    "Investigator synthetic",
    "Real Facebook/archive import",
    "LM Studio",
    "Frozen guard",
    "Main PC device node",
}


def validated_runtime_result(data):
    if not isinstance(data, dict):
        raise ValueError("runtime result must be an object")
    if data.get("product") != "RAH Raven Daily Driver" or data.get("version") != "1.0":
        raise ValueError("runtime result product/version mismatch")
    if data.get("overall") != "PASS" or data.get("recommended_stage") != "Runtime Test":
        raise ValueError(f"runtime gate is {data.get('overall')}")
    checks = data.get("checks")
    if not isinstance(checks, list) or not checks:
        raise ValueError("runtime result has no checks")
    required = [x for x in checks if isinstance(x, dict) and x.get("required") is True]
    required_names = {str(x.get("name", "")) for x in required}
    missing = REQUIRED_RUNTIME_CHECKS - required_names
    if missing:
        raise ValueError("runtime result is missing required checks: " + ", ".join(sorted(missing)))
    failed = [str(x.get("name", "unknown")) for x in required if x.get("status") != "PASS"]
    if failed:
        raise ValueError("required runtime checks are not PASS: " + ", ".join(failed))
    return True


def main():
    if not RESULT.exists():
        raise SystemExit("No runtime-gate.json. Run RUNTIME-GATE-RAH-RAVEN.bat first.")

    data = json.loads(RESULT.read_text(encoding="utf-8"))
    try:
        validated_runtime_result(data)
    except ValueError as exc:
        raise SystemExit(f"Promotion blocked: {exc}. All required runtime checks must pass.") from exc

    gate = StableGate(STATUS)
    for name, item in gate.components().items():
        if item.get("stage") == "Candidate" and not item.get("frozen"):
            gate.transition(name, "Runtime Test", reason="normal")

    print("Promotion complete: eligible Daily Driver components -> Runtime Test")
    print("Stable still requires an explicit final release decision after target-machine verification.")


if __name__ == "__main__":
    main()
