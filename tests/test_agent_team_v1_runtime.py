from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import rah_agent_bridge as bridge


class FabricHandler(BaseHTTPRequestHandler):
    raven_jobs: dict[str, dict] = {}

    def log_message(self, *_):
        return

    def send_json(self, code: int, obj):
        data = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/health":
            return self.send_json(200, {"ok": True})
        if self.path == "/agent/jobs/health":
            return self.send_json(200, {"ok": True, "ready": True, "elevated": True})
        if self.path == "/ai/health":
            return self.send_json(200, {"ok": True, "ready_providers": ["anythingllm"]})
        if self.path == "/ai/providers":
            return self.send_json(200, {"ok": True, "providers": [
                {"id": "anythingllm", "online": True, "ready": True, "detail": "mock authenticated"}
            ]})
        if self.path.startswith("/agent/jobs/"):
            job_id = self.path.rsplit("/", 1)[-1]
            job = self.raven_jobs.get(job_id)
            if not job:
                return self.send_json(404, {"ok": False, "error": "missing"})
            return self.send_json(200, {"ok": True, "job": job})
        return self.send_json(404, {"ok": False})

    def do_POST(self):
        n = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(n).decode("utf-8") or "{}")
        if self.path == "/ai/chat":
            provider = body.get("provider")
            if provider not in {"auto", "anythingllm", "lmstudio"}:
                return self.send_json(400, {"ok": False, "error": "bad provider"})
            return self.send_json(200, {
                "ok": True,
                "provider": "anythingllm",
                "workspace": body.get("workspace") or "rah-platform",
                "text": "RAH AGENT TEAM OK",
            })
        if self.path == "/agent/jobs":
            if body.get("capability") != "system-inventory" or body.get("confirm") is not True:
                return self.send_json(403, {"ok": False, "error": "capability rejected"})
            job_id = "mock-raven-1"
            self.raven_jobs[job_id] = {
                "id": job_id,
                "capability": "system-inventory",
                "status": "completed",
                "read_only": True,
                "result": {"ok": True, "hostname": "CI-MOCK"},
            }
            return self.send_json(202, {"ok": True, "accepted": True, "job": {"id": job_id}})
        return self.send_json(404, {"ok": False})


def request_json(url: str, *, method="GET", body=None, token=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=10) as r:
        raw = r.read().decode("utf-8")
        return json.loads(raw) if raw else {}


def run_once(worker_path: Path, bridge_url: str, fabric_url: str, token_file: Path, state_file: Path):
    cp = subprocess.run(
        [
            sys.executable, str(worker_path),
            "--bridge", bridge_url,
            "--fabric", fabric_url,
            "--token-file", str(token_file),
            "--state-file", str(state_file),
            "--poll-seconds", "0.2",
            "--once",
        ],
        cwd=str(ROOT),
        capture_output=True,
        text=True,
        timeout=40,
    )
    if cp.returncode != 0:
        raise RuntimeError(f"worker failed: {cp.returncode}\nSTDOUT={cp.stdout}\nSTDERR={cp.stderr}")


def main():
    worker_path = ROOT / "rah_agent_worker.py"
    subprocess.run([sys.executable, "-m", "py_compile", str(worker_path)], check=True)
    subprocess.run([sys.executable, str(worker_path), "--self-test"], check=True)

    with tempfile.TemporaryDirectory(prefix="rah-agent-team-") as tmp:
        base = Path(tmp)
        bus = bridge.JobBus(base / "bus")
        token_file = base / "bridge-token.txt"
        token = bridge.load_or_create_token(token_file)

        bserver = bridge.BridgeServer(("127.0.0.1", 0), bridge.Handler, bus, token)
        bthread = threading.Thread(target=bserver.serve_forever, daemon=True)
        bthread.start()
        bridge_url = f"http://127.0.0.1:{bserver.server_address[1]}"

        fserver = ThreadingHTTPServer(("127.0.0.1", 0), FabricHandler)
        fthread = threading.Thread(target=fserver.serve_forever, daemon=True)
        fthread.start()
        fabric_url = f"http://127.0.0.1:{fserver.server_address[1]}"

        try:
            # AI route
            q = request_json(
                bridge_url + "/v1/jobs/enqueue",
                method="POST",
                token=token,
                body={"kind": "agent.message", "source": "ci", "payload": {"message": "hello"}},
            )
            ai_id = q["job"]["id"]
            run_once(worker_path, bridge_url, fabric_url, token_file, base / "worker-state.json")
            ai_doc = json.loads((base / "bus" / "results" / f"{ai_id}.json").read_text(encoding="utf-8"))
            assert ai_doc["status"] == "completed"
            assert ai_doc["result"]["route"] == "ai-fabric"
            assert ai_doc["result"]["provider"] == "anythingllm"
            assert ai_doc["result"]["text"] == "RAH AGENT TEAM OK"

            # Raven route
            q = request_json(
                bridge_url + "/v1/jobs/enqueue",
                method="POST",
                token=token,
                body={"kind": "system.inventory", "source": "ci", "payload": {}},
            )
            raven_id = q["job"]["id"]
            run_once(worker_path, bridge_url, fabric_url, token_file, base / "worker-state.json")
            raven_doc = json.loads((base / "bus" / "results" / f"{raven_id}.json").read_text(encoding="utf-8"))
            assert raven_doc["status"] == "completed"
            assert raven_doc["result"]["route"] == "raven"
            assert raven_doc["result"]["capability"] == "system-inventory"
            assert raven_doc["result"]["readOnly"] is True

            state = json.loads((base / "worker-state.json").read_text(encoding="utf-8"))
            assert state["version"] == "1.0.0"
            assert state["execCapability"] is False
        finally:
            bserver.shutdown()
            bserver.server_close()
            fserver.shutdown()
            fserver.server_close()

    print("PASS: RAH Agent Team v1 dual-route runtime")


if __name__ == "__main__":
    main()
