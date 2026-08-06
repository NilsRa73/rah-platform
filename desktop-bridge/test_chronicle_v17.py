from __future__ import annotations

import importlib
import os
import tempfile


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-chronicle-test-") as temp:
        os.environ["RAH_CHRONICLE_DIR"] = temp
        module = importlib.import_module("server_v17")
        module._foreground_window_safe = lambda: {
            "available": True,
            "platform": "Windows",
            "app": "test.exe",
            "title": "Testvindu",
            "pid": 123,
            "redacted": False,
        }
        client = module.app.test_client()

        status = client.get("/chronicle/status")
        assert status.status_code == 200
        assert status.get_json()["ok"] is True
        assert status.get_json()["recording"] is False

        started = client.post(
            "/chronicle/session/start",
            json={"project": "RAH Test", "mode": "work"},
        )
        assert started.status_code == 200
        assert started.get_json()["session"]["project"] == "RAH Test"

        manual = client.post(
            "/chronicle/event",
            json={"title": "Testhendelse", "category": "decision", "note": "OK"},
        )
        assert manual.status_code == 200

        paused = client.post("/chronicle/pause")
        assert paused.status_code == 200
        resumed = client.post("/chronicle/resume")
        assert resumed.status_code == 200

        stopped = client.post("/chronicle/session/stop")
        assert stopped.status_code == 200

        events = client.get("/chronicle/events?limit=50").get_json()["events"]
        assert any(item.get("title") == "Testhendelse" for item in events)
        assert any(item.get("type") == "session-start" for item in events)
        assert any(item.get("type") == "session-stop" for item in events)

        private = module._privacy_filter(
            {
                "available": True,
                "app": "firefox.exe",
                "title": "Min nettbank",
                "pid": 1,
                "platform": "Windows",
            },
            module.DEFAULT_CONFIG,
        )
        assert private["redacted"] is True
        assert "TITTEL IKKE LAGRET" in private["title"]

        print("RAH Raven Chronicle v1.7 tests: OK")


if __name__ == "__main__":
    main()
