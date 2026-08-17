import json
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse


class BridgeState:
    def __init__(self, status_provider):
        self.status_provider = status_provider


def make_handler(state):
    class Handler(BaseHTTPRequestHandler):
        server_version = "RAHRavenDailyDriver/1.0"

        def _send(self, code, data):
            raw = json.dumps(data, ensure_ascii=False).encode("utf-8")
            self.send_response(code)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(raw)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(raw)

        def do_GET(self):
            parsed = urlparse(self.path)
            if parsed.path == "/health":
                return self._send(200, {"ok": True, "service": "rah-raven-daily-driver"})
            if parsed.path == "/status":
                return self._send(200, state.status_provider())
            self._send(404, {"error": "not_found"})

        def do_POST(self):
            self._send(405, {"error": "read_only_bridge"})

        def log_message(self, fmt, *args):
            return
    return Handler


class LocalBridge:
    def __init__(self, status_provider, host="127.0.0.1", port=18767):
        if host not in {"127.0.0.1", "localhost"}:
            raise ValueError("Daily Driver bridge must bind to loopback")
        self.state = BridgeState(status_provider)
        self.server = ThreadingHTTPServer((host, int(port)), make_handler(self.state))
        self.thread = None

    def start(self):
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def stop(self):
        self.server.shutdown()
        self.server.server_close()
