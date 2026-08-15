from __future__ import annotations

import hashlib, json, os, shutil, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ALLOWED = {"desktop-bridge/server_v17.py","desktop-bridge/test_chronicle_v17.py","RAH-RAVEN-CHRONICLE-VERSION.json","RAH-RAVEN-VERSION.json","tests/raven-chronicle-v17.test.mjs"}
FROZEN = ["RAH-RAVEN-CHRONICLE-LIVE.html","RAH-RAVEN-INSIGHTS.html","RAH-RAVEN-DAILY-BRIEF.html","desktop-bridge/chronicle_insights.py","desktop-bridge/chronicle_ai.py","desktop-bridge/raven_bridge.py","desktop-bridge/server_v16.py","RAH-RAVEN-FRISTVAKT.html","RAH-RAVEN-FRISTVAKT-VERSION.json","RAH-RAVEN-CASE-CENTER.html","RAH-RAVEN-CASE-CENTER-VERSION.json","RAH-COMMAND-CENTER-V0.5.html","RAH-COMMAND-CENTER-VERSION.json","rah-command-center-core.js","rah-node-agent.py","RAH-RAVEN-VISION-CORE.html","raven-vision-core.js","RAH-RAVEN-COUNCIL.html","raven-council.js","RAH-RAVEN-AGENT-RUNNER.html","RAH-RAVEN-MEMORY-SYNC.html","RAH-RAVEN-MISSION-CONTROL.html","RAH-RAVEN-PROJECT.html","RAH-RAVEN-CORE-DEMO.html","RAH-RAVEN-NOW.html","RAH-RAVEN-NOW-V2.html","RAH-RAVEN-START.html"]
EXPECTED_CORE = {"raven_vision":"0.6","raven_council":"0.3","agent_runner":"0.3","memory_sync":"0.2","mission_control":"2.9","project_focus":"2.4","raven_core":"1.12","raven_now":"2.17","raven_studio":"2.8"}

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def run(*args,cwd=ROOT):
    env=dict(os.environ); env["PYTHONDONTWRITEBYTECODE"]="1"; subprocess.run(args,cwd=cwd,env=env,check=True)
def repl(text,old,new,label):
    if text.count(old)!=1: raise RuntimeError(f"Expected one {label} anchor, found {text.count(old)}")
    return text.replace(old,new,1)

def main():
    before={n:sha(ROOT/n) for n in FROZEN}
    mp=ROOT/"RAH-RAVEN-CHRONICLE-VERSION.json"; m=json.loads(mp.read_text(encoding="utf-8"))
    if m.get("version")!="1.7.0" or m.get("stage")!="stable": raise RuntimeError("Chronicle v1.7.0 Stable required")
    rp=ROOT/"RAH-RAVEN-VERSION.json"; r=json.loads(rp.read_text(encoding="utf-8")); p=r.setdefault("privacy",{})
    if r.get("release_gate",{}).get("stable_components")!=EXPECTED_CORE: raise RuntimeError("Nine-core set changed")
    if p.get("raven_chronicle_stable") is not True or p.get("raven_fristvakt_stable") is not True: raise RuntimeError("Stable prerequisites missing")

    sp=ROOT/"desktop-bridge/server_v17.py"; s=sp.read_text(encoding="utf-8")
    s=repl(s,"from server_v16 import HOST, PORT, app","from server_v16 import HOST, LOCAL_BROWSER_ORIGINS, PORT, app","server import")
    s=repl(s,'APP_VERSION = "1.7.0"\nCHRONICLE_VERSION = "1.7.0"','APP_VERSION = "1.7.1"\nCHRONICLE_VERSION = "1.7.1"',"version")
    guard='''\n\nCHRONICLE_PROTECTED_PREFIX = "/chronicle"\n\n@app.before_request\ndef protect_chronicle_local_apis():\n    path = request.path\n    if path != CHRONICLE_PROTECTED_PREFIX and not path.startswith(CHRONICLE_PROTECTED_PREFIX + "/"):\n        return None\n    origin = (request.headers.get("Origin") or "").rstrip("/")\n    if origin and origin not in LOCAL_BROWSER_ORIGINS:\n        return jsonify({"ok": False, "error": "Dette lokale Chronicle-endepunktet er ikke tilgjengelig fra fremmede nettsteder."}), 403\n    return None\n'''
    s=repl(s,'\n\n@app.get("/chronicle/status")',guard+'\n\n@app.get("/chronicle/status")',"route guard")
    sp.write_text(s,encoding="utf-8")

    tp=ROOT/"desktop-bridge/test_chronicle_v17.py"; t=tp.read_text(encoding="utf-8")
    t=repl(t,'assert module.CHRONICLE_VERSION == "1.7.0"','assert module.CHRONICLE_VERSION == "1.7.1"',"test version")
    block='''\n\n        foreign = {"Origin": "https://foreign.example"}\n        assert client.post("/chronicle/session/start", headers=foreign).status_code == 403\n        assert client.post("/chronicle/pause", headers=foreign).status_code == 403\n        assert client.post("/chronicle/event", headers=foreign, data={"title":"Skal ikke lagres"}).status_code == 403\n        assert client.post("/chronicle/config", headers=foreign, data={"poll_seconds":"2"}).status_code == 403\n        assert client.get("/chronicle/export", headers=foreign).status_code == 403\n        after_block = client.get("/chronicle/status").get_json()\n        assert after_block["recording"] is False\n        assert after_block["event_count"] == 0\n        assert client.get("/chronicle/status", headers={"Origin":"null"}).status_code == 200\n        assert client.get("/chronicle/status", headers={"Origin":f"http://127.0.0.1:{module.PORT}"}).status_code == 200\n'''
    t=repl(t,'        client = module.app.test_client()\n\n        status = client.get("/chronicle/status")','        client = module.app.test_client()'+block+'\n        status = client.get("/chronicle/status")',"origin tests")
    tp.write_text(t,encoding="utf-8")

    m["version"]="1.7.1"; m["stage"]="stable-bugfix-candidate"; m["previous_stable_version"]="1.7.0"; m["runtime_feature_change"]=False
    f=m.setdefault("features",{}); f.update({"foreign_browser_origin_guard":True,"chronicle_routes_local_browser_origin_only":True,"cross_origin_mutation_blocked":True,"cors_wildcard":False})
    m["next_milestone"]="stable-gate"; m.pop("stable_since",None); m["development_reopened"]=True; m["development_paused"]=False; m["change_policy"]="bugfix-only"
    m["stable_release_gate"]={"status":"candidate","gate_version":"1.1.0","runtime_files_frozen":False,"stable_raven_runtime_frozen":True,"change_policy":"bugfix-only"}
    mp.write_text(json.dumps(m,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

    p.update({"raven_chronicle_foreign_browser_origin_guard":True,"raven_chronicle_routes_local_browser_origin_only":True,"raven_chronicle_cross_origin_mutation_blocked":True,"raven_chronicle_cors_wildcard":False,"raven_chronicle_bugfix_candidate":True,"raven_chronicle_candidate_over_previous_stable":True})
    rp.write_text(json.dumps(r,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")

    sem='''import assert from "node:assert/strict";\nimport fs from "node:fs";\nconst html=fs.readFileSync("RAH-RAVEN-CHRONICLE-LIVE.html","utf8");\nconst server=fs.readFileSync("desktop-bridge/server_v17.py","utf8");\nconst component=JSON.parse(fs.readFileSync("RAH-RAVEN-CHRONICLE-VERSION.json","utf8"));\nconst master=JSON.parse(fs.readFileSync("RAH-RAVEN-VERSION.json","utf8"));\nassert.match(html,/CHRONICLE LIVE · DESKTOP BRIDGE v1\\.7/);\nassert.match(html,/RAH Raven Chronicle v1\\.7 · lokal-first · menneskestyrt samtykke/);\nassert.match(html,/const BASE='http:\\/\\/127\\.0\\.0\\.1:18765'/);\nassert.match(html,/post\\('\\/chronicle\\/session\\/start'/);\nassert.doesNotMatch(html,/setInterval\\([^\\n]*session\\/start|refresh\\([^)]*session\\/start/);\nassert.equal(component.product,"RAH Raven Chronicle");\nassert.equal(component.version,"1.7.1");\nassert.equal(component.previous_stable_version,"1.7.0");\nassert.equal(component.stage,"stable-bugfix-candidate");\nassert.equal(component.runtime_feature_change,false);\nassert.equal(component.features.foreign_browser_origin_guard,true);\nassert.equal(component.features.chronicle_routes_local_browser_origin_only,true);\nassert.equal(component.features.cross_origin_mutation_blocked,true);\nassert.equal(component.features.cors_wildcard,false);\nassert.equal(component.features.visible_session_required_for_foreground_read,true);\nassert.equal(component.features.paused_blocks_foreground_read,true);\nassert.equal(component.features.keylogging,false);\nassert.equal(component.features.clipboard_capture,false);\nassert.equal(component.features.audio_capture,false);\nassert.equal(component.features.camera_capture,false);\nassert.equal(component.features.automatic_sending,false);\nassert.equal(component.next_milestone,"stable-gate");\nassert.equal(component.development_reopened,true);\nassert.equal(component.development_paused,false);\nassert.equal(component.change_policy,"bugfix-only");\nassert.equal(component.stable_release_gate.status,"candidate");\nassert.equal(component.stable_release_gate.gate_version,"1.1.0");\nassert.equal(component.stable_release_gate.runtime_files_frozen,false);\nassert.match(server,/from server_v16 import HOST, LOCAL_BROWSER_ORIGINS, PORT, app/);\nassert.match(server,/CHRONICLE_PROTECTED_PREFIX = "\\/chronicle"/);\nassert.match(server,/protect_chronicle_local_apis/);\nassert.match(server,/origin and origin not in LOCAL_BROWSER_ORIGINS/);\nconst stable={raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};\nassert.deepEqual(master.release_gate.stable_components,stable);\nassert.equal(master.privacy.raven_chronicle_foreign_browser_origin_guard,true);\nassert.equal(master.privacy.raven_chronicle_routes_local_browser_origin_only,true);\nassert.equal(master.privacy.raven_chronicle_cross_origin_mutation_blocked,true);\nassert.equal(master.privacy.raven_chronicle_cors_wildcard,false);\nassert.equal(master.privacy.raven_chronicle_bugfix_candidate,true);\nassert.equal(master.privacy.raven_chronicle_candidate_over_previous_stable,true);\nassert.equal(master.privacy.raven_chronicle_stable,true);\nassert.equal(master.privacy.raven_fristvakt_stable,true);\nassert.equal(master.privacy.case_center_stable,true);\nassert.equal(master.privacy.command_center_stable,true);\nconsole.log("Raven Chronicle v1.7.1 local-origin bugfix candidate passed over preserved v1.7.0 Stable contract.");\n'''
    (ROOT/"tests/raven-chronicle-v17.test.mjs").write_text(sem,encoding="utf-8")

    changed=set(subprocess.check_output(["git","diff","--name-only"],cwd=ROOT,text=True).splitlines())
    if changed!=ALLOWED: raise RuntimeError(f"Unexpected diff: {sorted(changed)}")
    run("python","-m","py_compile","server_v17.py","test_chronicle_v17.py",cwd=ROOT/"desktop-bridge")
    run("python","test_chronicle_v17.py",cwd=ROOT/"desktop-bridge"); run("python","test_chronicle_ai.py",cwd=ROOT/"desktop-bridge"); run("python","test_raven_bridge_security.py",cwd=ROOT/"desktop-bridge")
    run("node","tests/raven-chronicle-v17.test.mjs"); run("node","tests/raven-release-gate.test.mjs"); run("node","tests/raven-fristvakt-v0.2.test.mjs"); run("node","tests/raven-case-center-v16.test.mjs"); run("node","tests/rah-command-center-v05.test.mjs")
    for c in ROOT.rglob("__pycache__"): shutil.rmtree(c,ignore_errors=True)
    after={n:sha(ROOT/n) for n in FROZEN}; moved=[n for n in FROZEN if before[n]!=after[n]]
    if moved: raise RuntimeError(f"Frozen files changed: {moved}")
    if json.loads(rp.read_text(encoding="utf-8"))["release_gate"]["stable_components"]!=EXPECTED_CORE: raise RuntimeError("Nine-core set changed")
    print("Chronicle v1.7.1 candidate passed")
if __name__=="__main__": main()
