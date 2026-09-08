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
        foreign_pending = client.get("/agent/chatgpt/pending", headers=foreign_origin)
        assert foreign_pending.status_code == 403

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
        assert "hovedpc-local-status" in ids
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

        local_status_run = client.post(
            "/agent/run",
            json={"capability": "hovedpc-local-status", "confirm": True},
            headers=local_origin,
        )
        assert local_status_run.status_code == 200
        local_result = local_status_run.get_json()
        assert local_result["ok"] is True
        assert local_result["read_only"] is True
        assert local_result["files_modified"] is False
        assert local_result["automatic_actions"] is False
        assert local_result["tools_executed"] == ["hovedpc-local-status"]
        assert local_result["command"] is None
        assert "RAH RAVEN - HOVED-PC LOCAL STATUS" in local_result["stdout"]
        assert "SAFETY       : READ ONLY" in local_result["stdout"]
        local_status = local_result["local_status"]
        assert isinstance(local_status["hostname"], str) and local_status["hostname"]
        assert isinstance(local_status["local_addresses"], list)
        assert isinstance(local_status["disk"]["free_gb"], (int, float))
        assert isinstance(local_status["rah_roots"], list) and local_status["rah_roots"]
        assert all(root["file_names_returned"] is False for root in local_status["rah_roots"])
        assert all(root["file_contents_read"] is False for root in local_status["rah_roots"])
        assert local_status["raven_processes"]["probe"] == "fixed-image-filter"
        assert local_status["chronicle"]["foreground_window_read"] is False
        assert "hovedpc-local-status" in local_status["tools"]
        assert local_status["bridge"]["port"] == module.PORT
        assert local_status["safety"] == {
            "mode": "read-only-allowlist",
            "read_only": True,
            "arbitrary_paths": False,
            "arbitrary_commands": False,
            "file_names_returned": False,
            "file_contents_read": False,
            "file_writes": False,
            "automatic_execution": False,
            "network_scan": False,
            "external_network_requests": False,
        }

        missing_chat_confirm = client.post(
            "/agent/chatgpt/quick-check",
            json={},
            headers=local_origin,
        )
        assert missing_chat_confirm.status_code == 400

        queued = client.post(
            "/agent/chatgpt/quick-check",
            json={"confirm": True},
            headers=local_origin,
        )
        assert queued.status_code == 200
        queued_data = queued.get_json()
        assert queued_data["ok"] is True
        assert queued_data["queued"] is True
        assert queued_data["delivery"] == "composer-draft-only"
        assert queued_data["read_only"] is True
        assert queued_data["files_modified"] is False
        assert queued_data["automatic_actions"] is False
        assert queued_data["auto_send"] is False
        draft_id = queued_data["id"]

        pending = client.get("/agent/chatgpt/pending", headers=local_origin)
        assert pending.status_code == 200
        pending_data = pending.get_json()
        assert pending_data["pending"] is True
        item = pending_data["item"]
        assert item["id"] == draft_id
        assert item["kind"] == "quick-check"
        assert item["auto_send"] is False
        assert item["text"].startswith("se på quick check\n\nRAH RAVEN - LOCAL SYSTEM INVENTORY")
        assert len(item["text"]) <= 12000

        missing_ack = client.post("/agent/chatgpt/ack", json={}, headers=local_origin)
        assert missing_ack.status_code == 400
        wrong_ack = client.post("/agent/chatgpt/ack", json={"id": "wrong"}, headers=local_origin)
        assert wrong_ack.status_code == 404
        ack = client.post("/agent/chatgpt/ack", json={"id": draft_id}, headers=local_origin)
        assert ack.status_code == 200
        ack_data = ack.get_json()
        assert ack_data["acked"] is True
        assert ack_data["auto_send"] is False
        after_ack = client.get("/agent/chatgpt/pending", headers=local_origin).get_json()
        assert after_ack["pending"] is False

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

        print("RAH Raven Agent Runner read-only allowlist + HOVED-PC local status + Quick Check draft tests: OK")


if __name__ == "__main__":
    main()
