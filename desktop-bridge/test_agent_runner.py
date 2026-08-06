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
        assert "project-files" in ids
        assert "git-status" in ids
        assert "test-council" in ids
        assert "test-vision-core" in ids
        assert "test-core-demo" in ids
        assert "test-bridge-security" in ids

        missing_confirm = client.post(
            "/agent/run",
            json={"capability": "project-files"},
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
        assert "RAH-RAVEN-START.html" in result["files"]
        assert all(".git/" not in name for name in result["files"])
        assert all(".venv/" not in name for name in result["files"])

        print("RAH Raven Agent Runner read-only allowlist tests: OK")


if __name__ == "__main__":
    main()
