#!/usr/bin/env python3
from __future__ import annotations
import argparse,hmac,json,platform,secrets,shutil,socket
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
AGENT_VERSION="0.4.0";PROTOCOL="rah-node-health-v1";STORAGE_PROTOCOL="rah-node-storage-v1";ACTIONS_PROTOCOL="rah-node-actions-v1";PORT=18766
ALLOWED_ORIGINS={"null","http://127.0.0.1:18765","http://localhost:18765"}
ALLOWED_CAPABILITIES=("compute","storage","display","remote-desktop")
ACTION_CATALOG={"storage-summary.read":{"id":"storage-summary.read","label":"Read system-volume storage","capability":"storage","method":"GET","path":"/storage","scope":"system-volume","mutating":False}}
def clean_text(value,limit):return " ".join((value or "").split())[:limit]
def sanitize_capabilities(values):
 out=[]
 for value in values or []:
  item=clean_text(str(value),32).lower()
  if item in ALLOWED_CAPABILITIES and item not in out:out.append(item)
 return out
def build_permissions(capabilities=None):
 caps=sanitize_capabilities(capabilities)
 return {"healthRead":True,"capabilityRead":True,"actionCatalogRead":True,"storageRead":"storage" in caps,"commands":False,"files":False,"shell":False,"remoteControl":False}
def build_health_payload(node_name="",node_role="",capabilities=None):
 caps=sanitize_capabilities(capabilities)
 return {"protocol":PROTOCOL,"agentVersion":AGENT_VERSION,"status":"ready","hostname":clean_text(socket.gethostname(),80) or "Unknown host","platform":clean_text(platform.system(),80) or "Unknown platform","platformRelease":clean_text(platform.release(),80),"machine":clean_text(platform.machine(),40),"nodeName":clean_text(node_name,80),"nodeRole":clean_text(node_role,100),"capabilities":caps,"permissions":build_permissions(caps)}
def build_actions_payload(capabilities=None):
 caps=sanitize_capabilities(capabilities);actions=[]
 for action_id in ("storage-summary.read",):
  action=ACTION_CATALOG[action_id]
  if action["capability"] in caps:actions.append(dict(action))
 return {"protocol":ACTIONS_PROTOCOL,"status":"ready","actions":actions,"approvalMode":"command-center-local"}
def system_volume():
 anchor=Path.home().anchor
 return anchor if anchor else "/"
def build_storage_payload(capabilities=None):
 caps=sanitize_capabilities(capabilities)
 if "storage" not in caps:return None
 volume=system_volume();usage=shutil.disk_usage(volume)
 return {"protocol":STORAGE_PROTOCOL,"status":"ok","scope":"system-volume","volume":clean_text(volume,48),"totalBytes":int(usage.total),"usedBytes":int(usage.used),"freeBytes":int(usage.free)}
def is_authorized(header_value,token):
 prefix="Bearer "
 return bool(header_value and header_value.startswith(prefix) and hmac.compare_digest(header_value[len(prefix):],token))
def make_handler(token,node_name="",node_role="",capabilities=None):
 caps=sanitize_capabilities(capabilities);health_payload=build_health_payload(node_name,node_role,caps);actions_payload=build_actions_payload(caps)
 class Handler(BaseHTTPRequestHandler):
  server_version="RAHNodeAgent/0.4";sys_version=""
  def log_message(self,fmt,*args):return
  def _origin(self):return self.headers.get("Origin","")
  def _origin_allowed(self):return self._origin() in ALLOWED_ORIGINS
  def _cors(self):
   origin=self._origin()
   if origin in ALLOWED_ORIGINS:
    self.send_header("Access-Control-Allow-Origin",origin);self.send_header("Vary","Origin");self.send_header("Access-Control-Allow-Methods","GET, OPTIONS");self.send_header("Access-Control-Allow-Headers","Authorization, Content-Type")
    if self.headers.get("Access-Control-Request-Private-Network","").lower()=="true":self.send_header("Access-Control-Allow-Private-Network","true")
  def _json(self,status,body):
   data=json.dumps(body,separators=(",",":")).encode("utf-8");self.send_response(status);self._cors();self.send_header("Content-Type","application/json; charset=utf-8");self.send_header("Content-Length",str(len(data)));self.send_header("Cache-Control","no-store");self.send_header("X-Content-Type-Options","nosniff");self.end_headers();self.wfile.write(data)
  def do_OPTIONS(self):
   if self.path not in ("/health","/actions","/storage") or not self._origin_allowed():self._json(403,{"error":"forbidden"});return
   self.send_response(204);self._cors();self.send_header("Content-Length","0");self.end_headers()
  def do_GET(self):
   if self.path not in ("/health","/actions","/storage"):self._json(404,{"error":"not_found"});return
   if not self._origin_allowed():self._json(403,{"error":"origin_not_allowed"});return
   if not is_authorized(self.headers.get("Authorization"),token):self._json(401,{"error":"unauthorized"});return
   if self.path=="/health":self._json(200,health_payload);return
   if self.path=="/actions":self._json(200,actions_payload);return
   payload=build_storage_payload(caps)
   if payload is None:self._json(403,{"error":"storage_capability_not_enabled"});return
   self._json(200,payload)
  def do_POST(self):self._json(405,{"error":"method_not_allowed"})
  def do_PUT(self):self._json(405,{"error":"method_not_allowed"})
  def do_DELETE(self):self._json(405,{"error":"method_not_allowed"})
 return Handler
def create_server(host,port,token,node_name="",node_role="",capabilities=None):return ThreadingHTTPServer((host,port),make_handler(token,node_name,node_role,capabilities))
def parse_args():
 p=argparse.ArgumentParser(description="RAH Node Agent — explicit read-only identity, action catalog and storage-summary endpoints");p.add_argument("--allow-lan",action="store_true",help="Explicitly bind to LAN interfaces instead of loopback");p.add_argument("--name",default="");p.add_argument("--role",default="");p.add_argument("--capability",action="append",choices=ALLOWED_CAPABILITIES,default=[],help="Explicitly advertise one capability; repeat as needed");return p.parse_args()
def main():
 args=parse_args();host="0.0.0.0" if args.allow_lan else "127.0.0.1";token=secrets.token_urlsafe(32);capabilities=sanitize_capabilities(args.capability);server=create_server(host,PORT,token,args.name,args.role,capabilities);actions=build_actions_payload(capabilities)["actions"]
 print(f"RAH Node Agent v{AGENT_VERSION}");print("Mode: "+("LAN enrollment enabled" if args.allow_lan else "loopback only"));print(f"Port: {PORT}");print("Capabilities: "+(", ".join(capabilities) if capabilities else "identity-only"));print("Advertised actions: "+(", ".join(a["id"] for a in actions) if actions else "none"));print("Permissions: health/capability/action-catalog read; storage summary only with storage capability; commands/files/shell/remote control disabled.");print("Enrollment/action token (memory only; changes on restart):");print(token);print("GET /health and GET /actions are authenticated. GET /storage remains fixed-volume and read-only.");print("Command Center local approval is additionally required before CC invokes an advertised action.");print("No arbitrary action endpoint, arbitrary path, file listing, shell, write, command or remote-control endpoint exists.");print("Press Ctrl+C to stop the agent.")
 try:server.serve_forever(poll_interval=0.5)
 except KeyboardInterrupt:pass
 finally:server.server_close()
 return 0
if __name__=="__main__":raise SystemExit(main())
