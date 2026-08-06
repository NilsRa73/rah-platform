from __future__ import annotations

import importlib
import os
import tempfile


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-bridge-security-") as temp:
        os.environ["RAH_CHRONICLE_DIR"] = temp
        module = importlib.import_module("raven_bridge")
        client = module.app.test_client()
        foreign_origin = {"Origin": "https://example.invalid"}
        local_origin = {"Origin": f"http://127.0.0.1:{module.PORT}"}
        file_origin = {"Origin": "null"}

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
        ):
            foreign = client.post(path, json=payload, headers=foreign_origin)
            assert foreign.status_code == 403, path

        local = client.get("/chronicle/status", headers=local_origin)
        assert local.status_code == 200
        assert local.get_json()["ok"] is True

        no_origin = client.get("/chronicle/summary")
        assert no_origin.status_code == 200

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
        }
        for path, marker in pages.items():
            response = client.get(path)
            assert response.status_code == 200, path
            assert marker in response.data, path

        print("RAH Raven local-origin security, Vision, Case, Council and Agent Runner tests: OK")


if __name__ == "__main__":
    main()
