#!/usr/bin/env python3
from __future__ import annotations
import argparse,hmac,json,os,platform,re,secrets,shutil,socket,subprocess
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
AGENT_VERSION="0.6.0";PROTOCOL="rah-node-health-v1";STORAGE_PROTOCOL="rah-node-storage-v1";ACTIONS_PROTOCOL="rah-node-actions-v1";LAUNCH_PROTOCOL="rah-node-launch-v1";HANDOFF_PROTOCOL="rah-node-handoff-v1";PORT=18766
ALLOWED_ORIGINS={"null","http://127.0.0.1:18765","http://localhost:18765"}
ALLOWED_CAPABILITIES=("compute","storage","display","remote-desktop")
ACTION_CATALOG={
 "storage-summary.read":{"id":"storage-summary.read","label":"Read system-volume storage","capability":"storage","method":"GET","path":"/storage","scope":"system-volume","mutating":False},
 "rustdesk.launch":{"id":"rustdesk.launch","label":"Launch RustDesk","capability":"remote-desktop","method":"POST","path":"/launch/rustdesk","scope":"fixed-app","mutating":True},
 "rustdesk.connect":{"id":"rustdesk.connect","label":"Start RustDesk handoff","capability":"remote-desktop","method":"POST","path":"/handoff/rustdesk","scope":"fixed-app-peer-id","mutating":True,"input":"peer-id"}
}
def clean_text(value,limit):return " ".join((value or "").split())[:limit]
def sanitize_capabilities(values):
 out=[]
 for value in values or []:
  item=clean_text(str(value),32).lower()
  if item in ALLOWED_CAPABILITIES and item not in out:out.append(item)
 return out
def build_permissions(capabilities=None):
 caps=sanitize_capabilities(capabilities)
 return {"healthRead":True,"capabilityRead":True,"actionCatalogRead":True,"storageRead":"storage" in caps,"externalAppLaunch":"remote-desktop" in caps,"externalRemoteDesktopHandoff":"remote-desktop" in caps,"commands":False,"files":False,"shell":False,"remoteControl":False}
def build_health_payload(node_name="",node_role="",capabilities=None):
 caps=sanitize_capabilities(capabilities)
 return {"protocol":PROTOCOL,"agentVersion":AGENT_VERSION,"status":"ready","hostname":clean_text(socket.gethostname(),80) or "Unknown host","platform":clean_text(platform.system(),80) or "Unknown platform","platformRelease":clean_text(platform.release(),80),"machine":clean_text(platform.machine(),40),"nodeName":clean_text(node_name,80),"nodeRole":clean_text(node_role,100),"capabilities":caps,"permissions":build_permissions(caps)}
def rustdesk_candidates():
 candidates=[];which=shutil.which("rustdesk")
 if which:candidates.append(Path(which))
 if os.name=="nt":
  for base in (os.environ.get("ProgramFiles"),os.environ.get("ProgramFiles(x86)"),os.environ.get("LOCALAPPDATA")):
   if not base:continue
   root=Path(base)
   candidates.extend([root/"RustDesk"/"rustdesk.exe",root/"Programs"/"RustDesk"/"rustdesk.exe"])
 elif platform.system()=="Darwin":candidates.append(Path("/Applications/RustDesk.app/Contents/MacOS/RustDesk"))
 else:candidates.extend([Path("/usr/bin/rustdesk"),Path("/usr/local/bin/rustdesk"),Path("/opt/rustdesk/rustdesk")])
 out=[];seen=set()
 for candidate in candidates:
  try:key=str(candidate.resolve(strict=False))
  except Exception:key=str(candidate)
  if key not in seen:seen.add(key);out.append(candidate)
 return out
def resolve_rustdesk_executable():
 for candidate in rustdesk_candidates():
  try:
   if candidate.is_file():return str(candidate.resolve())
  except OSError:continue
 return ""
def build_app_paths(overrides=None):
 if overrides is not None:
  path=clean_text(str(overrides.get("rustdesk","") if isinstance(overrides,dict) else ""),512)
  return {"rustdesk":path} if path else {}
 path=resolve_rustdesk_executable();return {"rustdesk":path} if path else {}
def build_actions_payload(capabilities=None,app_paths=None):
 caps=sanitize_capabilities(capabilities);paths=build_app_paths(app_paths);actions=[]
 for action_id in ("storage-summary.read","rustdesk.launch","rustdesk.connect"):
  action=ACTION_CATALOG[action_id]
  if action["capability"] not in caps:continue
  if action_id.startswith("rustdesk.") and not paths.get("rustdesk"):continue
  actions.append(dict(action))
 return {"protocol":ACTIONS_PROTOCOL,"status":"ready","actions":actions,"approvalMode":"command-center-local"}
def system_volume():
 anchor=Path.home().anchor
 return anchor if anchor else "/"
def build_storage_payload(capabilities=None):
 caps=sanitize_capabilities(capabilities)
 if "storage" not in caps:return None
 volume=system_volume();usage=shutil.disk_usage(volume)
 return {"protocol":STORAGE_PROTOCOL,"status":"ok","scope":"system-volume","volume":clean_text(volume,48),"totalBytes":int(usage.total),"usedBytes":int(usage.used),"freeBytes":int(usage.free)}
def process_kwargs():
 kwargs={"stdin":subprocess.DEVNULL,"stdout":subprocess.DEVNULL,"stderr":subprocess.DEVNULL,"close_fds":True,"shell":False}
 if os.name=="nt":kwargs["creationflags"]=getattr(subprocess,"DETACHED_PROCESS",0)|getattr(subprocess,"CREATE_NEW_PROCESS_GROUP",0)
 else:kwargs["start_new_session"]=True
 return kwargs
def launch_executable(path):
 if not path:return False
 subprocess.Popen([path],**process_kwargs());return True
def is_valid_rustdesk_peer_id(value):
 if not isinstance(value,str) or value!=value.strip():return False
 return bool(re.fullmatch(r"(?:\d{6,20}|[A-Za-z][A-Za-z0-9_]{5,15})",value))
def launch_rustdesk_connect(path,peer_id):
 if not path or not is_valid_rustdesk_peer_id(peer_id):return False
 subprocess.Popen([path,"--connect",peer_id],**process_kwargs());return True
def is_authorized(header_value,token):
 prefix="Bearer "
 return bool(header_value and header_value.startswith(prefix) and hmac.compare_digest(header_value[len(prefix):],token))
def make_handler(token,node_name="",node_role="",capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None):
 caps=sanitize_capabilities(capabilities);paths=build_app_paths(app_paths);health_payload=build_health_payload(node_name,node_role,caps);actions_payload=build_actions_payload(caps,paths);launcher=app_launcher or launch_executable;handoff=handoff_launcher or launch_rustdesk_connect
 class Handler(BaseHTTPRequestHandler):
  server_version="RAHNodeAgent/0.6";sys_version=""
  def log_message(self,fmt,*args):return
  def _origin(self):return self.headers.get("Origin","")
  def _origin_allowed(self):return self._origin() in ALLOWED_ORIGINS
  def _cors(self):
   origin=self._origin()
   if origin in ALLOWED_ORIGINS:
    self.send_header("Access-Control-Allow-Origin",origin);self.send_header("Vary","Origin");self.send_header("Access-Control-Allow-Methods","GET, POST, OPTIONS");self.send_header("Access-Control-Allow-Headers","Authorization, Content-Type")
    if self.headers.get("Access-Control-Request-Private-Network","").lower()=="true":self.send_header("Access-Control-Allow-Private-Network","true")
  def _json(self,status,body):
   data=json.dumps(body,separators=(",",":")).encode("utf-8");self.send_response(status);self._cors();self.send_header("Content-Type","application/json; charset=utf-8");self.send_header("Content-Length",str(len(data)));self.send_header("Cache-Control","no-store");self.send_header("X-Content-Type-Options","nosniff");self.end_headers();self.wfile.write(data)
  def _authorized(self):
   if not self._origin_allowed():self._json(403,{"error":"origin_not_allowed"});return False
   if not is_authorized(self.headers.get("Authorization"),token):self._json(401,{"error":"unauthorized"});return False
   return True
  def _handoff_peer_id(self):
   if self.headers.get("Transfer-Encoding"):self._json(400,{"error":"transfer_encoding_not_allowed"});return None
   content_type=(self.headers.get("Content-Type","").split(";",1)[0].strip().lower())
   if content_type!="application/json":self._json(415,{"error":"json_content_type_required"});return None
   try:length=int(self.headers.get("Content-Length","0") or 0)
   except ValueError:self._json(400,{"error":"invalid_content_length"});return None
   if length<=0 or length>256:self._json(400,{"error":"invalid_handoff_body_size"});return None
   try:payload=json.loads(self.rfile.read(length).decode("utf-8"))
   except Exception:self._json(400,{"error":"invalid_json"});return None
   if not isinstance(payload,dict) or set(payload.keys())!={"peerId"}:self._json(400,{"error":"peer_id_only"});return None
   peer_id=payload.get("peerId")
   if not is_valid_rustdesk_peer_id(peer_id):self._json(400,{"error":"invalid_peer_id"});return None
   return peer_id
  def do_OPTIONS(self):
   if self.path not in ("/health","/actions","/storage","/launch/rustdesk","/handoff/rustdesk") or not self._origin_allowed():self._json(403,{"error":"forbidden"});return
   self.send_response(204);self._cors();self.send_header("Content-Length","0");self.end_headers()
  def do_GET(self):
   if self.path in ("/launch/rustdesk","/handoff/rustdesk"):self._json(405,{"error":"method_not_allowed"});return
   if self.path not in ("/health","/actions","/storage"):self._json(404,{"error":"not_found"});return
   if not self._authorized():return
   if self.path=="/health":self._json(200,health_payload);return
   if self.path=="/actions":self._json(200,actions_payload);return
   payload=build_storage_payload(caps)
   if payload is None:self._json(403,{"error":"storage_capability_not_enabled"});return
   self._json(200,payload)
  def do_POST(self):
   if self.path in ("/health","/actions","/storage"):self._json(405,{"error":"method_not_allowed"});return
   if self.path not in ("/launch/rustdesk","/handoff/rustdesk"):self._json(404,{"error":"not_found"});return
   if not self._authorized():return
   if "remote-desktop" not in caps:self._json(403,{"error":"remote_desktop_capability_not_enabled"});return
   path=paths.get("rustdesk","")
   if not path:self._json(503,{"error":"rustdesk_not_available"});return
   if self.path=="/launch/rustdesk":
    if self.headers.get("Transfer-Encoding") or int(self.headers.get("Content-Length","0") or 0)!=0:self._json(400,{"error":"request_body_not_allowed"});return
    try:ok=bool(launcher(path))
    except Exception:ok=False
    if not ok:self._json(503,{"error":"rustdesk_launch_failed"});return
    self._json(200,{"protocol":LAUNCH_PROTOCOL,"status":"launched","app":"rustdesk"});return
   peer_id=self._handoff_peer_id()
   if peer_id is None:return
   try:ok=bool(handoff(path,peer_id))
   except Exception:ok=False
   if not ok:self._json(503,{"error":"rustdesk_handoff_failed"});return
   self._json(200,{"protocol":HANDOFF_PROTOCOL,"status":"handoff-started","app":"rustdesk"})
  def do_PUT(self):self._json(405,{"error":"method_not_allowed"})
  def do_DELETE(self):self._json(405,{"error":"method_not_allowed"})
 return Handler
def create_server(host,port,token,node_name="",node_role="",capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None):return ThreadingHTTPServer((host,port),make_handler(token,node_name,node_role,capabilities,app_paths,app_launcher,handoff_launcher))
def parse_args():
 p=argparse.ArgumentParser(description="RAH Node Agent — explicit identity, fixed action catalog, read-only storage, fixed app launch and password-free RustDesk handoff");p.add_argument("--allow-lan",action="store_true",help="Explicitly bind to LAN interfaces instead of loopback");p.add_argument("--name",default="");p.add_argument("--role",default="");p.add_argument("--capability",action="append",choices=ALLOWED_CAPABILITIES,default=[],help="Explicitly advertise one capability; repeat as needed");return p.parse_args()
def main():
 args=parse_args();host="0.0.0.0" if args.allow_lan else "127.0.0.1";token=secrets.token_urlsafe(32);capabilities=sanitize_capabilities(args.capability);paths=build_app_paths();server=create_server(host,PORT,token,args.name,args.role,capabilities,paths);actions=build_actions_payload(capabilities,paths)["actions"]
 print(f"RAH Node Agent v{AGENT_VERSION}");print("Mode: "+("LAN enrollment enabled" if args.allow_lan else "loopback only"));print(f"Port: {PORT}");print("Capabilities: "+(", ".join(capabilities) if capabilities else "identity-only"));print("Advertised actions: "+(", ".join(a["id"] for a in actions) if actions else "none"));print("RustDesk: "+("available for approved launch/handoff" if paths.get("rustdesk") else "not found in fixed locations/PATH"));print("Permissions: health/capability/action-catalog read; storage summary with storage capability; fixed RustDesk launch/handoff with remote-desktop capability; commands/files/shell/native remote control disabled.");print("Enrollment/action token (memory only; changes on restart):");print(token);print("GET /health and GET /actions are authenticated. GET /storage remains fixed-volume and read-only.");print("POST /launch/rustdesk accepts no body, path or arguments and launches only the fixed RustDesk executable.");print("POST /handoff/rustdesk accepts only one validated peerId and internally uses the fixed --connect form; passwords are never accepted.");print("Command Center local approval is additionally required before CC invokes an advertised action.");print("No generic action/process endpoint, arbitrary path, installer, file listing, shell, command or native remote-control endpoint exists.");print("Press Ctrl+C to stop the agent.")
 try:server.serve_forever(poll_interval=0.5)
 except KeyboardInterrupt:pass
 finally:server.server_close()
 return 0
if __name__=="__main__":raise SystemExit(main())
