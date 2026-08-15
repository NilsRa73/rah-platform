import importlib.util,json,threading,unittest,urllib.error,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];spec=importlib.util.spec_from_file_location('rah_node_agent',ROOT/'rah-node-agent.py');agent=importlib.util.module_from_spec(spec);spec.loader.exec_module(agent)
class NodeAgentTests(unittest.TestCase):
 def setUp(self):
  self.token='test-token-abcdefghijklmnopqrstuvwxyz';self.launched=[];self.handoffs=[];self.server=agent.create_server('127.0.0.1',0,self.token,'Test Node','Approved apps',['compute','storage','remote-desktop'],{'rustdesk':'/fixed/test/rustdesk'},lambda path:self.launched.append(path) or True,lambda path,peer:self.handoffs.append((path,peer)) or True);self.port=self.server.server_address[1];self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
 def tearDown(self):self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
 def request(self,path='/health',token=None,method='GET',origin='null',port=None,data=None,content_type=None,challenge=None,private_network=False):
  headers={'Origin':origin};
  if token is not None:headers['Authorization']='Bearer '+token
  if content_type is not None:headers['Content-Type']=content_type
  if challenge is not None:headers[agent.ACTION_CHALLENGE_HEADER]=challenge
  if private_network:headers['Access-Control-Request-Private-Network']='true'
  payload=data.encode() if isinstance(data,str) else data;req=urllib.request.Request(f'http://127.0.0.1:{port or self.port}{path}',headers=headers,method=method,data=payload)
  try:
   with urllib.request.urlopen(req,timeout=2) as res:return res.status,dict(res.headers),res.read()
  except urllib.error.HTTPError as exc:return exc.code,dict(exc.headers),exc.read()
 def catalog(self,token=None,port=None):
  status,headers,body=self.request('/actions',token=token or self.token,port=port);self.assertEqual(status,200);return json.loads(body)
 def challenge(self,action_id,token=None,port=None):
  payload=self.catalog(token,port);row=next(x for x in payload['actions'] if x['id']==action_id);return row['challenge']
 def test_health_and_catalog_contract(self):
  self.assertEqual(self.request()[0],401);p=json.loads(self.request(token=self.token)[2]);self.assertEqual(p['agentVersion'],'0.7.0');self.assertNotIn('challenge',p);c=self.catalog();self.assertEqual(c['protocol'],'rah-node-actions-v2');self.assertEqual(c['approvalMode'],'command-center-local');self.assertEqual([x['id'] for x in c['actions']],['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  for row in c['actions']:
   self.assertEqual(row['challengeTtlSeconds'],60);self.assertRegex(row['challenge'],r'^[A-Za-z0-9_-]{24,64}$');
   for forbidden in ['url','command','arguments','executable','password','peerId']:self.assertNotIn(forbidden,row)
 def test_storage_requires_action_bound_single_use_challenge(self):
  self.assertEqual(self.request('/storage',token=self.token)[0],428);c=self.catalog();storage=next(x for x in c['actions'] if x['id']=='storage-summary.read')['challenge'];launch=next(x for x in c['actions'] if x['id']=='rustdesk.launch')['challenge'];self.assertEqual(self.request('/storage',token=self.token,challenge=launch)[0],409);status,headers,body=self.request('/storage',token=self.token,challenge=storage);self.assertEqual(status,200);self.assertEqual(json.loads(body)['protocol'],'rah-node-storage-v1');self.assertEqual(self.request('/storage',token=self.token,challenge=storage)[0],409)
 def test_refresh_invalidates_previous_challenges(self):
  old=self.challenge('storage-summary.read');new=self.challenge('storage-summary.read');self.assertNotEqual(old,new);self.assertEqual(self.request('/storage',token=self.token,challenge=old)[0],409);self.assertEqual(self.request('/storage',token=self.token,challenge=new)[0],200)
 def test_rustdesk_launch_requires_challenge_and_no_body(self):
  self.assertEqual(self.request('/launch/rustdesk',token=self.token,method='POST')[0],428);ch=self.challenge('rustdesk.launch');self.assertEqual(self.request('/launch/rustdesk',token=self.token,method='POST',data='{}',challenge=ch)[0],400);ch=self.challenge('rustdesk.launch');status,headers,body=self.request('/launch/rustdesk',token=self.token,method='POST',challenge=ch);self.assertEqual(status,200);self.assertEqual(json.loads(body),{'protocol':'rah-node-launch-v1','status':'launched','app':'rustdesk'});self.assertEqual(self.launched,['/fixed/test/rustdesk']);self.assertEqual(self.request('/launch/rustdesk',token=self.token,method='POST',challenge=ch)[0],409)
 def test_handoff_requires_challenge_peer_id_only_and_never_password(self):
  ch=self.challenge('rustdesk.connect');self.assertEqual(self.request('/handoff/rustdesk',token=self.token,method='POST',challenge=ch,data='{"peerId":"123456789","password":"secret"}',content_type='application/json')[0],400);ch=self.challenge('rustdesk.connect');self.assertEqual(self.request('/handoff/rustdesk',token=self.token,method='POST',challenge=ch,data='{"peerId":"123456789 --password secret"}',content_type='application/json')[0],400);ch=self.challenge('rustdesk.connect');status,headers,body=self.request('/handoff/rustdesk',token=self.token,method='POST',challenge=ch,data='{"peerId":"123456789"}',content_type='application/json');self.assertEqual(status,200);self.assertEqual(json.loads(body),{'protocol':'rah-node-handoff-v1','status':'handoff-started','app':'rustdesk'});self.assertEqual(self.handoffs,[('/fixed/test/rustdesk','123456789')]);self.assertEqual(self.request('/handoff/rustdesk',token=self.token,method='POST',challenge=ch,data='{"peerId":"123456789"}',content_type='application/json')[0],409)
 def test_expiry_helper_and_action_binding(self):
  state={};lock=threading.Lock();base={'protocol':agent.ACTIONS_PROTOCOL,'status':'ready','actions':[agent.ACTION_CATALOG['storage-summary.read']],'approvalMode':'command-center-local'};p=agent.issue_action_challenges(base,state,lock,60,now=100);ch=p['actions'][0]['challenge'];self.assertEqual(agent.consume_action_challenge(state,lock,'storage-summary.read',ch,now=161),'invalid');p=agent.issue_action_challenges(base,state,lock,60,now=200);ch=p['actions'][0]['challenge'];self.assertEqual(agent.consume_action_challenge(state,lock,'rustdesk.launch',ch,now=201),'invalid');self.assertEqual(agent.consume_action_challenge(state,lock,'storage-summary.read',ch,now=201),'ok');self.assertEqual(agent.consume_action_challenge(state,lock,'storage-summary.read',ch,now=202),'invalid')
 def test_capability_and_fixed_endpoint_boundaries(self):
  token='compute-only-token-abcdefghijklmnopqrstuvwxyz';server=agent.create_server('127.0.0.1',0,token,'Compute','Read only',['compute'],{'rustdesk':'/fixed/test/rustdesk'},lambda path:True,lambda path,peer:True);port=server.server_address[1];thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
  try:self.assertEqual(self.catalog(token,port)['actions'],[]);self.assertEqual(self.request('/storage',token=token,port=port)[0],403);self.assertEqual(self.request('/launch/rustdesk',token=token,method='POST',port=port)[0],403);self.assertEqual(self.request('/handoff/rustdesk',token=token,method='POST',port=port,data='{"peerId":"123456789"}',content_type='application/json')[0],403)
  finally:server.shutdown();server.server_close();thread.join(timeout=2)
  for path in ['/command','/action','/action/run','/files','/shell','/launch','/launch/calc','/handoff','/connect','/remote-control']:self.assertEqual(self.request(path,token=self.token)[0],404,path)
 def test_cors_and_source_safety(self):
  for path in ['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']:
   status,headers,_=self.request(path,method='OPTIONS',private_network=True);self.assertEqual(status,204);self.assertIn(agent.ACTION_CHALLENGE_HEADER,headers.get('Access-Control-Allow-Headers',''))
  source=(ROOT/'rah-node-agent.py').read_text();self.assertIn('subprocess.Popen([path,"--connect",peer_id]',source);self.assertIn('"shell":False',source);self.assertNotIn('os.system',source);self.assertNotIn('shell=True',source);self.assertNotIn('"--password"',source);self.assertNotIn('/action/run',source)
if __name__=='__main__':unittest.main()
