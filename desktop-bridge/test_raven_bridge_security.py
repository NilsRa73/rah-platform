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

        local = client.get("/chronicle/status", headers=local_origin)
        assert local.status_code == 200
        assert local.get_json()["ok"] is True

        no_origin = client.get("/chronicle/summary")
        assert no_origin.status_code == 200

        pages = {
            "/chronicle/ui": b"Raven Chronicle Live",
            "/chronicle/insights-ui": b"Raven Insights",
            "/chronicle/brief-ui": b"Raven Daily Brief",
        }
        for path, marker in pages.items():
            response = client.get(path)
            assert response.status_code == 200, path
            assert marker in response.data, path

        print("RAH Raven local-origin security tests: OK")


if __name__ == "__main__":
    main()
