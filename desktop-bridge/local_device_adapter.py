from __future__ import annotations

"""RAH Local Device Adapter v0.1.0.

A deliberately small local-only boundary between Home Control and future
physical device adapters. v0.1 performs no discovery, pairing, Wi-Fi,
Bluetooth, shell execution or remote control.

Supported actions:
- PING_DEVICE: deterministic adapter reachability test.
- GET_STATUS: returns adapter/device test status.
- LOCAL_TEST_COMMAND: simulates a command without changing the machine.

Every request produces a structured result and is appended to a local JSONL
log. The adapter accepts only explicit action IDs; arbitrary commands are not
executed.
"""

import json
import pathlib
from datetime import datetime, timezone
from typing import Any

ADAPTER_VERSION = "0.1.0"
ALLOWED_ACTIONS = frozenset({"PING_DEVICE", "GET_STATUS", "LOCAL_TEST_COMMAND"})
MAX_DEVICE_ID_LENGTH = 100
MAX_PARAMETERS_BYTES = 4096
LOG_PATH = pathlib.Path(__file__).resolve().parent / "local_device_adapter.jsonl"


def _timestamp() -> str:
    return datetime.now(timezone.utc).isoformat()


def _clean_device_id(value: Any) -> str:
    if not isinstance(value, str):
        raise ValueError("device_id må være tekst.")
    device_id = value.strip()
    if not device_id or len(device_id) > MAX_DEVICE_ID_LENGTH:
        raise ValueError("device_id mangler eller er for lang.")
    if any(ch in device_id for ch in "<>\\/\r\n\t"):
        raise ValueError("device_id inneholder tegn som ikke støttes.")
    return device_id


def _clean_parameters(value: Any) -> dict[str, Any]:
    if value is None:
        return {}
    if not isinstance(value, dict):
        raise ValueError("parameters må være et JSON-objekt.")
    encoded = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    if len(encoded.encode("utf-8")) > MAX_PARAMETERS_BYTES:
        raise ValueError("parameters er for stor.")
    return value


def _append_log(result: dict[str, Any], log_path: pathlib.Path) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(result, ensure_ascii=False, sort_keys=True) + "\n")


class DeviceAdapter:
    """Local-only, allowlisted device action adapter."""

    def __init__(self, log_path: pathlib.Path | None = None) -> None:
        self.log_path = pathlib.Path(log_path) if log_path else LOG_PATH

    def execute(self, request: dict[str, Any]) -> dict[str, Any]:
        if not isinstance(request, dict):
            return self._error("unknown", "UNKNOWN", "Forespørselen må være et JSON-objekt.")

        try:
            device_id = _clean_device_id(request.get("device_id"))
            action = request.get("action")
            if not isinstance(action, str) or action not in ALLOWED_ACTIONS:
                raise ValueError("Handlingen er ikke tillatt av Local Device Adapter.")
            parameters = _clean_parameters(request.get("parameters"))
        except ValueError as exc:
            return self._error(str(request.get("device_id") or "unknown"), str(request.get("action") or "UNKNOWN"), str(exc))

        if action == "PING_DEVICE":
            message = "Local Device Adapter svarer. Ingen nettverksforespørsel ble sendt."
            data = {"reachable": True, "mode": "local-adapter-test"}
        elif action == "GET_STATUS":
            message = "Lokal adapterstatus hentet."
            data = {"adapter_version": ADAPTER_VERSION, "mode": "local-only", "device_state": "registered-test-target"}
        else:
            message = "Testkommando simulert. Ingen systemendring ble utført."
            data = {"simulated": True, "parameters": parameters}

        result = {
            "ok": True,
            "device_id": device_id,
            "action": action,
            "status": "PASS",
            "message": message,
            "timestamp": _timestamp(),
            "data": data,
        }
        return self._log_or_fail(result)

    def _error(self, device_id: str, action: str, message: str) -> dict[str, Any]:
        result = {
            "ok": False,
            "device_id": device_id[:MAX_DEVICE_ID_LENGTH],
            "action": action,
            "status": "ERROR",
            "message": message,
            "timestamp": _timestamp(),
            "data": {},
        }
        return self._log_or_fail(result)

    def _log_or_fail(self, result: dict[str, Any]) -> dict[str, Any]:
        try:
            _append_log(result, self.log_path)
            return result
        except OSError as exc:
            failed = dict(result)
            failed.update({
                "ok": False,
                "status": "ERROR",
                "message": f"Adapterresultatet kunne ikke logges lokalt: {exc}",
                "data": {},
            })
            return failed


def execute_device_request(request: dict[str, Any], *, log_path: pathlib.Path | None = None) -> dict[str, Any]:
    """Convenience entrypoint for Bridge integration."""
    return DeviceAdapter(log_path=log_path).execute(request)
