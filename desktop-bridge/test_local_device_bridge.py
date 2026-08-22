from __future__ import annotations

"""Regression test for the Local Device Adapter Raven Bridge boundary."""

import pathlib
import tempfile

import local_device_adapter
import raven_bridge


def main() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        local_device_adapter.LOG_PATH = pathlib.Path(temp_dir) / "bridge-device.jsonl"
        client = raven_bridge.app.test_client()

        health = client.get("/health")
        assert health.status_code == 200
        health_data = health.get_json()
        assert health_data["local_device_adapter"] is True
        assert health_data["local_device_adapter_version"] == local_device_adapter.ADAPTER_VERSION
        assert health_data["local_device_adapter_mode"] == "local-only-allowlist"

        status = client.get("/device/status", headers={"Origin": "null"})
        assert status.status_code == 200
        assert status.get_json()["action"] == "GET_STATUS"

        ping = client.post(
            "/device/action",
            json={"device_id": "mainpc", "action": "PING_DEVICE", "parameters": {}},
            headers={"Origin": "http://127.0.0.1:7070"},
        )
        assert ping.status_code == 200
        assert ping.get_json()["status"] == "PASS"

        denied_action = client.post(
            "/device/action",
            json={"device_id": "mainpc", "action": "RUN_SHELL", "parameters": {}},
            headers={"Origin": "null"},
        )
        assert denied_action.status_code == 400
        assert denied_action.get_json()["ok"] is False

        foreign = client.get(
            "/device/status",
            headers={"Origin": "https://example.com"},
        )
        assert foreign.status_code == 403
        assert foreign.get_json()["ok"] is False

    print("PASS: RAH Local Device Adapter Bridge boundary")


if __name__ == "__main__":
    main()
