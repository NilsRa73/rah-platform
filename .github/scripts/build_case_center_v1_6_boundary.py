from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

FROZEN = [
    "RAH-RAVEN-START.html",
    "RAH-RAVEN-CORE-DEMO.html",
    "RAH-RAVEN-VISION-CORE.html",
    "raven-vision-core.js",
    "RAH-RAVEN-COUNCIL.html",
    "raven-council.js",
    "RAH-RAVEN-AGENT-RUNNER.html",
    "desktop-bridge/agent_runner.py",
    "RAH-RAVEN-MEMORY-SYNC.html",
    "raven-chronicle-sync.js",
    "RAH-RAVEN-MISSION-CONTROL.html",
    "RAH-RAVEN-PROJECT.html",
    "RAH-RAVEN-NOW-V2.html",
    "RAH-RAVEN-CHRONICLE-LIVE.html",
    "desktop-bridge/server_v17.py",
    "index.html",
    "system-health-v1.7.js",
    "RAH-HOME-CONTROL.html",
    "raven-checkpoint-policy.js",
]

EXPECTED_CORE = {
    "raven_vision": "0.6",
    "raven_council": "0.3",
    "agent_runner": "0.3",
    "memory_sync": "0.2",
    "mission_control": "2.9",
    "project_focus": "2.4",
    "raven_core": "1.12",
    "raven_now": "2.17",
    "raven_studio": "2.8",
}


def p(path: str) -> Path:
    return ROOT / path


def digest(path: str) -> str:
    return hashlib.sha256(p(path).read_bytes()).hexdigest()


before = {path: digest(path) for path in FROZEN}

# Harden the legacy v1.6 bridge module that supplies Case Center helpers to the canonical bridge.
server_path = p("desktop-bridge/server_v16.py")
server = server_path.read_text(encoding="utf-8")
if "import urllib.parse" not in server:
    server = server.replace("import urllib.request\n", "import urllib.request\nimport urllib.parse\n", 1)

old_constants = '''APP_VERSION = "1.6.0"\nHOST = os.getenv("RAH_BRIDGE_HOST", "127.0.0.1")\nPORT = int(os.getenv("RAH_BRIDGE_PORT", "18765"))\nMAX_WIDTH = int(os.getenv("RAH_BRIDGE_MAX_WIDTH", "2200"))\nLM_BASE = os.getenv("RAH_LM_BASE", "http://127.0.0.1:1234")\nMAX_UPLOAD_BYTES = int(os.getenv("RAH_CASE_MAX_UPLOAD", str(25 * 1024 * 1024)))\n'''
new_constants = '''APP_VERSION = "1.6.0"\nCASE_CENTER_VERSION = "1.6.0"\nDIRECT_RUN_DISABLED = True\nLOOPBACK_HOSTS = {"127.0.0.1", "localhost", "::1"}\n\n\ndef _normalize_loopback_host(value: str) -> str:\n    host = str(value or "").strip().lower()\n    if host == "[::1]":\n        host = "::1"\n    if host not in LOOPBACK_HOSTS:\n        raise RuntimeError("RAH Desktop Bridge må bindes til en lokal loopback-adresse.")\n    return host\n\n\ndef _normalize_loopback_base(value: str, label: str = "lokal tjeneste") -> str:\n    raw = str(value or "").strip()\n    try:\n        parsed = urllib.parse.urlsplit(raw)\n        host = (parsed.hostname or "").lower()\n        port = parsed.port\n    except ValueError as exc:\n        raise RuntimeError(f"{label} har ugyldig lokal adresse.") from exc\n    if parsed.scheme not in {"http", "https"} or host not in LOOPBACK_HOSTS:\n        raise RuntimeError(f"{label} må bruke lokal loopback-adresse.")\n    if parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in {"", "/"}:\n        raise RuntimeError(f"{label} må bruke en ren lokal baseadresse uten credentials, query, fragment eller sti.")\n    shown_host = f"[{host}]" if ":" in host else host\n    shown_port = f":{port}" if port is not None else ""\n    return f"{parsed.scheme}://{shown_host}{shown_port}"\n\n\nHOST = _normalize_loopback_host(os.getenv("RAH_BRIDGE_HOST", "127.0.0.1"))\nPORT = int(os.getenv("RAH_BRIDGE_PORT", "18765"))\nMAX_WIDTH = int(os.getenv("RAH_BRIDGE_MAX_WIDTH", "2200"))\nLM_BASE = _normalize_loopback_base(os.getenv("RAH_LM_BASE", "http://127.0.0.1:1234"), "LM Studio")\nMAX_UPLOAD_BYTES = int(os.getenv("RAH_CASE_MAX_UPLOAD", str(25 * 1024 * 1024)))\n'''
if old_constants not in server:
    raise RuntimeError("server_v16 constants anchor missing")
server = server.replace(old_constants, new_constants, 1)

health_anchor = '            "case_center": True,\n'
if health_anchor not in server:
    raise RuntimeError("Case Center health anchor missing")
server = server.replace(health_anchor, health_anchor + '            "case_center_version": CASE_CENTER_VERSION,\n', 1)

server = server.replace(
    '<h1>🐦‍⬛ RAH Raven Local Case Center</h1>',
    '<h1>🐦‍⬛ RAH Raven Local Case Center v1.6</h1>',
    1,
)

old_main = '''if __name__ == "__main__":\n    print(f"RAH Raven Desktop Bridge v{APP_VERSION}")\n    print(f"Listening on http://{HOST}:{PORT}")\n    app.run(host=HOST, port=PORT, debug=False, threaded=True)\n'''
new_main = '''if __name__ == "__main__":\n    print(f"RAH Raven Desktop Bridge library v{APP_VERSION}")\n    print("Direkte oppstart av server_v16.py er deaktivert av sikkerhetsgrunner.")\n    print("Start desktop-bridge/raven_bridge.py via Raven one-click launcher i stedet.")\n    raise SystemExit(2)\n'''
if old_main not in server:
    raise RuntimeError("server_v16 direct-run anchor missing")
server = server.replace(old_main, new_main, 1)
server_path.write_text(server, encoding="utf-8")

# Retire the old persistent prototype. This file is now only an explicit launcher to canonical /case.
launcher = '''<!doctype html>\n<html lang="no">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width,initial-scale=1">\n<meta name="theme-color" content="#07080b">\n<title>RAH Raven Case Center v1.6</title>\n<style>\n:root{color-scheme:dark;--bg:#07080b;--panel:#12151b;--line:#5c4618;--gold:#f0cf75;--muted:#aaa392;--good:#76e3aa}\n*{box-sizing:border-box}body{margin:0;min-height:100vh;display:grid;place-items:center;padding:20px;background:radial-gradient(circle at 50% 0,#3b2a0c55,transparent 35%),var(--bg);color:#f5f1e8;font:16px/1.5 Segoe UI,Arial,sans-serif}.card{width:min(760px,100%);border:1px solid var(--line);border-radius:24px;padding:30px;background:linear-gradient(145deg,#17140d,#0c0d10);box-shadow:0 24px 70px #0009}h1{margin:0;color:var(--gold);font:900 clamp(32px,6vw,56px)/1 Georgia,serif}.kicker{color:#d6b55c;letter-spacing:.18em;text-transform:uppercase;font-size:11px;font-weight:800}.notice{margin:20px 0;padding:14px;border-left:4px solid var(--good);background:#0d1913;border-radius:10px;color:#c8e8d6}.actions{display:flex;gap:10px;flex-wrap:wrap;margin-top:22px}a{display:inline-flex;align-items:center;justify-content:center;min-height:48px;padding:11px 16px;border-radius:12px;border:1px solid #82641f;background:#181308;color:#ffe397;text-decoration:none;font-weight:800}a.primary{background:linear-gradient(135deg,#ffe99b,#b9831f);color:#171005;border:0}.meta{color:var(--muted);font-size:13px}.footer{margin-top:22px;color:#746d5f;font-size:11px}\n</style>\n</head>\n<body>\n<main class="card">\n<div class="kicker">RAH Raven · Local-first · Human review</div>\n<h1>Case Center v1.6</h1>\n<p>Case Center bruker den kanoniske lokale Raven Bridge-flaten. Denne launcher-siden leser, analyserer eller lagrer ingen dokumenttekst.</p>\n<div class="notice"><strong>Privat arbeidsflate:</strong> Dokumenter i den kanoniske Case Center-sesjonen holdes i nettleserens minne og serveren rapporterer <em>stored: false</em>. Analyse skjer først når du trykker på analyseknappen, og resultatet krever menneskelig kontroll.</div>\n<p class="meta">Start Raven med one-click launcheren først. Deretter åpner knappen under bare den lokale adressen <strong>127.0.0.1:18765/case</strong>.</p>\n<div class="actions">\n<a class="primary" href="http://127.0.0.1:18765/case">Åpne Local Case Center</a>\n<a href="RAH-RAVEN-START.html">Tilbake til Raven Studio</a>\n</div>\n<div class="footer">RAH Raven Case Center v1.6 · Ingen localStorage · Ingen automatisk sending · Ingen selvattestert «faglig godkjenning».</div>\n</main>\n</body>\n</html>\n'''
p("RAH-RAVEN-CASE-CENTER.html").write_text(launcher, encoding="utf-8")

manifest = {
    "product": "RAH Raven Case Center",
    "version": "1.6.0",
    "stage": "candidate",
    "released_at": "2026-08-14",
    "entry": "RAH-RAVEN-CASE-CENTER.html",
    "canonical_ui": "http://127.0.0.1:18765/case",
    "canonical_bridge_entrypoint": "desktop-bridge/raven_bridge.py",
    "backend_helpers": "desktop-bridge/server_v16.py",
    "local_only": True,
    "runtime_feature_change": False,
    "features": {
        "canonical_bridge_entry_only": True,
        "direct_server_v16_disabled": True,
        "bridge_bind_loopback_only": True,
        "lm_studio_loopback_only": True,
        "external_ai_endpoints": False,
        "legacy_launcher_document_storage": False,
        "legacy_launcher_localstorage": False,
        "canonical_server_persists_documents": False,
        "analysis_requires_explicit_click": True,
        "human_review_required": True,
        "professional_approval_self_attestation": False,
        "case_center_screen_capture": False,
        "automatic_sending": False,
        "capability_set_changed": False,
    },
    "next_milestone": "stable-gate",
}
p("RAH-RAVEN-CASE-CENTER-VERSION.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

master_path = p("RAH-RAVEN-VERSION.json")
master = json.loads(master_path.read_text(encoding="utf-8"))
assert master["release_gate"]["stable_components"] == EXPECTED_CORE
assert master["privacy"]["raven_chronicle_stable"] is True
assert master["privacy"]["system_health_stable"] is True
files = master["files"]
if "RAH-RAVEN-CASE-CENTER-VERSION.json" not in files:
    idx = files.index("RAH-RAVEN-CASE-CENTER.html") + 1
    files.insert(idx, "RAH-RAVEN-CASE-CENTER-VERSION.json")
master["privacy"].update({
    "case_center_version_synced": True,
    "case_center_canonical_bridge_entry_only": True,
    "case_center_direct_server_v16_disabled": True,
    "case_center_bridge_bind_loopback_only": True,
    "case_center_lm_studio_loopback_only": True,
    "case_center_external_ai_endpoints": False,
    "case_center_legacy_launcher_document_storage": False,
    "case_center_legacy_launcher_localstorage": False,
    "case_center_server_persists_documents": False,
    "case_center_analysis_requires_explicit_click": True,
    "case_center_human_review_required": True,
    "case_center_professional_approval_self_attestation": False,
    "case_center_automatic_sending": False,
    "case_center_stable": False,
})
master_path.write_text(json.dumps(master, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

backend_test = '''from __future__ import annotations\n\nimport io\nimport unittest\nfrom unittest.mock import patch\n\nfrom server_v16 import (\n    APP_VERSION,\n    CASE_CENTER_VERSION,\n    DIRECT_RUN_DISABLED,\n    _normalize_loopback_base,\n    _normalize_loopback_host,\n    app,\n)\n\n\nclass CaseCenterV16Tests(unittest.TestCase):\n    def setUp(self) -> None:\n        app.config.update(TESTING=True)\n        self.client = app.test_client()\n\n    def test_health_announces_case_center_version(self) -> None:\n        response = self.client.get("/health")\n        self.assertEqual(response.status_code, 200)\n        data = response.get_json()\n        self.assertTrue(data["ok"])\n        self.assertTrue(data["case_center"])\n        self.assertEqual(data["version"], APP_VERSION)\n        self.assertEqual(data["case_center_version"], CASE_CENTER_VERSION)\n        self.assertEqual(CASE_CENTER_VERSION, "1.6.0")\n\n    def test_direct_legacy_server_entrypoint_is_disabled(self) -> None:\n        self.assertTrue(DIRECT_RUN_DISABLED)\n\n    def test_loopback_host_boundary(self) -> None:\n        self.assertEqual(_normalize_loopback_host("127.0.0.1"), "127.0.0.1")\n        self.assertEqual(_normalize_loopback_host("localhost"), "localhost")\n        self.assertEqual(_normalize_loopback_host("[::1]"), "::1")\n        with self.assertRaises(RuntimeError):\n            _normalize_loopback_host("0.0.0.0")\n        with self.assertRaises(RuntimeError):\n            _normalize_loopback_host("192.168.1.20")\n\n    def test_local_ai_base_boundary(self) -> None:\n        self.assertEqual(_normalize_loopback_base("http://127.0.0.1:1234", "LM"), "http://127.0.0.1:1234")\n        self.assertEqual(_normalize_loopback_base("http://localhost:1234/", "LM"), "http://localhost:1234")\n        with self.assertRaises(RuntimeError):\n            _normalize_loopback_base("https://example.com", "LM")\n        with self.assertRaises(RuntimeError):\n            _normalize_loopback_base("http://user:pass@127.0.0.1:1234", "LM")\n        with self.assertRaises(RuntimeError):\n            _normalize_loopback_base("http://127.0.0.1:1234/v1", "LM")\n        with self.assertRaises(RuntimeError):\n            _normalize_loopback_base("http://127.0.0.1:1234?x=1", "LM")\n\n    def test_case_page_is_available_and_memory_only(self) -> None:\n        response = self.client.get("/case")\n        self.assertEqual(response.status_code, 200)\n        self.assertIn(b"RAH Raven Local Case Center v1.6", response.data)\n        self.assertIn(b"Menneskelig kontroll kreves", response.data)\n        self.assertNotIn(b"localStorage", response.data)\n        self.assertNotIn(b"sessionStorage", response.data)\n\n    def test_extract_plain_text_without_persisting(self) -> None:\n        response = self.client.post(\n            "/case/extract",\n            data={"file": (io.BytesIO("Dato 2026-08-06: Testnotat".encode("utf-8")), "notat.txt")},\n            content_type="multipart/form-data",\n        )\n        self.assertEqual(response.status_code, 200)\n        data = response.get_json()\n        self.assertTrue(data["ok"])\n        self.assertIn("Testnotat", data["text"])\n        self.assertFalse(data["stored"])\n        self.assertEqual(len(data["sha256"]), 64)\n\n    def test_analyze_requires_documents(self) -> None:\n        response = self.client.post("/case/analyze", json={"documents": []})\n        self.assertEqual(response.status_code, 400)\n        self.assertFalse(response.get_json()["ok"])\n\n    @patch("server_v16._lm_chat", return_value=("Kildebasert svar [K1]", "local-model"))\n    def test_completed_analysis_requires_human_review(self, _mock_chat) -> None:\n        response = self.client.post(\n            "/case/analyze",\n            json={"documents": [{"name": "notat.txt", "text": "2026-08-06 Test"}]},\n        )\n        self.assertEqual(response.status_code, 200)\n        data = response.get_json()\n        self.assertTrue(data["ok"])\n        self.assertTrue(data["human_review_required"])\n        self.assertFalse(data["stored"])\n\n\nif __name__ == "__main__":\n    unittest.main()\n'''
p("desktop-bridge/test_case_v16.py").write_text(backend_test, encoding="utf-8")

semantic_test = '''import assert from "node:assert/strict";\nimport fs from "node:fs";\n\nconst shell = fs.readFileSync("RAH-RAVEN-CASE-CENTER.html", "utf8");\nconst server = fs.readFileSync("desktop-bridge/server_v16.py", "utf8");\nconst component = JSON.parse(fs.readFileSync("RAH-RAVEN-CASE-CENTER-VERSION.json", "utf8"));\nconst master = JSON.parse(fs.readFileSync("RAH-RAVEN-VERSION.json", "utf8"));\n\nassert.match(shell, /Case Center v1\\.6/);\nassert.match(shell, /http:\\/\\/127\\.0\\.0\\.1:18765\\/case/);\nassert.doesNotMatch(shell, /localStorage|sessionStorage|SpeechRecognition|webkitSpeechRecognition/);\nassert.doesNotMatch(shell, /professionalApproved|approveProfessional|FAGLIG GODKJENT/);\nassert.doesNotMatch(shell, /fetch\\s*\\(/);\n\nassert.match(server, /CASE_CENTER_VERSION = "1\\.6\\.0"/);\nassert.match(server, /DIRECT_RUN_DISABLED = True/);\nassert.match(server, /_normalize_loopback_host/);\nassert.match(server, /_normalize_loopback_base/);\nassert.match(server, /case_center_version/);\nassert.doesNotMatch(server, /app\\.run\\(host=HOST, port=PORT/);\n\nassert.equal(component.product, "RAH Raven Case Center");\nassert.equal(component.version, "1.6.0");\nassert.equal(component.stage, "candidate");\nassert.equal(component.local_only, true);\nassert.equal(component.features.canonical_bridge_entry_only, true);\nassert.equal(component.features.direct_server_v16_disabled, true);\nassert.equal(component.features.bridge_bind_loopback_only, true);\nassert.equal(component.features.lm_studio_loopback_only, true);\nassert.equal(component.features.external_ai_endpoints, false);\nassert.equal(component.features.legacy_launcher_document_storage, false);\nassert.equal(component.features.legacy_launcher_localstorage, false);\nassert.equal(component.features.canonical_server_persists_documents, false);\nassert.equal(component.features.analysis_requires_explicit_click, true);\nassert.equal(component.features.human_review_required, true);\nassert.equal(component.features.professional_approval_self_attestation, false);\nassert.equal(component.features.automatic_sending, false);\nassert.equal(component.next_milestone, "stable-gate");\n\nconst stable = {raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};\nassert.deepEqual(master.release_gate.stable_components, stable);\nassert.equal(master.privacy.raven_chronicle_stable, true);\nassert.equal(master.privacy.system_health_stable, true);\nassert.equal(master.privacy.case_center_stable, false);\nassert.equal(master.privacy.case_center_canonical_bridge_entry_only, true);\nassert.equal(master.privacy.case_center_direct_server_v16_disabled, true);\nassert.equal(master.privacy.case_center_lm_studio_loopback_only, true);\nassert.equal(master.privacy.case_center_legacy_launcher_localstorage, false);\nassert.equal(master.privacy.case_center_professional_approval_self_attestation, false);\nconsole.log("RAH Raven Case Center v1.6 candidate contract passed.");\n'''
p("tests/raven-case-center-v16.test.mjs").write_text(semantic_test, encoding="utf-8")

after = {path: digest(path) for path in FROZEN}
changed_frozen = [path for path in FROZEN if before[path] != after[path]]
if changed_frozen:
    raise RuntimeError(f"Case Center candidate changed frozen Raven runtime(s): {changed_frozen}")

master = json.loads(master_path.read_text(encoding="utf-8"))
assert master["release_gate"]["stable_components"] == EXPECTED_CORE
assert master["privacy"]["raven_chronicle_stable"] is True
assert master["privacy"]["system_health_stable"] is True
print("Built Case Center v1.6 local-boundary candidate; frozen Raven surfaces preserved.")
