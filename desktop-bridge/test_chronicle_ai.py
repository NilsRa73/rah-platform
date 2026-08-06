from __future__ import annotations

import importlib
import os
import tempfile


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-chronicle-ai-") as temp:
        os.environ["RAH_CHRONICLE_DIR"] = temp
        bridge = importlib.import_module("server_v17")
        insights = importlib.import_module("chronicle_insights")
        ai = importlib.import_module("chronicle_ai")

        ai._lm_chat = lambda system, user, model="", max_tokens=2200: (
            "DAGEN I KORTE TREKK\nTestbrief\n\nETT NESTE STEG\nFullfør testen.",
            "local-test-model",
        )

        client = bridge.app.test_client()
        manual = client.post(
            "/chronicle/event",
            json={
                "project": "RAH Test",
                "category": "decision",
                "privacy": "project",
                "title": "Bygg lokal Daily Brief",
                "note": "Test beslutning",
            },
        )
        assert manual.status_code == 200

        structured = client.get("/chronicle/brief?hours=24")
        assert structured.status_code == 200
        payload = structured.get_json()
        assert payload["ok"] is True
        assert any(
            item.get("title") == "Bygg lokal Daily Brief"
            for item in payload["brief"]["decisions"]
        )

        generated = client.post(
            "/chronicle/ai-brief",
            json={"hours": 24, "focus": "Test"},
        )
        assert generated.status_code == 200
        result = generated.get_json()
        assert result["ok"] is True
        assert result["model"] == "local-test-model"
        assert "Testbrief" in result["answer"]
        assert result["local_only"] is True
        assert result["human_review_required"] is True

        print("RAH Raven Chronicle AI tests: OK")


if __name__ == "__main__":
    main()
