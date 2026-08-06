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

        for path in (
            "/chronicle/status",
            "/chronicle/events",
            "/chronicle/summary",
            "/chronicle/brief",
        ):
            foreign = client.get(path, headers=foreign_origin)
            assert foreign.status_code == 403, path

        foreign_ai = client.post(
            "/chronicle/ai-brief",
            json={"hours": 24},
            headers=foreign_origin,
        )
        assert foreign_ai.status_code == 403

        foreign_council = client.post(
            "/lm/chat",
            json={"messages": [{"role": "user", "content": "test"}]},
            headers=foreign_origin,
        )
        assert foreign_council.status_code == 403

        local = client.get("/chronicle/status", headers=local_origin)
        assert local.status_code == 200
        assert local.get_json()["ok"] is True

        no_origin = client.get("/chronicle/summary")
        assert no_origin.status_code == 200

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

        pages = {
            "/chronicle/ui": b"Raven Chronicle Live",
            "/chronicle/insights-ui": b"Raven Insights",
            "/chronicle/brief-ui": b"Raven Daily Brief",
        }
        for path, marker in pages.items():
            response = client.get(path)
            assert response.status_code == 200, path
            assert marker in response.data, path

        print("RAH Raven local-origin security and Council proxy tests: OK")


if __name__ == "__main__":
    main()
