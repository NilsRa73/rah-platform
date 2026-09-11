from __future__ import annotations

import importlib
import os
import pathlib
import tempfile
import time


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-raven-jobs-") as temp:
        os.environ["RAH_CHRONICLE_DIR"] = str(pathlib.Path(temp) / "chronicle")
        os.environ["RAH_JOB_DIR"] = str(pathlib.Path(temp) / "jobs")
        # CI may not run elevated. Production keeps the default Admin requirement.
        os.environ["RAH_JOB_REQUIRE_ADMIN"] = "0"

        module = importlib.import_module("raven_bridge_agent")
        jobs = module.raven_jobs
        client = module.app.test_client()
        local_origin = {"Origin": f"http://127.0.0.1:{module.PORT}"}
        foreign_origin = {"Origin": "https://example.invalid"}

        health = client.get("/agent/jobs/health", headers=local_origin)
        assert health.status_code == 200
        health_data = health.get_json()
        assert health_data["ok"] is True
        assert health_data["ready"] is True
        assert health_data["mode"] == "queued-read-only-allowlist"
        assert health_data["arbitrary_commands"] is False
        assert health_data["arguments_allowed"] is False

        foreign = client.post(
            "/agent/jobs",
            json={"capability": "system-inventory", "confirm": True},
            headers=foreign_origin,
        )
        assert foreign.status_code == 403

        missing_confirm = client.post(
            "/agent/jobs",
            json={"capability": "system-inventory"},
            headers=local_origin,
        )
        assert missing_confirm.status_code == 400

        arbitrary = client.post(
            "/agent/jobs",
            json={"capability": "powershell -Command whoami", "confirm": True},
            headers=local_origin,
        )
        assert arbitrary.status_code == 403
        assert arbitrary.get_json()["arbitrary_commands"] is False

        unexpected_args = client.post(
            "/agent/jobs",
            json={
                "capability": "system-inventory",
                "confirm": True,
                "args": ["anything"],
            },
            headers=local_origin,
        )
        assert unexpected_args.status_code == 400
        assert unexpected_args.get_json()["arguments_allowed"] is False

        submitted = client.post(
            "/agent/jobs",
            json={
                "capability": "system-inventory",
                "confirm": True,
                "client_request_id": "test-system-inventory",
            },
            headers=local_origin,
        )
        assert submitted.status_code == 202
        submitted_data = submitted.get_json()
        assert submitted_data["accepted"] is True
        assert submitted_data["job"]["status"] == "queued"
        job_id = submitted_data["job"]["id"]

        final = None
        for _ in range(100):
            response = client.get(f"/agent/jobs/{job_id}", headers=local_origin)
            assert response.status_code == 200
            final = response.get_json()["job"]
            if final["status"] in {"succeeded", "failed"}:
                break
            time.sleep(0.05)

        assert final is not None
        assert final["status"] == "succeeded", final
        assert final["result"]["ok"] is True
        assert final["result"]["read_only"] is True
        assert final["result"]["files_modified"] is False
        assert final["result"]["arbitrary_commands"] is False
        assert final["result"]["tools_executed"] == ["system-inventory"]
        assert final["result"]["execution_mode"] == "queued-after-explicit-confirm"

        listing = client.get("/agent/jobs?limit=10", headers=local_origin)
        assert listing.status_code == 200
        listing_data = listing.get_json()
        assert listing_data["count"] >= 1
        assert any(item["id"] == job_id for item in listing_data["jobs"])

        assert jobs.AUDIT_FILE.is_file()
        audit_text = jobs.AUDIT_FILE.read_text(encoding="utf-8")
        assert '"event":"queued"' in audit_text
        assert '"event":"running"' in audit_text
        assert '"event":"finished"' in audit_text
        assert job_id in audit_text

        bridge_health = client.get("/health")
        assert bridge_health.status_code == 200
        bridge_health_data = bridge_health.get_json()
        assert bridge_health_data["job_executor"] is True
        assert bridge_health_data["job_executor_ready"] is True
        assert bridge_health_data["job_executor_mode"] == "queued-read-only-allowlist"

        print("RAH Raven queued Job Executor lifecycle + safety tests: OK")


if __name__ == "__main__":
    main()
