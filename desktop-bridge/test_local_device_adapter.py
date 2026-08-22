from __future__ import annotations

"""Standard-library regression test for RAH Local Device Adapter v0.1."""

import json
import pathlib
import tempfile

from local_device_adapter import ADAPTER_VERSION, DeviceAdapter


def main() -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
        log_path = pathlib.Path(temp_dir) / "adapter.jsonl"
        adapter = DeviceAdapter(log_path=log_path)

        ping = adapter.execute({"device_id": "mainpc", "action": "PING_DEVICE", "parameters": {}})
        assert ping["ok"] is True
        assert ping["status"] == "PASS"
        assert ping["data"]["reachable"] is True

        status = adapter.execute({"device_id": "mainpc", "action": "GET_STATUS"})
        assert status["ok"] is True
        assert status["data"]["adapter_version"] == ADAPTER_VERSION
        assert status["data"]["mode"] == "local-only"

        simulated = adapter.execute({
            "device_id": "mainpc",
            "action": "LOCAL_TEST_COMMAND",
            "parameters": {"label": "Home Control adapter smoke test"},
        })
        assert simulated["ok"] is True
        assert simulated["data"]["simulated"] is True

        denied = adapter.execute({"device_id": "mainpc", "action": "RUN_SHELL", "parameters": {"cmd": "whoami"}})
        assert denied["ok"] is False
        assert denied["status"] == "ERROR"

        lines = log_path.read_text(encoding="utf-8").splitlines()
        assert len(lines) == 4
        records = [json.loads(line) for line in lines]
        assert [record["action"] for record in records[:3]] == ["PING_DEVICE", "GET_STATUS", "LOCAL_TEST_COMMAND"]
        assert records[3]["status"] == "ERROR"

    print("PASS: RAH Local Device Adapter v0.1 contract")


if __name__ == "__main__":
    main()
