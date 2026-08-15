#!/usr/bin/env python3
"""RAH Node Agent v0.1 — explicit, read-only device enrollment endpoint.

Default bind is loopback. Pass --allow-lan to bind on the LAN. The agent exposes
only GET /health and CORS preflight for the local Command Center. A fresh bearer
token is generated in memory on every start and is never written to disk.
"""

from __future__ import annotations

import argparse
import hmac
import json
import platform
import secrets
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Callable

AGENT_VERSION = "0.1.0"
PROTOCOL = "rah-node-health-v1"
PORT = 18766
ALLOWED_ORIGINS = {"null", "http://127.0.0.1:18765", "http://localhost:18765"}


def clean_text(value: str | None, limit: int) -> str:
    text = " ".join((value or "").split())
    return text[:limit]


def build_health_payload(node_name: str = "", node_role: str = "") -> dict:
    return {
        "protocol": PROTOCOL,
        "agentVersion": AGENT_VERSION,
        "status": "ready",
        "hostname": clean_text(socket.gethostname(), 80) or "Unknown host",
        "platform": clean_text(platform.system(), 80) or "Unknown platform",
        "platformRelease": clean_text(platform.release(), 80),
        "machine": clean_text(platform.machine(), 40),
        "nodeName": clean_text(node_name, 80),
        "nodeRole": clean_text(node_role, 100),
    }


def is_authorized(header_value: str | None, token: str) -> bool:
    prefix = "Bearer "
    if not header_value or not header_value.startswith(prefix):
        return False
    candidate = header_value[len(prefix):]
    return hmac.compare_digest(candidate, token)


def make_handler(token: str, node_name: str = "", node_role: str = "") -> type[BaseHTTPRequestHandler]:
    payload_factory: Callable[[], dict] = lambda: build_health_payload(node_name, node_role)

    class Handler(BaseHTTPRequestHandler):
        server_version = "RAHNodeAgent/0.1"
        sys_version = ""

        def log_message(self, fmt: str, *args) -> None:
            return

        def _origin(self) -> str:
            return self.headers.get("Origin", "")

        def _origin_allowed(self) -> bool:
            return self._origin() in ALLOWED_ORIGINS

        def _cors(self) -> None:
            origin = self._origin()
            if origin in ALLOWED_ORIGINS:
                self.send_header("Access-Control-Allow-Origin", origin)
                self.send_header("Vary", "Origin")
                self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
                self.send_header("Access-Control-Allow-Headers", "Authorization, Content-Type")
                if self.headers.get("Access-Control-Request-Private-Network", "").lower() == "true":
                    self.send_header("Access-Control-Allow-Private-Network", "true")

        def _json(self, status: int, body: dict) -> None:
            data = json.dumps(body, separators=(",", ":")).encode("utf-8")
            self.send_response(status)
            self._cors()
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.end_headers()
            self.wfile.write(data)

        def do_OPTIONS(self) -> None:
            if self.path != "/health" or not self._origin_allowed():
                self._json(403, {"error": "forbidden"})
                return
            self.send_response(204)
            self._cors()
            self.send_header("Content-Length", "0")
            self.end_headers()

        def do_GET(self) -> None:
            if self.path != "/health":
                self._json(404, {"error": "not_found"})
                return
            if not self._origin_allowed():
                self._json(403, {"error": "origin_not_allowed"})
                return
            if not is_authorized(self.headers.get("Authorization"), token):
                self._json(401, {"error": "unauthorized"})
                return
            self._json(200, payload_factory())

        def do_POST(self) -> None:
            self._json(405, {"error": "method_not_allowed"})

        def do_PUT(self) -> None:
            self._json(405, {"error": "method_not_allowed"})

        def do_DELETE(self) -> None:
            self._json(405, {"error": "method_not_allowed"})

    return Handler


def create_server(host: str, port: int, token: str, node_name: str = "", node_role: str = "") -> ThreadingHTTPServer:
    return ThreadingHTTPServer((host, port), make_handler(token, node_name, node_role))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="RAH Node Agent — read-only health enrollment endpoint")
    parser.add_argument("--allow-lan", action="store_true", help="Explicitly bind to LAN interfaces instead of loopback")
    parser.add_argument("--name", default="", help="Optional display name returned in /health")
    parser.add_argument("--role", default="", help="Optional role returned in /health")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    host = "0.0.0.0" if args.allow_lan else "127.0.0.1"
    token = secrets.token_urlsafe(32)
    server = create_server(host, PORT, token, args.name, args.role)

    print("RAH Node Agent v%s" % AGENT_VERSION)
    print("Mode: %s" % ("LAN enrollment enabled" if args.allow_lan else "loopback only"))
    print("Port: %s" % PORT)
    print("Enrollment token (memory only; changes on restart):")
    print(token)
    print("Only GET /health exists. No shell, commands, files or remote control endpoints are exposed.")
    if args.allow_lan:
        print("If a firewall prompt appears, allow Private networks only.")
    print("Press Ctrl+C to stop the agent.")

    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
