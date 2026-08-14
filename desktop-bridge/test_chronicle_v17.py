from __future__ import annotations

import importlib
import os
import tempfile


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-chronicle-test-") as temp:
        os.environ["RAH_CHRONICLE_DIR"] = temp
        module = importlib.import_module("server_v17")
        reads = {"count": 0}

        def fake_foreground_window_safe():
            reads["count"] += 1
            return {
                "available": True,
                "platform": "Windows",
                "app": "test.exe",
                "title": "Testvindu",
                "pid": 123,
                "redacted": False,
            }

        module._foreground_window_safe = fake_foreground_window_safe
        assert module.CHRONICLE_VERSION == "1.7.0"
        client = module.app.test_client()

        status = client.get("/chronicle/status")
        assert status.status_code == 200
        assert status.get_json()["ok"] is True
        status_data = status.get_json()
        assert status_data["recording"] is False
        assert status_data["active_window"]["available"] is False
        assert status_data["active_window"]["observation_allowed"] is False
        assert status_data["safeguards"]["foreground_read_requires_active_session"] is True
        assert status_data["safeguards"]["paused_blocks_foreground_read"] is True
        assert reads["count"] == 0
        stopped_window = client.get("/chronicle/active-window").get_json()["window"]
        assert stopped_window["available"] is False
        assert reads["count"] == 0

        started = client.post(
            "/chronicle/session/start",
            json={"project": "RAH Test", "mode": "work"},
        )
        assert started.status_code == 200
        assert started.get_json()["session"]["project"] == "RAH Test"
        running_status = client.get("/chronicle/status").get_json()
        assert running_status["active_window"]["available"] is True
        assert running_status["active_window"]["observation_allowed"] is True
        assert reads["count"] == 1

        manual = client.post(
            "/chronicle/event",
            json={"title": "Testhendelse", "category": "decision", "note": "OK"},
        )
        assert manual.status_code == 200

        paused = client.post("/chronicle/pause")
        assert paused.status_code == 200
        paused_status = client.get("/chronicle/status").get_json()
        assert paused_status["active_window"]["available"] is False
        assert paused_status["active_window"]["observation_allowed"] is False
        assert reads["count"] == 1
        paused_window = client.get("/chronicle/active-window").get_json()["window"]
        assert paused_window["available"] is False
        assert reads["count"] == 1
        resumed = client.post("/chronicle/resume")
        assert resumed.status_code == 200
        resumed_status = client.get("/chronicle/status").get_json()
        assert resumed_status["active_window"]["available"] is True
        assert reads["count"] == 2

        stopped = client.post("/chronicle/session/stop")
        assert stopped.status_code == 200
        final_status = client.get("/chronicle/status").get_json()
        assert final_status["active_window"]["available"] is False
        assert reads["count"] == 2

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
