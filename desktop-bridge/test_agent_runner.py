from __future__ import annotations

import importlib
import os
import tempfile


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-agent-runner-") as temp:
        os.environ["RAH_CHRONICLE_DIR"] = temp
        module = importlib.import_module("raven_bridge")
        client = module.app.test_client()
        local_origin = {"Origin": f"http://127.0.0.1:{module.PORT}"}
        foreign_origin = {"Origin": "https://example.invalid"}

        # Verify the runner resolved the actual repository root independently
        # of the capped/sorted project-files response page.
        project_root = module.agent_runner.PROJECT_ROOT
        assert (project_root / "RAH-RAVEN-START.html").is_file()

        foreign_caps = client.get("/agent/capabilities", headers=foreign_origin)
        assert foreign_caps.status_code == 403

        foreign_run = client.post(
            "/agent/run",
            json={"capability": "project-files", "confirm": True},
            headers=foreign_origin,
        )
        assert foreign_run.status_code == 403

        capabilities = client.get("/agent/capabilities", headers=local_origin)
        assert capabilities.status_code == 200
        data = capabilities.get_json()
        assert data["ok"] is True
        assert data["mode"] == "read-only-allowlist"
        assert data["arbitrary_commands"] is False
        assert data["file_writes"] is False
        assert data["automatic_execution"] is False
        ids = {item["id"] for item in data["capabilities"]}
        assert "system-inventory" in ids
        assert "project-files" in ids
        assert "git-status" in ids
        assert "test-council" in ids
        assert "test-vision-core" in ids
        assert "test-core-demo" in ids
        assert "test-bridge-security" in ids

        missing_confirm = client.post(
            "/agent/run",
            json={"capability": "system-inventory"},
            headers=local_origin,
        )
        assert missing_confirm.status_code == 400

        arbitrary = client.post(
            "/agent/run",
            json={"capability": "powershell -Command Remove-Item *", "confirm": True},
            headers=local_origin,
        )
        assert arbitrary.status_code == 403
        assert arbitrary.get_json()["arbitrary_commands"] is False

        inventory_run = client.post(
            "/agent/run",
            json={"capability": "system-inventory", "confirm": True},
            headers=local_origin,
        )
        assert inventory_run.status_code == 200
        inventory_result = inventory_run.get_json()
        assert inventory_result["ok"] is True
        assert inventory_result["read_only"] is True
        assert inventory_result["files_modified"] is False
        assert inventory_result["automatic_actions"] is False
        assert inventory_result["tools_executed"] == ["system-inventory"]
        assert inventory_result["command"] is None
        inventory = inventory_result["inventory"]
        assert isinstance(inventory["hostname"], str) and inventory["hostname"]
        assert inventory["os"]["system"]
        assert isinstance(inventory["cpu"]["logical_cores"], (int, type(None)))
        assert isinstance(inventory["gpus"], list)
        assert isinstance(inventory["monitors"], list)
        assert inventory["monitor_count"] == len(inventory["monitors"])
        assert inventory["raven_bridge"]["port"] == module.PORT
        assert inventory["raven_bridge"]["health_route"] is True
        assert inventory["raven_bridge"]["agent_route"] is True
        assert inventory["raven_bridge"]["vision_monitor_route"] is True
        assert inventory["safety"] == {
            "mode": "read-only-allowlist",
            "read_only": True,
            "arbitrary_commands": False,
            "file_writes": False,
            "automatic_execution": False,
        }
        assert "SAFETY   : READ ONLY" in inventory_result["stdout"]

        listing = client.post(
            "/agent/run",
            json={"capability": "project-files", "confirm": True},
            headers=local_origin,
        )
        assert listing.status_code == 200
        result = listing.get_json()
        assert result["ok"] is True
        assert result["read_only"] is True
        assert result["files_modified"] is False
        assert result["automatic_actions"] is False
        assert result["tools_executed"] == ["project-files"]
        assert result["count"] > 0
        assert result["count"] == len(result["files"])
        assert result["count"] <= 180
        assert all(".git/" not in name for name in result["files"])
        assert all(".venv/" not in name for name in result["files"])

        print("RAH Raven Agent Runner read-only allowlist + system inventory tests: OK")


if __name__ == "__main__":
    main()
