"""RAH Raven project registry validator and local status reader.

Safe by default:
- reads raven/projects.json
- checks declared repository paths
- optionally probes loopback-only HTTP health endpoints
- never moves, deletes, installs or modifies project files
"""
from __future__ import annotations

import argparse
import json
import pathlib
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

ROOT = pathlib.Path(__file__).resolve().parents[1]
REGISTRY = pathlib.Path(__file__).with_name("projects.json")
LOOPBACK = {"127.0.0.1", "localhost", "::1"}
VALID_STAGES = {"planned", "prototype", "active", "candidate", "stabilize", "stable", "paused", "blocked"}


def load_registry(path: pathlib.Path = REGISTRY) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def validate_registry(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    projects = data.get("projects")
    if not isinstance(projects, list) or not projects:
        return ["projects must be a non-empty list"]

    seen_ids: set[str] = set()
    seen_priorities: set[int] = set()
    for index, project in enumerate(projects, 1):
        prefix = f"projects[{index}]"
        pid = project.get("id")
        priority = project.get("priority")
        stage = project.get("stage")

        if not isinstance(pid, str) or not pid.strip():
            errors.append(f"{prefix}.id must be a non-empty string")
        elif pid in seen_ids:
            errors.append(f"duplicate project id: {pid}")
        else:
            seen_ids.add(pid)

        if not isinstance(priority, int):
            errors.append(f"{prefix}.priority must be an integer")
        elif priority in seen_priorities:
            errors.append(f"duplicate priority: {priority}")
        else:
            seen_priorities.add(priority)

        if stage not in VALID_STAGES:
            errors.append(f"{prefix}.stage invalid: {stage!r}")

        if not isinstance(project.get("paths", []), list):
            errors.append(f"{prefix}.paths must be a list")
        if not isinstance(project.get("checks", []), list):
            errors.append(f"{prefix}.checks must be a list")

    expected = set(range(1, len(projects) + 1))
    if seen_priorities != expected:
        errors.append(f"priorities must be contiguous 1..{len(projects)}")

    return errors


def _probe_http(url: str, timeout: float = 1.5) -> dict[str, Any]:
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme not in {"http", "https"} or (parsed.hostname or "").lower() not in LOOPBACK:
        return {"ok": False, "detail": "blocked: only loopback health checks are allowed"}

    try:
        req = urllib.request.Request(url, headers={"Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return {"ok": 200 <= response.status < 300, "detail": f"HTTP {response.status}"}
    except urllib.error.HTTPError as exc:
        return {"ok": False, "detail": f"HTTP {exc.code}"}
    except Exception as exc:
        return {"ok": False, "detail": str(exc)}


def project_status(project: dict[str, Any], probe_local: bool = False) -> dict[str, Any]:
    declared_paths = project.get("paths", [])
    path_rows = []
    for raw in declared_paths:
        full = ROOT / raw
        path_rows.append({"path": raw, "exists": full.exists()})

    checks = []
    for check in project.get("checks", []):
        row = {
            "name": check.get("name", "check"),
            "type": check.get("type", "unknown"),
            "required": bool(check.get("required", False)),
        }
        if probe_local and check.get("type") == "http":
            row.update(_probe_http(str(check.get("url", ""))))
        else:
            row.update({"ok": None, "detail": "not probed"})
        checks.append(row)

    missing_paths = [row["path"] for row in path_rows if not row["exists"]]
    required_failures = [row for row in checks if row["required"] and row["ok"] is False]

    if missing_paths:
        state = "missing"
    elif required_failures:
        state = "offline"
    elif declared_paths:
        state = "present"
    else:
        state = "tracked"

    return {
        "priority": project["priority"],
        "id": project["id"],
        "name": project["name"],
        "stage": project["stage"],
        "state": state,
        "missing_paths": missing_paths,
        "paths": path_rows,
        "checks": checks,
        "next": project.get("next"),
    }


def build_report(data: dict[str, Any], probe_local: bool = False) -> dict[str, Any]:
    errors = validate_registry(data)
    projects = [project_status(p, probe_local=probe_local) for p in sorted(data.get("projects", []), key=lambda p: p["priority"])]
    return {
        "ok": not errors,
        "registry": str(REGISTRY),
        "project_root": data.get("project_root"),
        "errors": errors,
        "projects": projects,
    }


def print_text(report: dict[str, Any]) -> None:
    print("RAH Raven Project Registry")
    print("=" * 72)
    if report["errors"]:
        for error in report["errors"]:
            print(f"[FAIL] {error}")
        print("=" * 72)

    for project in report["projects"]:
        print(f'{project["priority"]:>2}. [{project["state"].upper():7}] {project["name"]} — {project["stage"]}')
        if project["missing_paths"]:
            print("    missing:", ", ".join(project["missing_paths"]))
        for check in project["checks"]:
            if check["ok"] is not None:
                tag = "OK" if check["ok"] else ("FAIL" if check["required"] else "WARN")
                print(f'    [{tag}] {check["name"]}: {check["detail"]}')
        if project.get("next"):
            print(f'    next: {project["next"]}')
    print("=" * 72)
    print("RESULT:", "PASS" if report["ok"] else "FAIL")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate and inspect the RAH Raven project registry.")
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--probe-local", action="store_true", help="Probe loopback-only health URLs.")
    args = parser.parse_args()

    try:
        data = load_registry()
        report = build_report(data, probe_local=args.probe_local)
    except Exception as exc:
        if args.as_json:
            print(json.dumps({"ok": False, "error": str(exc)}, indent=2))
        else:
            print(f"RAH Raven Project Registry: FAIL — {exc}")
        return 1

    if args.as_json:
        print(json.dumps(report, indent=2, ensure_ascii=False))
    else:
        print_text(report)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
