from __future__ import annotations

import importlib
import os
import tempfile


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-bridge-security-") as temp:
        os.environ["RAH_CHRONICLE_DIR"] = temp
        module = importlib.import_module("raven_bridge")
        module._foreground_window_safe = lambda: {
            "available": True,
            "platform": "Windows",
            "app": "test.exe",
            "title": "Testvindu",
            "pid": 123,
            "redacted": False,
        }
        client = module.app.test_client()

        foreign = client.get(
            "/chronicle/status",
            headers={"Origin": "https://example.invalid"},
        )
        assert foreign.status_code == 403

        local = client.get(
            "/chronicle/status",
            headers={"Origin": f"http://127.0.0.1:{module.PORT}"},
        )
        assert local.status_code == 200
        assert local.get_json()["ok"] is True

        no_origin = client.get("/chronicle/status")
        assert no_origin.status_code == 200

        ui = client.get("/chronicle/ui")
        assert ui.status_code == 200
        assert b"Raven Chronicle Live" in ui.data

        print("RAH Raven local-origin security tests: OK")


if __name__ == "__main__":
    main()
