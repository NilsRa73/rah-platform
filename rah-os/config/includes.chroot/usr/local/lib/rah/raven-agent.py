#!/usr/bin/env python3
import json
import os
import platform
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSION = "0.1.0-dev"
HOST = "127.0.0.1"
PORT = 18765


def system_payload():
    mem_kb = None
    try:
        with open('/proc/meminfo', 'r', encoding='utf-8') as f:
            for line in f:
                if line.startswith('MemTotal:'):
                    mem_kb = int(line.split()[1])
                    break
    except OSError:
        pass
    return {
        "hostname": socket.gethostname(),
        "os": "RAH OS Raven",
        "rah_version": VERSION,
        "kernel": platform.release(),
        "architecture": platform.machine(),
        "cpu_threads": os.cpu_count(),
        "memory_total_mb": round(mem_kb / 1024) if mem_kb else None,
    }


HOME = """<!doctype html>
<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<title>RAH Command Center</title>
<style>
:root{color-scheme:dark} body{margin:0;background:#080808;color:#eee;font:16px system-ui,Segoe UI,sans-serif}
main{max-width:960px;margin:8vh auto;padding:28px}.brand{color:#d8aa42;letter-spacing:.18em}
h1{font-size:48px;margin:.2em 0}.card{border:1px solid #8d6b25;background:#111;padding:20px;border-radius:14px;margin:16px 0}
.ok{color:#86d27a}.gold{color:#e3b94e} code{color:#e3b94e}</style></head>
<body><main><div class='brand'>RAH OS • RAVEN DEVELOPMENT EDITION</div><h1>Raven Command Center</h1>
<div class='card'><h2 class='ok'>● Raven Core online</h2><p>Local service: <code>127.0.0.1:18765</code></p></div>
<div class='card'><h2>v0.1 foundation</h2><p>KDE Plasma • Debian 13 Trixie • Raven local agent • RAH branding.</p>
<p class='gold'>Next: authenticated privilege broker, Vision, node control, app installer and RAH update service.</p></div>
<div class='card'><h2>System API</h2><p><a href='/health'>/health</a> · <a href='/system'>/system</a></p></div>
</main></body></html>"""


class Handler(BaseHTTPRequestHandler):
    def send_json(self, data, status=200):
        raw = json.dumps(data, indent=2).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path == '/health':
            return self.send_json({"status": "ok", "service": "rah-raven-agent", "version": VERSION})
        if self.path == '/system':
            return self.send_json(system_payload())
        if self.path == '/':
            raw = HOME.encode('utf-8')
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(raw)))
            self.end_headers()
            self.wfile.write(raw)
            return
        self.send_json({"error": "not_found"}, 404)

    def log_message(self, fmt, *args):
        pass


if __name__ == '__main__':
    ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
