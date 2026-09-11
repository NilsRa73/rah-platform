from __future__ import annotations

import datetime as dt
import json
import os
import sqlite3
import threading
import time
import urllib.error
import urllib.request
from collections import defaultdict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

APP_DIR = Path(os.environ.get("RAH_CHRONICLE_HOME", r"C:\RAH\Chronicle"))
DATA_DIR = APP_DIR / "Data"
REPORT_DIR = APP_DIR / "Reports"
LOG_DIR = APP_DIR / "Logs"
DB_PATH = DATA_DIR / "chronicle.db"
HOST = "127.0.0.1"
PORT = int(os.environ.get("RAH_CHRONICLE_PORT", "18766"))
REPORT_HOUR = int(os.environ.get("RAH_CHRONICLE_REPORT_HOUR", "23"))
REPORT_MINUTE = int(os.environ.get("RAH_CHRONICLE_REPORT_MINUTE", "50"))

for p in (APP_DIR, DATA_DIR, REPORT_DIR, LOG_DIR):
    p.mkdir(parents=True, exist_ok=True)


def log(message: str) -> None:
    stamp = dt.datetime.now().isoformat(timespec="seconds")
    line = f"[{stamp}] {message}"
    print(line, flush=True)
    try:
        with (LOG_DIR / "chronicle.log").open("a", encoding="utf-8") as f:
            f.write(line + "\n")
    except OSError:
        pass


def db() -> sqlite3.Connection:
    con = sqlite3.connect(DB_PATH, timeout=10)
    con.execute("PRAGMA journal_mode=WAL")
    con.execute(
        """
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts REAL NOT NULL,
            event_type TEXT NOT NULL,
            reason TEXT,
            tab_id INTEGER,
            domain TEXT,
            url TEXT,
            title TEXT,
            duration_s INTEGER NOT NULL DEFAULT 0,
            work INTEGER NOT NULL DEFAULT 0
        )
        """
    )
    con.execute("CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts)")
    con.commit()
    return con


def clean_text(value, limit=600) -> str:
    text = str(value or "").replace("\x00", "").strip()
    return text[:limit]


def normalize_event(raw: dict) -> dict:
    now = time.time()
    try:
        ts = float(raw.get("ts", now))
    except (TypeError, ValueError):
        ts = now
    if abs(ts - now) > 86400 * 7:
        ts = now
    try:
        duration = max(0, min(int(raw.get("duration_s", 0)), 86400))
    except (TypeError, ValueError):
        duration = 0
    try:
        tab_id = int(raw["tab_id"]) if raw.get("tab_id") is not None else None
    except (TypeError, ValueError):
        tab_id = None
    return {
        "ts": ts,
        "event_type": clean_text(raw.get("type", "unknown"), 40),
        "reason": clean_text(raw.get("reason", ""), 80),
        "tab_id": tab_id,
        "domain": clean_text(raw.get("domain", ""), 255).lower(),
        "url": clean_text(raw.get("url", ""), 1000),
        "title": clean_text(raw.get("title", ""), 500),
        "duration_s": duration,
        "work": 1 if bool(raw.get("work")) else 0,
    }


def store_event(raw: dict) -> None:
    e = normalize_event(raw)
    with db() as con:
        con.execute(
            """
            INSERT INTO events(ts,event_type,reason,tab_id,domain,url,title,duration_s,work)
            VALUES(:ts,:event_type,:reason,:tab_id,:domain,:url,:title,:duration_s,:work)
            """,
            e,
        )


def day_bounds(day: dt.date) -> tuple[float, float]:
    start = dt.datetime.combine(day, dt.time.min).timestamp()
    end = dt.datetime.combine(day + dt.timedelta(days=1), dt.time.min).timestamp()
    return start, end


def aggregate(day: dt.date) -> dict:
    start, end = day_bounds(day)
    with db() as con:
        rows = con.execute(
            """
            SELECT domain, title, url, SUM(duration_s) AS seconds, MAX(work) AS work, COUNT(*) AS events
            FROM events
            WHERE ts >= ? AND ts < ? AND event_type = 'focus_end' AND duration_s > 0
            GROUP BY domain, title, url
            ORDER BY seconds DESC
            """,
            (start, end),
        ).fetchall()

    by_domain = defaultdict(int)
    total = 0
    work_total = 0
    items = []
    for domain, title, url, seconds, work, events in rows:
        seconds = int(seconds or 0)
        total += seconds
        if work:
            work_total += seconds
        by_domain[domain or "unknown"] += seconds
        items.append({
            "domain": domain or "unknown",
            "title": title or "Untitled",
            "url": url or "",
            "seconds": seconds,
            "work": bool(work),
            "events": int(events or 0),
        })

    return {
        "date": day.isoformat(),
        "total_seconds": total,
        "work_seconds": work_total,
        "domains": sorted(by_domain.items(), key=lambda x: x[1], reverse=True),
        "items": items[:50],
    }


def fmt_duration(seconds: int) -> str:
    seconds = max(0, int(seconds))
    h, rem = divmod(seconds, 3600)
    m, _ = divmod(rem, 60)
    if h:
        return f"{h}t {m:02d}m"
    return f"{m}m"


def deterministic_report(data: dict) -> str:
    date = data["date"]
    total = data["total_seconds"]
    work_total = data["work_seconds"]
    top_domains = data["domains"][:8]
    top_items = [x for x in data["items"] if x["work"]][:10]

    lines = [
        f"# RAH Chronicle — Daily Report {date}",
        "",
        "## Summary",
        f"- Tracked active-tab time: **{fmt_duration(total)}**",
        f"- Work-domain time: **{fmt_duration(work_total)}**",
        f"- Work share: **{round((work_total / total * 100), 1) if total else 0}%**",
        "",
        "## Top domains",
    ]
    if top_domains:
        for domain, seconds in top_domains:
            lines.append(f"- **{domain}** — {fmt_duration(seconds)}")
    else:
        lines.append("- No tracked activity yet.")

    lines.extend(["", "## Main work tabs"])
    if top_items:
        for item in top_items:
            lines.append(f"- **{item['title']}** — {item['domain']} — {fmt_duration(item['seconds'])}")
    else:
        lines.append("- No allowlisted work-tab sessions recorded.")

    chatgpt = sum(s for d, s in data["domains"] if d == "chatgpt.com" or d.endswith(".chatgpt.com"))
    github = sum(s for d, s in data["domains"] if d == "github.com" or d.endswith(".github.com"))
    cloudflare = sum(s for d, s in data["domains"] if "cloudflare.com" in d)
    lines.extend([
        "",
        "## RAH signals",
        f"- ChatGPT: {fmt_duration(chatgpt)}",
        f"- GitHub: {fmt_duration(github)}",
        f"- Cloudflare: {fmt_duration(cloudflare)}",
        "",
        "## Suggested next move",
    ])
    if github + cloudflare > 0:
        lines.append("Continue from the most active RAH implementation thread and convert unfinished browser work into one concrete build/test batch.")
    elif chatgpt > 0:
        lines.append("Turn today's strongest ChatGPT planning thread into a concrete RAH task, code change, or verified checklist tomorrow.")
    else:
        lines.append("Open the RAH work domains you want Chronicle to recognize, or add them in the extension settings.")

    lines.extend([
        "",
        "---",
        "Generated locally by RAH Chronicle. Page body text, passwords, form fields, and incognito tabs are not collected by v1.",
    ])
    return "\n".join(lines) + "\n"


def ai_report(data: dict, fallback: str) -> str:
    mode = os.environ.get("RAH_AI_MODE", "off").strip().lower()
    base = os.environ.get("RAH_AI_BASE_URL", "").rstrip("/")
    model = os.environ.get("RAH_AI_MODEL", "").strip()
    key = os.environ.get("RAH_AI_API_KEY", "").strip()
    if mode != "openai_compatible" or not base or not model:
        return fallback

    compact = {
        "date": data["date"],
        "tracked": fmt_duration(data["total_seconds"]),
        "work": fmt_duration(data["work_seconds"]),
        "domains": [{"domain": d, "time": fmt_duration(s)} for d, s in data["domains"][:10]],
        "work_tabs": [
            {"title": x["title"], "domain": x["domain"], "time": fmt_duration(x["seconds"])}
            for x in data["items"] if x["work"]
        ][:12],
    }
    prompt = (
        "Write a concise Norwegian daily work report for RAH AI Studios. "
        "Use only the aggregated activity supplied. Separate: what was worked on, likely progress, unfinished threads, "
        "and the 3 best next actions. Do not invent completed work. Return Markdown.\n\n"
        + json.dumps(compact, ensure_ascii=False)
    )
    payload = json.dumps({
        "model": model,
        "messages": [
            {"role": "system", "content": "You are the RAH Chronicle daily work summarizer."},
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.2,
    }).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if key:
        headers["Authorization"] = f"Bearer {key}"
    req = urllib.request.Request(base + "/chat/completions", data=payload, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read().decode("utf-8"))
        text = result["choices"][0]["message"]["content"].strip()
        if text:
            return text + "\n\n---\nAI summary generated from aggregated RAH Chronicle activity only.\n"
    except (urllib.error.URLError, urllib.error.HTTPError, KeyError, IndexError, ValueError) as exc:
        log(f"AI summary unavailable; using local report: {exc}")
    return fallback


def report_path(day: dt.date) -> Path:
    return REPORT_DIR / f"RAH-Chronicle-{day.isoformat()}.md"


def generate_report(day: dt.date, force: bool = False) -> Path:
    path = report_path(day)
    if path.exists() and not force:
        return path
    data = aggregate(day)
    base = deterministic_report(data)
    text = ai_report(data, base)
    path.write_text(text, encoding="utf-8")
    (REPORT_DIR / "latest.md").write_text(text, encoding="utf-8")
    log(f"Generated daily report: {path}")
    return path


def ensure_missed_report() -> None:
    yesterday = dt.date.today() - dt.timedelta(days=1)
    if not report_path(yesterday).exists():
        generate_report(yesterday)


def scheduler() -> None:
    ensure_missed_report()
    done_for = None
    while True:
        now = dt.datetime.now()
        if now.hour == REPORT_HOUR and now.minute >= REPORT_MINUTE and done_for != now.date():
            generate_report(now.date(), force=True)
            done_for = now.date()
        time.sleep(20)


def escape_html(text: str) -> str:
    return str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;")


def dashboard_html() -> str:
    data = aggregate(dt.date.today())
    top = data["domains"][:7]
    rows = "".join(f"<tr><td>{escape_html(d)}</td><td>{fmt_duration(s)}</td></tr>" for d, s in top) or "<tr><td colspan='2'>No activity yet</td></tr>"
    return f"""<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<title>RAH Chronicle</title><style>
:root{{color-scheme:dark;--bg:#080705;--panel:#151109;--gold:#d7ad45;--text:#f7f1e4;--muted:#aaa197;--line:#47391c}}
body{{margin:0;background:radial-gradient(circle at top,#2b1f09,#080705 42%);color:var(--text);font:16px/1.5 system-ui,Segoe UI,sans-serif}}
main{{max-width:980px;margin:0 auto;padding:36px 20px}}h1{{font-size:44px;margin:0;color:var(--gold)}}.sub{{color:var(--muted)}}
.grid{{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin:24px 0}}.card{{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:18px}}
.big{{font-size:28px;font-weight:800;color:var(--gold)}}table{{width:100%;border-collapse:collapse}}td{{padding:10px;border-bottom:1px solid #2a2418}}a{{color:#f1ce75}}
@media(max-width:700px){{.grid{{grid-template-columns:1fr}}}}</style></head><body><main>
<h1>RAH CHRONICLE</h1><p class='sub'>Local work telemetry · privacy-first · port {PORT}</p>
<div class='grid'><div class='card'><div class='sub'>Tracked today</div><div class='big'>{fmt_duration(data['total_seconds'])}</div></div>
<div class='card'><div class='sub'>Work domains</div><div class='big'>{fmt_duration(data['work_seconds'])}</div></div>
<div class='card'><div class='sub'>Reports</div><div class='big'>{len(list(REPORT_DIR.glob('RAH-Chronicle-*.md')))}</div></div></div>
<div class='card'><h2>Top domains</h2><table>{rows}</table></div>
<p><a href='/report/today'>Open today's report</a> · <a href='/health'>Health JSON</a></p>
</main></body></html>"""


class Handler(BaseHTTPRequestHandler):
    server_version = "RAHChronicle/0.1"

    def log_message(self, fmt, *args):
        return

    def _headers(self, status=200, content_type="application/json; charset=utf-8"):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.end_headers()

    def do_OPTIONS(self):
        self._headers(204)

    def do_GET(self):
        if self.path == "/health":
            self._headers()
            self.wfile.write(json.dumps({"ok": True, "service": "RAH Chronicle", "version": "0.1.0", "db": str(DB_PATH)}).encode())
            return
        if self.path == "/api/today":
            self._headers()
            self.wfile.write(json.dumps(aggregate(dt.date.today()), ensure_ascii=False).encode("utf-8"))
            return
        if self.path == "/report/today":
            path = generate_report(dt.date.today(), force=True)
            self._headers(200, "text/markdown; charset=utf-8")
            self.wfile.write(path.read_bytes())
            return
        if self.path == "/":
            self._headers(200, "text/html; charset=utf-8")
            self.wfile.write(dashboard_html().encode("utf-8"))
            return
        self._headers(404)
        self.wfile.write(b'{"error":"not found"}')

    def do_POST(self):
        if self.path != "/event":
            self._headers(404)
            self.wfile.write(b'{"error":"not found"}')
            return
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 65536)
            raw = json.loads(self.rfile.read(length).decode("utf-8"))
            if not isinstance(raw, dict):
                raise ValueError("event must be object")
            store_event(raw)
            self._headers(202)
            self.wfile.write(b'{"ok":true}')
        except Exception as exc:
            self._headers(400)
            self.wfile.write(json.dumps({"ok": False, "error": clean_text(exc, 200)}).encode("utf-8"))


def main() -> None:
    db().close()
    threading.Thread(target=scheduler, daemon=True, name="rah-chronicle-scheduler").start()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    log(f"RAH Chronicle listening on http://{HOST}:{PORT}")
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        log("RAH Chronicle stopped")


if __name__ == "__main__":
    main()
