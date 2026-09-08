from __future__ import annotations

import importlib
import os
import pathlib
import tempfile


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-file-index-") as temp:
        root = pathlib.Path(temp)
        (root / "Agents").mkdir()
        (root / "Agents" / "worker.json").write_text('{"secret":"content-must-not-be-read"}', encoding="utf-8")
        (root / "Logs").mkdir()
        (root / "Logs" / "raven.log").write_text("private log body", encoding="utf-8")
        deep = root / "A" / "B" / "C" / "D" / "E"
        deep.mkdir(parents=True)
        (deep / "too-deep.txt").write_text("do not index this deeply", encoding="utf-8")

        module = importlib.import_module("raven_bridge")
        indexer = module.agent_runner.rah_file_index

        bounded = indexer._index_root("test", root, max_entries=20, max_depth=4)
        assert bounded["exists"] is True
        assert bounded["contents_read"] is False
        assert bounded["symlinks_followed"] is False
        assert bounded["count"] <= 20
        paths = {item["path"] for item in bounded["entries"]}
        assert "Agents/worker.json" in paths
        assert "Logs/raven.log" in paths
        assert "A/B/C/D/E/too-deep.txt" not in paths
        assert all("content-must-not-be-read" not in str(item) for item in bounded["entries"])
        assert all("private log body" not in str(item) for item in bounded["entries"])

        client = module.app.test_client()
        local_origin = {"Origin": f"http://127.0.0.1:{module.PORT}"}
        foreign_origin = {"Origin": "https://example.invalid"}

        caps = client.get("/agent/capabilities", headers=local_origin).get_json()
        ids = {item["id"] for item in caps["capabilities"]}
        assert "rah-file-index" in ids

        missing_confirm = client.post(
            "/agent/run",
            json={"capability": "rah-file-index"},
            headers=local_origin,
        )
        assert missing_confirm.status_code == 400

        foreign = client.post(
            "/agent/run",
            json={"capability": "rah-file-index", "confirm": True},
            headers=foreign_origin,
        )
        assert foreign.status_code == 403

        response = client.post(
            "/agent/run",
            json={"capability": "rah-file-index", "confirm": True},
            headers=local_origin,
        )
        assert response.status_code == 200
        data = response.get_json()
        assert data["ok"] is True
        assert data["read_only"] is True
        assert data["files_modified"] is False
        assert data["automatic_actions"] is False
        assert data["tools_executed"] == ["rah-file-index"]
        assert data["command"] is None
        index = data["file_index"]
        assert index["contents_read"] is False
        assert index["symlinks_followed"] is False
        assert index["arbitrary_paths"] is False
        assert index["file_writes"] is False
        assert index["max_entries_per_root"] == 300
        assert index["max_depth"] == 4
        assert "CONTENTS    : NOT READ" in data["stdout"]
        assert "SAFETY      : READ ONLY" in data["stdout"]

        print("RAH fixed-root file metadata index boundary + API tests: OK")


if __name__ == "__main__":
    main()
