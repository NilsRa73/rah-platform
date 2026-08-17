import argparse
import json
import os
import socket
import sys
import tempfile
import time
from pathlib import Path

from chronicle import Chronicle
from devices import DeviceRegistry
from investigator import Investigator
from raven_agents import build_agents
from stable_gate import StableGate


APP_DIR = Path(__file__).resolve().parent


def check_port(host, port, timeout=0.6):
    try:
        with socket.create_connection((host, int(port)), timeout=timeout):
            return True
    except OSError:
        return False


def result(name, status, detail="", required=True):
    return {
        "name": name,
        "status": status,
        "detail": detail,
        "required": required,
    }


def load_config():
    with (APP_DIR / "config.json").open("r", encoding="utf-8") as f:
        return json.load(f)


def run_checks(facebook_path=None):
    checks = []
    config = load_config()

    checks.append(result("Python 3", "PASS", sys.version.split()[0]))

    try:
        import requests  # noqa: F401
        checks.append(result("requests", "PASS", "installed"))
    except Exception as exc:
        checks.append(result("requests", "FAIL", str(exc)))

    for folder in ("runtime/data", "runtime/logs", "runtime/reports", "runtime/devices", "runtime/imports", "runtime/exports", "runtime/state"):
        path = APP_DIR / folder
        path.mkdir(parents=True, exist_ok=True)
        checks.append(result(f"folder:{folder}", "PASS" if path.exists() else "FAIL"))

    bridge_host = config.get("bridge", {}).get("host", "127.0.0.1")
    bridge_port = int(config.get("bridge", {}).get("port", 18767))
    bridge_online = check_port(bridge_host, bridge_port)
    checks.append(
        result(
            "Daily Driver Bridge",
            "PASS" if bridge_online else "PENDING",
            f"{bridge_host}:{bridge_port} {'reachable' if bridge_online else 'not running yet'}",
            required=False,
        )
    )

    try:
        with tempfile.TemporaryDirectory() as tmp:
            db = Path(tmp) / "chronicle.db"
            c = Chronicle(db)
            c.decision("Runtime gate persistence test", "before reopen", module="Runtime Gate")
            c.upsert_account("runtime-gate@example.com", "email", "Example", 0.8, ["synthetic"])
            del c
            c2 = Chronicle(db)
            decision_ok = bool(c2.search("Runtime gate persistence test"))
            account_ok = bool(c2.accounts(["Pending"]))
            checks.append(
                result(
                    "Chronicle persistence",
                    "PASS" if decision_ok and account_ok else "FAIL",
                    f"decision={decision_ok}, account={account_ok}",
                )
            )
    except Exception as exc:
        checks.append(result("Chronicle persistence", "FAIL", str(exc)))

    try:
        with tempfile.TemporaryDirectory() as tmp:
            c = Chronicle(Path(tmp) / "chronicle.db")
            inv = Investigator(c)
            sample = (
                "Contact runtime.user73@yahoo.com; username: raven_runtime73; "
                "profile https://github.com/raven_runtime73; +47 900 00 000"
            )
            data = inv.analyze_text(sample, source="runtime-gate")
            kinds = {x["kind"] for x in data["entities"]}
            ok = {"email", "username", "account"} <= kinds
            checks.append(
                result(
                    "Investigator synthetic",
                    "PASS" if ok else "FAIL",
                    f"entities={len(data['entities'])}, relations={len(data['relations'])}",
                )
            )
    except Exception as exc:
        checks.append(result("Investigator synthetic", "FAIL", str(exc)))

    if facebook_path:
        try:
            path = Path(facebook_path)
            if not path.exists():
                raise FileNotFoundError(path)
            with tempfile.TemporaryDirectory() as tmp:
                c = Chronicle(Path(tmp) / "chronicle.db")
                inv = Investigator(c)
                data = inv.import_path(path)
                ok = len(data["files"]) > 0
                checks.append(
                    result(
                        "Real Facebook/archive import",
                        "PASS" if ok else "FAIL",
                        f"files={len(data['files'])}, entities={len(data['entities'])}, relations={len(data['relations'])}, warnings={len(data['warnings'])}",
                    )
                )
        except Exception as exc:
            checks.append(result("Real Facebook/archive import", "FAIL", str(exc)))
    else:
        checks.append(
            result(
                "Real Facebook/archive import",
                "PENDING",
                "Run with --facebook PATH_TO_ZIP when ready.",
                required=True,
            )
        )

    try:
        agents = build_agents(config)
        lm_agents = [a for a in agents if a.config.get("adapter") == "lmstudio" and a.enabled]
        if not lm_agents:
            checks.append(result("LM Studio", "PENDING", "no enabled LM Studio agent", required=True))
        else:
            statuses = [a.status() for a in lm_agents]
            online = all(s.get("online") for s in statuses)
            detail = "; ".join(s.get("detail", "") for s in statuses)
            checks.append(result("LM Studio", "PASS" if online else "PENDING", detail, required=True))

        cloud_agents = [a for a in agents if a.config.get("adapter") == "openai"]
        if cloud_agents:
            enabled = [a for a in cloud_agents if a.enabled]
            if not enabled:
                checks.append(
                    result(
                        "OpenAI cloud",
                        "SKIP",
                        "disabled by default; optional Stable Gate check",
                        required=False,
                    )
                )
            else:
                statuses = [a.status() for a in enabled]
                online = all(s.get("online") for s in statuses)
                checks.append(
                    result(
                        "OpenAI cloud",
                        "PASS" if online else "PENDING",
                        "; ".join(s.get("detail", "") for s in statuses),
                        required=False,
                    )
                )
    except Exception as exc:
        checks.append(result("AI adapter status", "FAIL", str(exc)))

    try:
        with tempfile.TemporaryDirectory() as tmp:
            gate = StableGate(
                Path(tmp) / "gate.json",
                initial={"Frozen Demo": {"version": "1", "stage": "Frozen", "frozen": True}},
            )
            blocked = False
            try:
                gate.transition("Frozen Demo", "Frozen", reason="normal")
            except PermissionError:
                blocked = True
            checks.append(result("Frozen guard", "PASS" if blocked else "FAIL", f"blocked={blocked}"))
    except Exception as exc:
        checks.append(result("Frozen guard", "FAIL", str(exc)))

    try:
        registry = DeviceRegistry(APP_DIR / "runtime" / "devices" / "devices.json")
        snapshot = registry.snapshot()
        local = next((d for d in snapshot if d.get("id") == "main-pc"), None)
        ok = bool(local and local.get("online"))
        checks.append(
            result(
                "Main PC device node",
                "PASS" if ok else "FAIL",
                json.dumps(local or {}, ensure_ascii=False),
            )
        )
    except Exception as exc:
        checks.append(result("Main PC device node", "FAIL", str(exc)))

    mandatory_fail = any(x["required"] and x["status"] == "FAIL" for x in checks)
    mandatory_pending = any(x["required"] and x["status"] == "PENDING" for x in checks)

    if mandatory_fail:
        overall = "FAIL"
        recommended_stage = "Candidate"
    elif mandatory_pending:
        overall = "PENDING_RUNTIME"
        recommended_stage = "Candidate"
    else:
        overall = "PASS"
        recommended_stage = "Runtime Test"

    return {
        "product": "RAH Raven Daily Driver",
        "version": "1.0",
        "overall": overall,
        "recommended_stage": recommended_stage,
        "checks": checks,
    }


def main():
    parser = argparse.ArgumentParser(description="RAH Raven Daily Driver Windows Runtime Gate")
    parser.add_argument("--facebook", help="Optional real Facebook/archive ZIP or extracted file/folder")
    parser.add_argument(
        "--output",
        default=str(APP_DIR / "runtime" / "state" / "runtime-gate.json"),
        help="JSON result path",
    )
    args = parser.parse_args()

    data = run_checks(args.facebook)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    print("=" * 68)
    print("RAH RAVEN DAILY DRIVER — RUNTIME GATE")
    print("=" * 68)
    for item in data["checks"]:
        flag = "*" if item["required"] else "-"
        print(f"{flag} {item['status']:<15} {item['name']}: {item['detail']}")
    print("-" * 68)
    print("OVERALL:", data["overall"])
    print("RECOMMENDED STAGE:", data["recommended_stage"])
    print("RESULT:", output)

    return 0 if data["overall"] != "FAIL" else 1


if __name__ == "__main__":
    raise SystemExit(main())
