from __future__ import annotations

import importlib
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
        assert health_data["download_manager"] is True
        assert health_data["download_manager_mode"] == "chatgpt-expected-only"

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
            "/lm/models",
            "/case",
            "/agent/capabilities",
            "/downloads/status",
            "/downloads/recent",
            "/downloads/search?q=pdf",
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
            ("/downloads/expect", {"filename": "test.pdf", "source": "chatgpt"}),
            ("/downloads/scan", {"confirm": True}),
            ("/downloads/open-vault", {"confirm": True}),
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

        agent_caps = client.get("/agent/capabilities", headers=file_origin)
        assert agent_caps.status_code == 200
        agent_data = agent_caps.get_json()
        assert agent_data["mode"] == "read-only-allowlist"
        assert agent_data["arbitrary_commands"] is False
        assert agent_data["file_writes"] is False
        assert agent_data["automatic_execution"] is False

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

        print("RAH Raven local-origin security, Doctor loopback boundary, canonical 18765 launchers, Vision, Case, Council, Agent Runner and Raven Vault tests: OK")


if __name__ == "__main__":
    main()
