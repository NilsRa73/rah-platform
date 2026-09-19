from __future__ import annotations

import importlib
import json
import os
import pathlib
import subprocess
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
        assert health_data["anythingllm_auto_approval"] is True

        foreign = client.post(
            "/agent/jobs",
            json={"capability": "system-inventory", "confirm": True},
            headers=foreign_origin,
        )
        assert foreign.status_code == 403

        foreign_auto = client.post(
            "/agent/jobs/auto",
            json={"capability": "system-inventory"},
            headers=foreign_origin,
        )
        assert foreign_auto.status_code == 403

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
        # system-inventory may spend up to ~8s probing Windows GPU data, so the
        # previous 5s fixed loop was inherently flaky on busy hosted runners.
        deadline = time.monotonic() + 25.0
        while time.monotonic() < deadline:
            response = client.get(f"/agent/jobs/{job_id}", headers=local_origin)
            assert response.status_code == 200
            final = response.get_json()["job"]
            if final["status"] in {"succeeded", "failed"}:
                break
            time.sleep(0.10)

        assert final is not None
        assert final["status"] == "succeeded", {"timeout_seconds": 25, "job": final}
        assert final["result"]["ok"] is True
        assert final["result"]["read_only"] is True
        assert final["result"]["files_modified"] is False
        assert final["result"]["arbitrary_commands"] is False
        assert final["result"]["tools_executed"] == ["system-inventory"]
        assert final["result"]["execution_mode"] == "queued-after-explicit-confirm"

        approval = jobs.agent_runner.anythingllm_approval
        original_post_json = approval._post_json
        old_workspace = os.environ.get("RAH_ANYTHINGLLM_WORKSPACE")
        old_api_key = os.environ.get("RAH_ANYTHINGLLM_API_KEY")
        old_base_url = os.environ.get("RAH_ANYTHINGLLM_BASE_URL")
        try:
            os.environ["RAH_ANYTHINGLLM_WORKSPACE"] = "rah-review"
            os.environ["RAH_ANYTHINGLLM_API_KEY"] = "test-only-key"
            os.environ["RAH_ANYTHINGLLM_BASE_URL"] = "http://127.0.0.1:3001"

            approval._post_json = lambda url, api_key, payload, timeout: {
                "textResponse": json.dumps({
                    "decision": "APPROVE",
                    "summary": "Allowlisted read-only inventory can run.",
                    "risk": "low",
                    "reasons": ["Fixed capability, no arguments, no writes."],
                })
            }

            auto_submitted = client.post(
                "/agent/jobs/auto",
                json={
                    "capability": "system-inventory",
                    "client_request_id": "test-auto-system-inventory",
                    "purpose": "Verify the no-keyboard approval path.",
                },
                headers=local_origin,
            )
            assert auto_submitted.status_code == 202, auto_submitted.get_json()
            auto_data = auto_submitted.get_json()
            assert auto_data["accepted"] is True
            assert auto_data["decision"] == "APPROVE"
            assert auto_data["job"]["approval_source"] == "anythingllm"
            assert auto_data["job"]["confirmed"] is False
            assert auto_data["job"]["approved"] is True
            auto_job_id = auto_data["job"]["id"]

            auto_final = None
            auto_deadline = time.monotonic() + 25.0
            while time.monotonic() < auto_deadline:
                response = client.get(f"/agent/jobs/{auto_job_id}", headers=local_origin)
                assert response.status_code == 200
                auto_final = response.get_json()["job"]
                if auto_final["status"] in {"succeeded", "failed"}:
                    break
                time.sleep(0.10)

            assert auto_final is not None
            assert auto_final["status"] == "succeeded", {
                "timeout_seconds": 25,
                "job": auto_final,
            }
            assert auto_final["result"]["ok"] is True
            assert auto_final["result"]["read_only"] is True
            assert auto_final["result"]["files_modified"] is False
            assert auto_final["result"]["arbitrary_commands"] is False
            assert auto_final["result"]["tools_executed"] == ["system-inventory"]
            assert auto_final["result"]["execution_mode"] == "queued-after-anythingllm-approval"
            assert auto_final["result"]["approval_source"] == "anythingllm"

            approval._post_json = lambda url, api_key, payload, timeout: {
                "textResponse": json.dumps({
                    "decision": "BLOCK",
                    "summary": "Test block.",
                    "risk": "high",
                    "reasons": ["Intentional test denial."],
                })
            }
            blocked = client.post(
                "/agent/jobs/auto",
                json={"capability": "system-inventory", "purpose": "Block-path test."},
                headers=local_origin,
            )
            assert blocked.status_code == 409
            blocked_data = blocked.get_json()
            assert blocked_data["accepted"] is False
            assert blocked_data["queued"] is False
            assert blocked_data["decision"] == "BLOCK"

            arbitrary_auto = client.post(
                "/agent/jobs/auto",
                json={"capability": "powershell -Command whoami"},
                headers=local_origin,
            )
            assert arbitrary_auto.status_code == 403
            assert arbitrary_auto.get_json()["arbitrary_commands"] is False

            unsupported_auto = client.post(
                "/agent/jobs/auto",
                json={"capability": "project-files", "purpose": "Must remain manual."},
                headers=local_origin,
            )
            assert unsupported_auto.status_code == 403
            unsupported_data = unsupported_auto.get_json()
            assert unsupported_data["anythingllm_approval_supported"] is False

            auto_args = client.post(
                "/agent/jobs/auto",
                json={"capability": "system-inventory", "args": ["anything"]},
                headers=local_origin,
            )
            assert auto_args.status_code == 400
            assert auto_args.get_json()["arguments_allowed"] is False
        finally:
            approval._post_json = original_post_json
            if old_workspace is None:
                os.environ.pop("RAH_ANYTHINGLLM_WORKSPACE", None)
            else:
                os.environ["RAH_ANYTHINGLLM_WORKSPACE"] = old_workspace
            if old_api_key is None:
                os.environ.pop("RAH_ANYTHINGLLM_API_KEY", None)
            else:
                os.environ["RAH_ANYTHINGLLM_API_KEY"] = old_api_key
            if old_base_url is None:
                os.environ.pop("RAH_ANYTHINGLLM_BASE_URL", None)
            else:
                os.environ["RAH_ANYTHINGLLM_BASE_URL"] = old_base_url

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
        assert '"approval_source":"manual-confirm"' in audit_text
        assert '"approval_source":"anythingllm"' in audit_text
        assert job_id in audit_text
        assert auto_job_id in audit_text

        project_root = pathlib.Path(__file__).resolve().parent.parent
        approval_test_ps1 = project_root / "TEST-ANYTHINGLLM-APPROVAL.ps1"
        approval_start_cmd = project_root / "START-HER-ANYTHINGLLM-APPROVAL.cmd"
        assert approval_test_ps1.is_file()
        assert approval_start_cmd.is_file()
        approval_test_text = approval_test_ps1.read_text(encoding="utf-8")
        approval_start_text = approval_start_cmd.read_text(encoding="utf-8")
        assert "RahAnythingApprovalTestVersion = '0.1.0'" in approval_test_text
        assert "/agent/jobs/auto" in approval_test_text
        assert "system-inventory" in approval_test_text
        assert "queued-after-anythingllm-approval" in approval_test_text
        assert "secretIncluded = $false" in approval_test_text
        assert "CONFIGURE-RAH-PROJECT-MEMORY.cmd" in approval_start_text
        assert "TEST-ANYTHINGLLM-APPROVAL.ps1" in approval_start_text
        assert "--self-test" in approval_start_text

        if os.name == "nt":
            ps_self = subprocess.run(
                [
                    "powershell.exe",
                    "-NoProfile",
                    "-NonInteractive",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(approval_test_ps1),
                    "-SelfTest",
                ],
                capture_output=True,
                text=True,
                timeout=20,
                check=False,
            )
            assert ps_self.returncode == 0, {
                "stdout": ps_self.stdout,
                "stderr": ps_self.stderr,
            }

            cmd_self = subprocess.run(
                ["cmd.exe", "/d", "/c", str(approval_start_cmd), "--self-test"],
                capture_output=True,
                text=True,
                timeout=20,
                check=False,
            )
            assert cmd_self.returncode == 0, {
                "stdout": cmd_self.stdout,
                "stderr": cmd_self.stderr,
            }

        bridge_health = client.get("/health")
        assert bridge_health.status_code == 200
        bridge_health_data = bridge_health.get_json()
        assert bridge_health_data["job_executor"] is True
        assert bridge_health_data["job_executor_ready"] is True
        assert bridge_health_data["job_executor_mode"] == "queued-read-only-allowlist"

        print("RAH Raven queued Job Executor lifecycle + safety tests: OK")


if __name__ == "__main__":
    main()
