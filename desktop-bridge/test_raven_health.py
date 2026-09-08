from __future__ import annotations

import importlib
import os
import tempfile


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-health-") as temp:
        os.environ["RAH_CHRONICLE_DIR"] = temp
        module = importlib.import_module("raven_bridge")
        client = module.app.test_client()
        local_origin = {"Origin": f"http://127.0.0.1:{module.PORT}"}
        foreign_origin = {"Origin": "https://example.invalid"}

        health = client.get("/health")
        assert health.status_code == 200
        health_data = health.get_json()
        assert health_data["ok"] is True
        assert health_data["raven_doctor"] is True
        assert health_data["raven_doctor_version"] == module.raven_health.HEALTH_VERSION

        ui = client.get("/doctor/ui")
        assert ui.status_code == 200
        assert b"Raven Doctor" in ui.data
        assert b"GREEN" in ui.data
        assert b"YELLOW" in ui.data
        assert b"RED" in ui.data

        foreign = client.get("/doctor/status", headers=foreign_origin)
        assert foreign.status_code == 403

        status = client.get("/doctor/status", headers=local_origin)
        assert status.status_code == 200
        data = status.get_json()
        assert data["status"] in {"GREEN", "YELLOW"}
        assert data["read_only"] is True
        assert data["files_modified"] is False
        assert data["automatic_actions"] is False
        assert data["lm_studio_required"] is False
        assert data["port"] == 18765
        assert isinstance(data["hostname"], str) and data["hostname"]
        assert data["counts"]["RED"] == 0

        checks = {item["id"]: item for item in data["checks"]}
        required = {
            "runtime",
            "bridge",
            "command-wheel",
            "vision-ui",
            "chatgpt-bridge",
            "agent-runner-ui",
            "chronicle-ui",
            "daily-brief-ui",
            "doctor-ui",
            "live5s",
            "agent-runner",
            "chatgpt-handoff",
            "chronicle-service",
            "daily-brief-service",
            "monitors",
            "disk",
            "processes",
            "lm-studio",
        }
        assert required.issubset(checks)
        assert checks["bridge"]["status"] == "GREEN"
        assert checks["live5s"]["status"] == "GREEN"
        assert checks["agent-runner"]["status"] == "GREEN"
        assert checks["chatgpt-handoff"]["status"] == "GREEN"
        assert checks["lm-studio"]["required"] is False
        assert checks["lm-studio"]["status"] in {"GREEN", "YELLOW"}

        acceptance = data["physical_acceptance"]
        assert "PENDING" in acceptance["live5s"]
        assert "PENDING" in acceptance["quick_check_to_chatgpt"]

        print("RAH Raven structured Doctor local-only/read-only health test: OK")


if __name__ == "__main__":
    main()
