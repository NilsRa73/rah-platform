from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

FROZEN = [
    "RAH-RAVEN-CASE-CENTER.html",
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
EXPECTED_CORE={"raven_vision":"0.6","raven_council":"0.3","agent_runner":"0.3","memory_sync":"0.2","mission_control":"2.9","project_focus":"2.4","raven_core":"1.12","raven_now":"2.17","raven_studio":"2.8"}

def p(path:str)->Path:return ROOT/path
def digest(path:str)->str:return hashlib.sha256(p(path).read_bytes()).hexdigest()
before={path:digest(path) for path in FROZEN}

server_path=p("desktop-bridge/server_v16.py")
server=server_path.read_text(encoding="utf-8")
old='''app = Flask(__name__)\napp.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_BYTES\nCORS(app, resources={r"/*": {"origins": "*"}})\n\n\ndef _active_window_rect()'''
new='''LOCAL_BROWSER_ORIGINS = {\n    "null",\n    f"http://127.0.0.1:{PORT}",\n    f"http://localhost:{PORT}",\n    f"http://[::1]:{PORT}",\n}\nCASE_PROTECTED_PREFIXES = ("/capture/", "/lm/", "/case")\n\napp = Flask(__name__)\napp.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_BYTES\nCORS(app, resources={r"/*": {"origins": sorted(LOCAL_BROWSER_ORIGINS)}})\n\n\n@app.before_request\ndef protect_case_center_local_apis():\n    if not request.path.startswith(CASE_PROTECTED_PREFIXES):\n        return None\n    origin = (request.headers.get("Origin") or "").rstrip("/")\n    if origin and origin not in LOCAL_BROWSER_ORIGINS:\n        return jsonify({\n            "ok": False,\n            "error": "Dette lokale Case Center-endepunktet er ikke tilgjengelig fra fremmede nettsteder.",\n        }), 403\n    return None\n\n\ndef _active_window_rect()'''
if server.count(old)!=1:raise RuntimeError("CORS/origin anchor missing or ambiguous")
server=server.replace(old,new,1)
server_path.write_text(server,encoding="utf-8")

test_path=p("desktop-bridge/test_case_v16.py")
test=test_path.read_text(encoding="utf-8")
anchor='''    def test_case_page_is_available_and_memory_only(self) -> None:\n        response = self.client.get("/case")\n'''
insert='''    def test_foreign_browser_origin_is_blocked_before_sensitive_routes(self) -> None:\n        headers={"Origin": "https://evil.example"}\n        self.assertEqual(self.client.get("/case", headers=headers).status_code, 403)\n        self.assertEqual(self.client.get("/lm/models", headers=headers).status_code, 403)\n        self.assertEqual(self.client.get("/capture/active-window", headers=headers).status_code, 403)\n\n    def test_local_file_origin_can_open_case_center(self) -> None:\n        response=self.client.get("/case", headers={"Origin": "null"})\n        self.assertEqual(response.status_code, 200)\n        self.assertEqual(response.headers.get("Access-Control-Allow-Origin"), "null")\n\n'''+anchor
if test.count(anchor)!=1:raise RuntimeError("backend test anchor missing")
test=test.replace(anchor,insert,1)
test_path.write_text(test,encoding="utf-8")

manifest_path=p("RAH-RAVEN-CASE-CENTER-VERSION.json")
manifest=json.loads(manifest_path.read_text(encoding="utf-8"))
assert manifest["stage"]=="candidate"
manifest["features"]["foreign_browser_origin_guard"]=True
manifest["features"]["cors_wildcard"]=False
manifest["features"]["capture_requires_local_origin"]=True
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

master_path=p("RAH-RAVEN-VERSION.json")
master=json.loads(master_path.read_text(encoding="utf-8"))
assert master["release_gate"]["stable_components"]==EXPECTED_CORE
assert master["privacy"]["raven_chronicle_stable"] is True
assert master["privacy"]["system_health_stable"] is True
master["privacy"]["case_center_foreign_browser_origin_guard"]=True
master["privacy"]["case_center_cors_wildcard"]=False
master["privacy"]["case_center_capture_requires_local_origin"]=True
master_path.write_text(json.dumps(master,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

semantic_path=p("tests/raven-case-center-v16.test.mjs")
semantic=semantic_path.read_text(encoding="utf-8")
server_anchor='''assert.match(server, /case_center_version/);\nassert.doesNotMatch(server, /app\\.run\\(host=HOST, port=PORT/);'''
server_new='''assert.match(server, /case_center_version/);\nassert.match(server, /protect_case_center_local_apis/);\nassert.match(server, /LOCAL_BROWSER_ORIGINS/);\nassert.match(server, /CASE_PROTECTED_PREFIXES/);\nassert.doesNotMatch(server, /["']origins["']\\s*:\\s*["']\\*["']/);\nassert.doesNotMatch(server, /app\\.run\\(host=HOST, port=PORT/);'''
if semantic.count(server_anchor)!=1:raise RuntimeError("semantic server anchor missing")
semantic=semantic.replace(server_anchor,server_new,1)
feature_anchor='''assert.equal(component.features.automatic_sending, false);\nassert.equal(component.next_milestone, "stable-gate");'''
feature_new='''assert.equal(component.features.automatic_sending, false);\nassert.equal(component.features.foreign_browser_origin_guard, true);\nassert.equal(component.features.cors_wildcard, false);\nassert.equal(component.features.capture_requires_local_origin, true);\nassert.equal(component.next_milestone, "stable-gate");'''
if semantic.count(feature_anchor)!=1:raise RuntimeError("semantic component anchor missing")
semantic=semantic.replace(feature_anchor,feature_new,1)
master_anchor='''assert.equal(master.privacy.case_center_professional_approval_self_attestation, false);\nconsole.log("RAH Raven Case Center v1.6 candidate contract passed.");'''
master_new='''assert.equal(master.privacy.case_center_professional_approval_self_attestation, false);\nassert.equal(master.privacy.case_center_foreign_browser_origin_guard, true);\nassert.equal(master.privacy.case_center_cors_wildcard, false);\nassert.equal(master.privacy.case_center_capture_requires_local_origin, true);\nconsole.log("RAH Raven Case Center v1.6 candidate contract passed.");'''
if semantic.count(master_anchor)!=1:raise RuntimeError("semantic master anchor missing")
semantic=semantic.replace(master_anchor,master_new,1)
semantic_path.write_text(semantic,encoding="utf-8")

after={path:digest(path) for path in FROZEN}
changed=[path for path in FROZEN if before[path]!=after[path]]
if changed:raise RuntimeError(f"Origin hardening changed frozen runtime(s): {changed}")
print("Case Center origin boundary hardened; frozen Raven surfaces preserved.")
