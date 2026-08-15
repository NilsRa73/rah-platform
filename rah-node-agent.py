#!/usr/bin/env python3
from __future__ import annotations
import argparse,base64,hashlib,hmac,json,os,platform,re,secrets,shutil,socket,subprocess,threading,time
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
AGENT_VERSION="0.9.0";PROTOCOL="rah-node-health-v2";STORAGE_PROTOCOL="rah-node-storage-v1";ACTIONS_PROTOCOL="rah-node-actions-v3";LAUNCH_PROTOCOL="rah-node-launch-v1";HANDOFF_PROTOCOL="rah-node-handoff-v1";AUTH_PROTOCOL="rah-node-auth-v1";ACTION_CHALLENGE_HEADER="X-RAH-Action-Challenge";AUTH_NONCE_HEADER="X-RAH-Auth-Nonce";AUTH_PROOF_HEADER="X-RAH-Auth-Proof";ACTION_CHALLENGE_TTL_SECONDS=60;AUTH_NONCE_TTL_SECONDS=30;PORT=18766
ALLOWED_ORIGINS={"null","http://127.0.0.1:18765","http://localhost:18765"};ALLOWED_CAPABILITIES=("compute","storage","display","remote-desktop");AUTHENTICATED_PATHS=("/health","/actions","/storage","/launch/rustdesk","/handoff/rustdesk")
ACTION_CATALOG={"storage-summary.read":{"id":"storage-summary.read","label":"Read system-volume storage","capability":"storage","method":"GET","path":"/storage","scope":"system-volume","mutating":False},"rustdesk.launch":{"id":"rustdesk.launch","label":"Launch RustDesk","capability":"remote-desktop","method":"POST","path":"/launch/rustdesk","scope":"fixed-app","mutating":True},"rustdesk.connect":{"id":"rustdesk.connect","label":"Start RustDesk handoff","capability":"remote-desktop","method":"POST","path":"/handoff/rustdesk","scope":"fixed-app-peer-id","mutating":True,"input":"peer-id"}}
def clean_text(v,n):return " ".join((v or "").split())[:n]
def sanitize_session_id(v):v=str(v or "");return v if re.fullmatch(r"[A-Za-z0-9_-]{20,64}",v) else ""
def sanitize_auth_nonce(v):v=str(v or "");return v if re.fullmatch(r"[A-Za-z0-9_-]{24,64}",v) else ""
def sanitize_auth_proof(v):v=str(v or "");return v if re.fullmatch(r"[A-Za-z0-9_-]{43}",v) else ""
def sanitize_capabilities(values):
 out=[]
 for v in values or []:
  x=clean_text(str(v),32).lower()
  if x in ALLOWED_CAPABILITIES and x not in out:out.append(x)
 return out
def build_permissions(c=None):
 caps=sanitize_capabilities(c);return{"healthRead":True,"capabilityRead":True,"actionCatalogRead":True,"storageRead":"storage" in caps,"externalAppLaunch":"remote-desktop" in caps,"externalRemoteDesktopHandoff":"remote-desktop" in caps,"commands":False,"files":False,"shell": False,"remoteControl":False}
def build_health_payload(name="",role="",capabilities=None,session_id=""):
 caps=sanitize_capabilities(capabilities);return{"protocol":PROTOCOL,"agentVersion":AGENT_VERSION,"status":"ready","sessionId":sanitize_session_id(session_id),"hostname":clean_text(socket.gethostname(),80) or "Unknown host","platform":clean_text(platform.system(),80) or "Unknown platform","platformRelease":clean_text(platform.release(),80),"machine":clean_text(platform.machine(),40),"nodeName":clean_text(name,80),"nodeRole":clean_text(role,100),"capabilities":caps,"permissions":build_permissions(caps)}
def rustdesk_candidates():
 out=[];w=shutil.which("rustdesk")
 if w:out.append(Path(w))
 if os.name=="nt":
  for b in (os.environ.get("ProgramFiles"),os.environ.get("ProgramFiles(x86)"),os.environ.get("LOCALAPPDATA")):
   if b:out += [Path(b)/"RustDesk"/"rustdesk.exe",Path(b)/"Programs"/"RustDesk"/"rustdesk.exe"]
 elif platform.system()=="Darwin":out.append(Path("/Applications/RustDesk.app/Contents/MacOS/RustDesk"))
 else:out += [Path("/usr/bin/rustdesk"),Path("/usr/local/bin/rustdesk"),Path("/opt/rustdesk/rustdesk")]
 return out
def resolve_rustdesk_executable():
 for p in rustdesk_candidates():
  try:
   if p.is_file():return str(p.resolve())
  except OSError:pass
 return ""
def build_app_paths(overrides=None):
 if overrides is not None:
  p=clean_text(str(overrides.get("rustdesk","") if isinstance(overrides,dict) else ""),512);return{"rustdesk":p} if p else{}
 p=resolve_rustdesk_executable();return{"rustdesk":p} if p else{}
def build_actions_payload(capabilities=None,app_paths=None,session_id=""):
 caps=sanitize_capabilities(capabilities);paths=build_app_paths(app_paths);actions=[]
 for aid in ("storage-summary.read","rustdesk.launch","rustdesk.connect"):
  a=ACTION_CATALOG[aid]
  if a["capability"] in caps and (not aid.startswith("rustdesk.") or paths.get("rustdesk")):actions.append(dict(a))
 return{"protocol":ACTIONS_PROTOCOL,"status":"ready","sessionId":sanitize_session_id(session_id),"actions":actions,"approvalMode":"command-center-local"}
def issue_action_challenges(base,state,lock,ttl_seconds=60,now=None):
 ts=time.monotonic() if now is None else float(now);ttl=max(1,int(ttl_seconds));actions=[]
 with lock:
  state.clear()
  for a in base.get("actions",[]):
   ch=secrets.token_urlsafe(24);state[a["id"]]={"value":ch,"expires":ts+ttl};row=dict(a);row.update(challenge=ch,challengeTtlSeconds=ttl);actions.append(row)
 return{"protocol":ACTIONS_PROTOCOL,"status":"ready","sessionId":base.get("sessionId",""),"actions":actions,"approvalMode":"command-center-local"}
def consume_action_challenge(state,lock,aid,value,now=None):
 if not isinstance(value,str) or not value:return"missing"
 ts=time.monotonic() if now is None else float(now)
 with lock:entry=state.get(aid)
 if not entry or ts>entry["expires"]:return"invalid"
 if not hmac.compare_digest(value,entry["value"]):return"invalid"
 with lock:state.pop(aid,None)
 return"ok"
def body_sha256_hex(body):return hashlib.sha256(body or b"").hexdigest()
def build_auth_canonical(session_id,nonce,method,path,body_hash):
 s=sanitize_session_id(session_id);n=sanitize_auth_nonce(nonce);m=str(method or "").upper()
 if not s or not n or m not in ("GET","POST") or path not in AUTHENTICATED_PATHS or not isinstance(body_hash,str) or not re.fullmatch(r"[0-9a-f]{64}",body_hash):return""
 return"\n".join(("RAH-AUTH-V1",s,n,m,path,body_hash))
def compute_auth_proof(token,canonical):
 if not isinstance(token,str) or not token or not canonical:return""
 return base64.urlsafe_b64encode(hmac.new(token.encode("utf-8"),canonical.encode("utf-8"),hashlib.sha256).digest()).decode().rstrip("=")
def issue_auth_challenge(state,lock,client,session_id,ttl_seconds=30,now=None):
 ts=time.monotonic() if now is None else float(now);ttl=max(1,int(ttl_seconds));nonce=secrets.token_urlsafe(24)
 with lock:state[str(client)]={"value":nonce,"expires":ts+ttl}
 return{"protocol":AUTH_PROTOCOL,"status":"challenge","sessionId":sanitize_session_id(session_id),"nonce":nonce,"ttlSeconds":ttl}
def consume_auth_proof(state,lock,client,token,session_id,nonce,proof,method,path,body_bytes=b"",now=None):
 n=sanitize_auth_nonce(nonce);p=sanitize_auth_proof(proof)
 if not n or not p:return"missing"
 ts=time.monotonic() if now is None else float(now)
 with lock:entry=state.pop(str(client),None)
 if not entry or ts>entry["expires"] or not hmac.compare_digest(n,entry["value"]):return"invalid"
 expected=compute_auth_proof(token,build_auth_canonical(session_id,n,method,path,body_sha256_hex(body_bytes)))
 return"ok" if expected and hmac.compare_digest(p,expected) else"invalid"
def system_volume():return Path.home().anchor or "/"
def build_storage_payload(capabilities=None):
 if "storage" not in sanitize_capabilities(capabilities):return None
 v=system_volume();u=shutil.disk_usage(v);return{"protocol":STORAGE_PROTOCOL,"status":"ok","scope":"system-volume","volume":clean_text(v,48),"totalBytes":int(u.total),"usedBytes":int(u.used),"freeBytes":int(u.free)}
def process_kwargs():
 k={"stdin":subprocess.DEVNULL,"stdout":subprocess.DEVNULL,"stderr":subprocess.DEVNULL,"close_fds":True,"shell": False}
 if os.name=="nt":k["creationflags"]=getattr(subprocess,"DETACHED_PROCESS",0)|getattr(subprocess,"CREATE_NEW_PROCESS_GROUP",0)
 else:k["start_new_session"]=True
 return k
def launch_executable(path):subprocess.Popen([path],**process_kwargs());return True
def is_valid_rustdesk_peer_id(v):return isinstance(v,str) and v==v.strip() and bool(re.fullmatch(r"(?:\d{6,20}|[A-Za-z][A-Za-z0-9_]{5,15})",v))
def launch_rustdesk_connect(path,peer_id):
 if not path or not is_valid_rustdesk_peer_id(peer_id):return False
 subprocess.Popen([path, "--connect", peer_id],**process_kwargs());return True
def make_handler(token,node_name="",node_role="",capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=60,session_id=None,auth_ttl_seconds=30):
 caps=sanitize_capabilities(capabilities);paths=build_app_paths(app_paths);session=sanitize_session_id(session_id) or secrets.token_urlsafe(18);health=build_health_payload(node_name,node_role,caps,session);actions=build_actions_payload(caps,paths,session);action_state={};auth_state={};alock=threading.Lock();xlock=threading.Lock();launcher=app_launcher or launch_executable;handoff=handoff_launcher or launch_rustdesk_connect
 class H(BaseHTTPRequestHandler):
  server_version="RAHNodeAgent/0.9";sys_version=""
  def log_message(self,*_):return
  def _origin(self):return self.headers.get("Origin","")
  def _allowed(self):return self._origin() in ALLOWED_ORIGINS
  def _cors(self):
   if self._allowed():
    self.send_header("Access-Control-Allow-Origin",self._origin());self.send_header("Vary","Origin");self.send_header("Access-Control-Allow-Methods","GET, POST, OPTIONS");self.send_header("Access-Control-Allow-Headers","Content-Type, "+ACTION_CHALLENGE_HEADER+", "+AUTH_NONCE_HEADER+", "+AUTH_PROOF_HEADER)
    if self.headers.get("Access-Control-Request-Private-Network","").lower()=="true":self.send_header("Access-Control-Allow-Private-Network","true")
  def _json(self,status,obj):
   data=json.dumps(obj,separators=(",",":")).encode();self.send_response(status);self._cors();self.send_header("Content-Type","application/json; charset=utf-8");self.send_header("Content-Length",str(len(data)));self.send_header("Cache-Control","no-store");self.send_header("X-Content-Type-Options","nosniff");self.end_headers();self.wfile.write(data)
  def _client(self):return self.client_address[0]
  def _empty(self):
   if self.headers.get("Transfer-Encoding") or int(self.headers.get("Content-Length","0") or 0)!=0:self._json(400,{"error":"request_body_not_allowed"});return False
   return True
  def _proof(self,method,path,body=b""):
   if not self._allowed():self._json(403,{"error":"origin_not_allowed"});return False
   if self.headers.get("Authorization"):self._json(400,{"error":"bearer_transport_not_allowed"});return False
   r=consume_auth_proof(auth_state,xlock,self._client(),token,session,self.headers.get(AUTH_NONCE_HEADER,""),self.headers.get(AUTH_PROOF_HEADER,""),method,path,body)
   if r=="ok":return True
   self._json(428 if r=="missing" else 401,{"error":"auth_proof_required" if r=="missing" else"auth_proof_invalid_or_expired"});return False
  def _action(self,aid):
   r=consume_action_challenge(action_state,alock,aid,self.headers.get(ACTION_CHALLENGE_HEADER,""))
   if r=="ok":return True
   self._json(428 if r=="missing" else 409,{"error":"action_challenge_required" if r=="missing" else"action_challenge_invalid_or_expired"});return False
  def _read_handoff(self):
   if self.headers.get("Transfer-Encoding"):self._json(400,{"error":"transfer_encoding_not_allowed"});return None
   if self.headers.get("Content-Type","").split(";",1)[0].strip().lower()!="application/json":self._json(415,{"error":"json_content_type_required"});return None
   try:n=int(self.headers.get("Content-Length","0") or 0)
   except ValueError:self._json(400,{"error":"invalid_content_length"});return None
   if n<=0 or n>256:self._json(400,{"error":"invalid_handoff_body_size"});return None
   body=self.rfile.read(n)
   try:p=json.loads(body.decode())
   except Exception:self._json(400,{"error":"invalid_json"});return None
   return body,p
  def do_OPTIONS(self):
   if self.path not in (("/auth/challenge",)+AUTHENTICATED_PATHS) or not self._allowed():self._json(403,{"error":"forbidden"});return
   self.send_response(204);self._cors();self.send_header("Content-Length","0");self.end_headers()
  def do_GET(self):
   if self.path=="/auth/challenge":
    if not self._allowed():self._json(403,{"error":"origin_not_allowed"});return
    if self.headers.get("Authorization"):self._json(400,{"error":"bearer_transport_not_allowed"});return
    self._json(200,issue_auth_challenge(auth_state,xlock,self._client(),session,auth_ttl_seconds));return
   if self.path not in ("/health","/actions","/storage"):self._json(405 if self.path in ("/launch/rustdesk","/handoff/rustdesk") else 404,{"error":"method_not_allowed" if self.path in ("/launch/rustdesk","/handoff/rustdesk") else"not_found"});return
   if not self._empty() or not self._proof("GET",self.path):return
   if self.path=="/health":self._json(200,health);return
   if self.path=="/actions":self._json(200,issue_action_challenges(actions,action_state,alock,challenge_ttl_seconds));return
   p=build_storage_payload(caps)
   if p is None:self._json(403,{"error":"storage_capability_not_enabled"});return
   if self._action("storage-summary.read"):self._json(200,p)
  def do_POST(self):
   if self.path not in ("/launch/rustdesk","/handoff/rustdesk"):self._json(405 if self.path in ("/auth/challenge","/health","/actions","/storage") else 404,{"error":"method_not_allowed" if self.path in ("/auth/challenge","/health","/actions","/storage") else"not_found"});return
   if self.path=="/launch/rustdesk":
    if not self._empty() or not self._proof("POST",self.path):return
    if "remote-desktop" not in caps:self._json(403,{"error":"remote_desktop_capability_not_enabled"});return
    path=paths.get("rustdesk","")
    if not path:self._json(503,{"error":"rustdesk_not_available"});return
    if not self._action("rustdesk.launch"):return
    try:ok=bool(launcher(path))
    except Exception:ok=False
    self._json(200,{"protocol":LAUNCH_PROTOCOL,"status":"launched","app":"rustdesk"}) if ok else self._json(503,{"error":"rustdesk_launch_failed"});return
   r=self._read_handoff()
   if r is None:return
   body,p=r
   if not self._proof("POST",self.path,body):return
   if "remote-desktop" not in caps:self._json(403,{"error":"remote_desktop_capability_not_enabled"});return
   path=paths.get("rustdesk","")
   if not path:self._json(503,{"error":"rustdesk_not_available"});return
   if not isinstance(p,dict) or set(p)!={"peerId"}:self._json(400,{"error":"peer_id_only"});return
   peer=p.get("peerId")
   if not is_valid_rustdesk_peer_id(peer):self._json(400,{"error":"invalid_peer_id"});return
   if not self._action("rustdesk.connect"):return
   try:ok=bool(handoff(path,peer))
   except Exception:ok=False
   self._json(200,{"protocol":HANDOFF_PROTOCOL,"status":"handoff-started","app":"rustdesk"}) if ok else self._json(503,{"error":"rustdesk_handoff_failed"})
  def do_PUT(self):self._json(405,{"error":"method_not_allowed"})
  def do_DELETE(self):self._json(405,{"error":"method_not_allowed"})
 return H
def create_server(host,port,token,node_name="",node_role="",capabilities=None,app_paths=None,app_launcher=None,handoff_launcher=None,challenge_ttl_seconds=60,session_id=None,auth_ttl_seconds=30):return ThreadingHTTPServer((host,port),make_handler(token,node_name,node_role,capabilities,app_paths,app_launcher,handoff_launcher,challenge_ttl_seconds,session_id,auth_ttl_seconds))
def parse_args():
 p=argparse.ArgumentParser(description="RAH Node Agent — token-proof auth + fixed allowlisted actions");p.add_argument("--allow-lan",action="store_true");p.add_argument("--name",default="");p.add_argument("--role",default="");p.add_argument("--capability",action="append",choices=ALLOWED_CAPABILITIES,default=[]);return p.parse_args()
def main():
 a=parse_args();host="0.0.0.0" if a.allow_lan else"127.0.0.1";token=secrets.token_urlsafe(32);caps=sanitize_capabilities(a.capability);paths=build_app_paths();server=create_server(host,PORT,token,a.name,a.role,caps,paths);print(f"RAH Node Agent v{AGENT_VERSION}\nPort: {PORT}\nCapabilities: "+(", ".join(caps) if caps else"identity-only"));print("Enrollment/action token (memory only; changes on restart):\n"+token);print("Token stays local in Command Center; LAN carries only session-bound HMAC-SHA256 proofs. No bearer fallback, shell, files, generic execution or native remote control.")
 try:server.serve_forever(poll_interval=.5)
 except KeyboardInterrupt:pass
 finally:server.server_close()
if __name__=="__main__":main()