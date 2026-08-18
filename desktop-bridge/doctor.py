"""RAH Raven Doctor.

Checks the local prerequisites and services needed by Raven Vision:
- Python/runtime and bridge dependencies
- Desktop Bridge health and screenshot capture
- LM Studio OpenAI-compatible API
- loaded model availability

Exit code 0 means the complete local chain is ready.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import platform
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


@dataclass
class Check:
    name: str
    ok: bool
    detail: str
    required: bool = True


def fetch_json(url: str, timeout: float = 4.0) -> Any:
    request = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.loads(response.read().decode("utf-8"))


def dependency_checks() -> list[Check]:
    checks = [
        Check("Python", sys.version_info >= (3, 10), f"{platform.python_version()} ({sys.executable})"),
    ]
    for module, label in (("flask", "Flask"), ("flask_cors", "Flask-CORS"), ("mss", "MSS capture"), ("PIL", "Pillow")):
        found = importlib.util.find_spec(module) is not None
        checks.append(Check(label, found, "installed" if found else "missing"))
    return checks


def bridge_checks(base_url: str, capture: bool) -> list[Check]:
    checks: list[Check] = []
    try:
        data = fetch_json(f"{base_url.rstrip('/')}/health")
        checks.append(Check("Desktop Bridge", bool(data.get("ok")), f"v{data.get('version', '?')} on {data.get('platform', '?')}"))
    except Exception as exc:
        checks.append(Check("Desktop Bridge", False, friendly_error(exc)))
        return checks

    if capture:
        started = time.perf_counter()
        try:
            data = fetch_json(f"{base_url.rstrip('/')}/capture/active-window", timeout=12)
            metadata = data.get("metadata") or {}
            image = str(data.get("image") or "")
            ok = bool(data.get("ok") and image.startswith("data:image/"))
            duration = time.perf_counter() - started
            checks.append(Check(
                "Window capture",
                ok,
                f"{metadata.get('width', '?')}x{metadata.get('height', '?')} • {duration:.1f}s" if ok else str(data.get("error") or "no image returned"),
            ))
        except Exception as exc:
            checks.append(Check("Window capture", False, friendly_error(exc)))
    return checks


def lm_studio_checks(base_url: str) -> list[Check]:
    try:
        data = fetch_json(f"{base_url.rstrip('/')}/models", timeout=5)
        models = [item.get("id") for item in data.get("data", []) if item.get("id")]
        if not models:
            return [
                Check("LM Studio server", True, "API reachable"),
                Check("Loaded model", False, "No model is loaded in LM Studio"),
            ]
        preview = ", ".join(models[:3])
        if len(models) > 3:
            preview += f" (+{len(models) - 3} more)"
        return [
            Check("LM Studio server", True, "OpenAI-compatible API reachable"),
            Check("Loaded model", True, preview),
        ]
    except Exception as exc:
        return [Check("LM Studio server", False, friendly_error(exc))]


def friendly_error(exc: Exception) -> str:
    if isinstance(exc, urllib.error.HTTPError):
        return f"HTTP {exc.code}"
    if isinstance(exc, urllib.error.URLError):
        reason = getattr(exc, "reason", exc)
        return f"connection failed: {reason}"
    return str(exc)


def print_report(checks: list[Check]) -> None:
    width = max(len(check.name) for check in checks)
    print("\nRAH Raven Doctor")
    print("=" * 58)
    for check in checks:
        icon = "OK" if check.ok else "FAIL"
        print(f"[{icon:<4}] {check.name:<{width}}  {check.detail}")
    print("=" * 58)
    failed = [check for check in checks if check.required and not check.ok]
    if failed:
        print("RESULT: NOT READY")
        print("\nFix order:")
        names = {item.name for item in failed}
        step = 1
        if {"Python", "Flask", "Flask-CORS", "MSS capture", "Pillow"} & names:
            print(f" {step}. Run start-bridge.bat again to install local dependencies.")
            step += 1
        if "Desktop Bridge" in names:
            print(f" {step}. Start desktop-bridge\\start-bridge.bat.")
            step += 1
        if "LM Studio server" in names:
            print(f" {step}. Open LM Studio and start Local Server on port 1234.")
            step += 1
        if "Loaded model" in names:
            print(f" {step}. Load a vision-capable model in LM Studio.")
            step += 1
        if "Window capture" in names:
            print(f" {step}. Keep a normal window active and rerun the doctor.")
    else:
        print("RESULT: READY — Raven Vision local chain is operational.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate the complete RAH Raven Vision local chain.")
    parser.add_argument("--bridge", default="http://127.0.0.1:18765")
    parser.add_argument("--lm-studio", default="http://127.0.0.1:1234/v1")
    parser.add_argument("--skip-capture", action="store_true")
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()

    checks = dependency_checks()
    checks.extend(bridge_checks(args.bridge, not args.skip_capture))
    checks.extend(lm_studio_checks(args.lm_studio))

    if args.as_json:
        print(json.dumps([check.__dict__ for check in checks], indent=2))
    else:
        print_report(checks)
    return 0 if all(check.ok or not check.required for check in checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
