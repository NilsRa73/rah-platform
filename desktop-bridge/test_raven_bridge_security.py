from __future__ import annotations

import importlib
import json
import os
import tempfile
from pathlib import Path

import doctor


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-bridge-security-") as temp:
        os.environ["RAH_CHRONICLE_DIR"] = temp
        os.environ["RAH_DOWNLOAD_MANAGER_STATE"] = str(Path(temp) / "downloads-state")
        os.environ["RAH_RAVEN_VAULT"] = str(Path(temp) / "vault")
        os.environ["RAH_DOWNLOADS_DIR"] = str(Path(temp) / "incoming")
        module = importlib.import_module("raven_bridge")
        client = module.app.test_client()
        foreign_origin = {"Origin": "https://example.invalid"}
        local_origin = {"Origin": f"http://127.0.0.1:{module.PORT}"}
        file_origin = {"Origin": "null"}

        assert module.PORT == 18765
        health = client.get("/health", headers=local_origin)
        assert health.status_code == 200
        health_data = health.get_json()
        assert health_data["ok"] is True
        assert health_data["council_proxy"] is True
        assert health_data["anythingllm_approval_gate"] is True
        assert health_data["anythingllm_approval_version"] == "0.1.0"
        assert health_data["download_manager"] is True
        assert health_data["download_manager_mode"] == "chatgpt-expected-only"
        assert health_data["vision_monitor_capture"] is True
        assert health_data["vision_area_capture"] is True
        assert health_data["vision_chatgpt_userscript"] is True
        assert health_data["app_launcher"] is True
        assert health_data["app_launcher_mode"] == "fixed-allowlist-explicit-launch"

        # Raven Doctor describes a local chain and must fail closed before any
        # request when an external/LAN/credential-bearing endpoint is supplied.
        bridge_paths = frozenset({"", "/"})
        lm_paths = frozenset({"", "/", "/v1", "/v1/"})
        allowed = (
            ("http://127.0.0.1:18765", "Desktop Bridge", bridge_paths, "http://127.0.0.1:18765"),
            ("http://localhost:18765/", "Desktop Bridge", bridge_paths, "http://localhost:18765"),
            ("http://[::1]:18765", "Desktop Bridge", bridge_paths, "http://[::1]:18765"),
            ("http://127.0.0.1:1234/v1", "LM Studio", lm_paths, "http://127.0.0.1:1234/v1"),
        )
        for value, label, paths, expected in allowed:
            assert doctor.normalize_loopback_endpoint(value, label=label, allowed_paths=paths) == expected

        blocked = (
            ("https://example.invalid:18765", "Desktop Bridge", bridge_paths),
            ("http://192.168.1.50:18765", "Desktop Bridge", bridge_paths),
            ("http://0.0.0.0:18765", "Desktop Bridge", bridge_paths),
            ("http://user:pass@127.0.0.1:18765", "Desktop Bridge", bridge_paths),
            ("http://127.0.0.1:18765/?token=secret", "Desktop Bridge", bridge_paths),
            ("http://127.0.0.1:18765/#fragment", "Desktop Bridge", bridge_paths),
            ("http://127.0.0.1:18765/admin", "Desktop Bridge", bridge_paths),
            ("file:///tmp/bridge", "Desktop Bridge", bridge_paths),
            ("http://10.0.0.8:1234/v1", "LM Studio", lm_paths),
            ("http://127.0.0.1:1234/v1/models", "LM Studio", lm_paths),
        )
        for value, label, paths in blocked:
            try:
                doctor.normalize_loopback_endpoint(value, label=label, allowed_paths=paths)
            except ValueError:
                pass
            else:
                raise AssertionError(f"Doctor accepted non-local or malformed endpoint: {value}")

        foreign_get_paths = (
            "/chronicle/status",
            "/chronicle/events",
            "/chronicle/summary",
            "/chronicle/brief",
            "/capture/active-window",
            "/capture/after-delay?seconds=1",
            "/capture/monitors",
            "/capture/monitor?index=1",
            "/capture/area?left=0&top=0&width=100&height=100",
            "/lm/models",
            "/case",
            "/agent/capabilities",
            "/agent/approval/status",
            "/downloads/status",
            "/downloads/recent",
            "/downloads/search?q=pdf",
            "/apps/catalog",
        )
        for path in foreign_get_paths:
            foreign = client.get(path, headers=foreign_origin)
            assert foreign.status_code == 403, path

        for path, payload in (
            ("/chronicle/ai-brief", {"hours": 24}),
            ("/lm/chat", {"messages": [{"role": "user", "content": "test"}]}),
            ("/lm/analyze", {"image": "data:image/png;base64,AA==", "prompt": "test"}),
            ("/case/analyze", {"documents": [], "question": "test"}),
            ("/agent/run", {"capability": "project-files", "confirm": True}),
            ("/agent/approval/review", {"capability": "project-files", "proposal": {"read_only": True}}),
            ("/downloads/expect", {"filename": "test.pdf", "source": "chatgpt"}),
            ("/downloads/scan", {"confirm": True}),
            ("/downloads/open-vault", {"confirm": True}),
            ("/apps/launch", {"id": "world-media", "confirm": True}),
        ):
            foreign = client.post(path, json=payload, headers=foreign_origin)
            assert foreign.status_code == 403, path

        local = client.get("/chronicle/status", headers=local_origin)
        assert local.status_code == 200
        assert local.get_json()["ok"] is True

        no_origin = client.get("/chronicle/summary")
        assert no_origin.status_code == 200

        download_status = client.get("/downloads/status", headers=file_origin)
        assert download_status.status_code == 200
        download_data = download_status.get_json()
        assert download_data["mode"] == "chatgpt-expected-only"
        assert download_data["automatic"] is True

        app_catalog = client.get("/apps/catalog", headers=file_origin)
        assert app_catalog.status_code == 200
        app_catalog_data = app_catalog.get_json()
        assert app_catalog_data["mode"] == "fixed-allowlist-explicit-launch"
        assert app_catalog_data["arbitrary_commands"] is False
        assert app_catalog_data["caller_arguments"] is False
        assert {item["id"] for item in app_catalog_data["apps"]} == {"world-media", "rah-os", "raven-browser"}

        no_confirm = client.post(
            "/apps/launch",
            json={"id": "world-media"},
            headers=file_origin,
        )
        assert no_confirm.status_code == 409
        assert no_confirm.get_json()["automatic_launch"] is False

        arbitrary_app = client.post(
            "/apps/launch",
            json={"id": "cmd /c del *", "confirm": True},
            headers=file_origin,
        )
        assert arbitrary_app.status_code == 403
        assert arbitrary_app.get_json()["arbitrary_commands"] is False

        original_app_launch = module.app_launcher.launch
        try:
            module.app_launcher.launch = lambda root, app_id: {
                "ok": True,
                "id": app_id,
                "name": "RAH World Media",
                "pid": 4242,
                "shell_window": False,
                "arbitrary_commands": False,
                "caller_arguments": False,
            }
            explicit_app = client.post(
                "/apps/launch",
                json={"id": "world-media", "confirm": True},
                headers=file_origin,
            )
            assert explicit_app.status_code == 200
            explicit_data = explicit_app.get_json()
            assert explicit_data["ok"] is True
            assert explicit_data["shell_window"] is False
            assert explicit_data["arbitrary_commands"] is False
        finally:
            module.app_launcher.launch = original_app_launch

        agent_caps = client.get("/agent/capabilities", headers=file_origin)
        assert agent_caps.status_code == 200
        agent_data = agent_caps.get_json()
        assert agent_data["mode"] == "read-only-allowlist"
        assert agent_data["arbitrary_commands"] is False
        assert agent_data["file_writes"] is False
        assert agent_data["automatic_execution"] is False
        assert agent_data["anythingllm_approval"]["mode"] == "anythingllm-read-only-gate"

        approval = module.agent_runner.anythingllm_approval
        assert approval._normalize_base_url("http://127.0.0.1:3001") == "http://127.0.0.1:3001"
        for blocked_url in (
            "http://192.168.1.50:3001",
            "http://0.0.0.0:3001",
            "http://user:pass@127.0.0.1:3001",
            "http://127.0.0.1:3001/api/v1",
        ):
            try:
                approval._normalize_base_url(blocked_url)
            except approval.ApprovalConfigError:
                pass
            else:
                raise AssertionError(f"Approval gate accepted unsafe AnythingLLM URL: {blocked_url}")

        redirect_handler = approval._NoRedirectHandler()
        try:
            redirect_handler.redirect_request(
                None,
                None,
                302,
                "Found",
                {"Location": "https://example.com/collect"},
                "https://example.com/collect",
            )
        except approval.ApprovalRedirectError as exc:
            assert "loopback-only boundary" in str(exc)
        else:
            raise AssertionError("AnythingLLM HTTP redirect was not blocked.")

        previous_workspace = os.environ.get("RAH_ANYTHINGLLM_WORKSPACE")
        previous_api_key = os.environ.get("RAH_ANYTHINGLLM_API_KEY")
        previous_base_url = os.environ.get("RAH_ANYTHINGLLM_BASE_URL")
        previous_memory_config = os.environ.get("RAH_PROJECT_MEMORY_CONFIG")
        original_post_json = approval._post_json
        try:
            shared_token = Path(temp) / "anythingllm-token.txt"
            shared_token.write_text("test-shared-key", encoding="utf-8")
            shared_config = Path(temp) / "project-memory.json"
            shared_config.write_text(
                json.dumps({
                    "base_url": "http://127.0.0.1:3001",
                    "workspace": "rah-shared-memory",
                    "token_file": str(shared_token),
                }),
                encoding="utf-8",
            )
            os.environ.pop("RAH_ANYTHINGLLM_WORKSPACE", None)
            os.environ.pop("RAH_ANYTHINGLLM_API_KEY", None)
            os.environ.pop("RAH_ANYTHINGLLM_BASE_URL", None)
            os.environ["RAH_PROJECT_MEMORY_CONFIG"] = str(shared_config)
            shared = approval._config()
            assert shared["configured"] is True
            assert shared["workspace"] == "rah-shared-memory"
            assert shared["api_key"] == "test-shared-key"
            assert shared["credential_source"] == "project-memory-token-file"
            shared_status = approval._safe_status()
            assert shared_status["project_memory_shared_config"] is True
            assert "test-shared-key" not in json.dumps(shared_status)

            os.environ["RAH_ANYTHINGLLM_WORKSPACE"] = "rah-review"
            os.environ["RAH_ANYTHINGLLM_API_KEY"] = "test-only-key"
            os.environ["RAH_ANYTHINGLLM_BASE_URL"] = "http://127.0.0.1:3001"
            approval._post_json = lambda url, api_key, payload, timeout: {
                "textResponse": json.dumps({
                    "decision": "APPROVE",
                    "summary": "Read-only capability is acceptable.",
                    "risk": "low",
                    "reasons": ["Allowlisted and read-only."],
                })
            }

            unsupported_review = client.post(
                "/agent/approval/review",
                json={
                    "capability": "project-files",
                    "proposal": {
                        "read_only": True,
                        "task": "List bounded project file metadata.",
                    },
                },
                headers=local_origin,
            )
            assert unsupported_review.status_code == 422
            assert unsupported_review.get_json()["ok"] is False

            review = client.post(
                "/agent/approval/review",
                json={
                    "capability": "system-inventory",
                    "proposal": {
                        "read_only": True,
                        "task": "Read fixed local system inventory.",
                    },
                },
                headers=local_origin,
            )
            assert review.status_code == 200
            review_data = review.get_json()
            assert review_data["decision"] == "APPROVE"
            token = review_data["approval_id"]
            assert token

            wrong_capability = client.post(
                "/agent/run",
                json={"capability": "project-files", "approval_id": token},
                headers=local_origin,
            )
            assert wrong_capability.status_code == 400
            assert wrong_capability.get_json()["anythingllm_approval_supported"] is False

            approved_run = client.post(
                "/agent/run",
                json={"capability": "system-inventory", "approval_id": token},
                headers=local_origin,
            )
            assert approved_run.status_code == 200
            assert approved_run.get_json()["approval_source"] == "anythingllm"

            reused = client.post(
                "/agent/run",
                json={"capability": "system-inventory", "approval_id": token},
                headers=local_origin,
            )
            assert reused.status_code == 400

            arbitrary_review = client.post(
                "/agent/approval/review",
                json={
                    "capability": "cmd-del-all",
                    "proposal": {"read_only": False, "command": "cmd /c del *"},
                },
                headers=local_origin,
            )
            assert arbitrary_review.status_code == 422
        finally:
            approval._post_json = original_post_json
            if previous_workspace is None:
                os.environ.pop("RAH_ANYTHINGLLM_WORKSPACE", None)
            else:
                os.environ["RAH_ANYTHINGLLM_WORKSPACE"] = previous_workspace
            if previous_api_key is None:
                os.environ.pop("RAH_ANYTHINGLLM_API_KEY", None)
            else:
                os.environ["RAH_ANYTHINGLLM_API_KEY"] = previous_api_key
            if previous_base_url is None:
                os.environ.pop("RAH_ANYTHINGLLM_BASE_URL", None)
            else:
                os.environ["RAH_ANYTHINGLLM_BASE_URL"] = previous_base_url
            if previous_memory_config is None:
                os.environ.pop("RAH_PROJECT_MEMORY_CONFIG", None)
            else:
                os.environ["RAH_PROJECT_MEMORY_CONFIG"] = previous_memory_config

        original_chat = module._lm_chat
        try:
            module._lm_chat = lambda system, user, model="", max_tokens=1400: (
                f"Lokalt svar: {user[:40]}",
                model or "test-local-model",
            )
            council_payload = {
                "model": "",
                "max_tokens": 500,
                "messages": [
                    {"role": "system", "content": "Svar på norsk."},
                    {"role": "user", "content": "Lag ett kontrollert neste steg."},
                ],
            }
            for headers in (local_origin, file_origin, {}):
                response = client.post("/lm/chat", json=council_payload, headers=headers)
                assert response.status_code == 200
                data = response.get_json()
                assert data["ok"] is True
                assert data["model"] == "test-local-model"
                assert data["tools_executed"] is False
                assert data["automatic_actions"] is False
        finally:
            module._lm_chat = original_chat

        invalid = client.post(
            "/lm/chat",
            json={"messages": [{"role": "user", "content": [{"type": "text"}]}]},
            headers=local_origin,
        )
        assert invalid.status_code == 400

        arbitrary_agent = client.post(
            "/agent/run",
            json={"capability": "cmd /c del *", "confirm": True},
            headers=local_origin,
        )
        assert arbitrary_agent.status_code == 403
        assert arbitrary_agent.get_json()["arbitrary_commands"] is False

        pages = {
            "/vision/ui": b"RAH Raven Vision",
            "/vision/chatgpt.user.js": b"RAH Raven Vision",
            "/chronicle/ui": b"Raven Chronicle Live",
            "/chronicle/insights-ui": b"Raven Insights",
            "/chronicle/brief-ui": b"Raven Daily Brief",
            "/downloads/ui": b"RAH RAVEN VAULT",
        }
        for path, marker in pages.items():
            response = client.get(path)
            assert response.status_code == 200, path
            assert marker in response.data, path

        # User-facing launchers and diagnostics must stay on the canonical
        # Raven Core entrypoint/port. They must not silently regress to the
        # retired server.py:8765 path.
        start_bridge = Path("start-bridge.bat").read_text(encoding="utf-8")
        start_vision = Path("start-raven-vision.bat").read_text(encoding="utf-8")
        doctor_source = Path("doctor.py").read_text(encoding="utf-8")
        for text in (start_bridge, start_vision):
            assert "raven_bridge.py" in text
            assert ":18765" in text
            assert ":8765" not in text
        assert "http://127.0.0.1:18765" in doctor_source
        assert "http://127.0.0.1:8765" not in doctor_source
        assert "normalize_loopback_endpoint" in doctor_source
        assert "LOOPBACK_HOSTS" in doctor_source

        print("RAH Raven local-origin security, fixed App Launcher, monitor/area capture, ChatGPT bridge, Doctor loopback boundary, canonical 18765 launchers, Vision, Case, Council, Agent Runner and Raven Vault tests: OK")


if __name__ == "__main__":
    main()
