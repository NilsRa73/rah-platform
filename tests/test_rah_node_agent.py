import importlib.util,json,threading,unittest,urllib.error,urllib.request
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];spec=importlib.util.spec_from_file_location('rah_node_agent',ROOT/'rah-node-agent.py');agent=importlib.util.module_from_spec(spec);spec.loader.exec_module(agent)
class NodeAgentTests(unittest.TestCase):
 def setUp(self):self.token='test-token-abcdefghijklmnopqrstuvwxyz';self.server=agent.create_server('127.0.0.1',0,self.token,'Test Node','Read only',['compute','shell','storage','compute']);self.port=self.server.server_address[1];self.thread=threading.Thread(target=self.server.serve_forever,daemon=True);self.thread.start()
 def tearDown(self):self.server.shutdown();self.server.server_close();self.thread.join(timeout=2)
 def request(self,path='/health',token=None,method='GET',origin='null',private_network=False,port=None):
  headers={'Origin':origin}
  if token is not None:headers['Authorization']='Bearer '+token
  if private_network:headers['Access-Control-Request-Private-Network']='true'
  req=urllib.request.Request(f'http://127.0.0.1:{port or self.port}{path}',headers=headers,method=method)
  try:
   with urllib.request.urlopen(req,timeout=2) as res:return res.status,dict(res.headers),res.read()
  except urllib.error.HTTPError as exc:return exc.code,dict(exc.headers),exc.read()
 def test_health_requires_bearer_token(self):
  self.assertEqual(self.request()[0],401);status,headers,body=self.request(token=self.token);self.assertEqual(status,200);payload=json.loads(body);self.assertEqual(payload['agentVersion'],'0.3.0');self.assertEqual(payload['capabilities'],['compute','storage']);self.assertEqual(payload['permissions'],{'healthRead':True,'capabilityRead':True,'storageRead':True,'commands':False,'files':False,'shell':False,'remoteControl':False});self.assertNotIn('token',payload)
 def test_storage_summary_is_fixed_read_only_payload(self):
  self.assertEqual(self.request('/storage')[0],401);status,headers,body=self.request('/storage',token=self.token);self.assertEqual(status,200);payload=json.loads(body);self.assertEqual(payload['protocol'],'rah-node-storage-v1');self.assertEqual(payload['status'],'ok');self.assertEqual(payload['scope'],'system-volume');self.assertIsInstance(payload['totalBytes'],int);self.assertIsInstance(payload['usedBytes'],int);self.assertIsInstance(payload['freeBytes'],int);self.assertGreaterEqual(payload['totalBytes'],payload['usedBytes']);self.assertNotIn('files',payload);self.assertNotIn('entries',payload);self.assertNotIn('requestedPath',payload)
 def test_storage_requires_explicit_storage_capability(self):
  token='compute-only-token-abcdefghijklmnopqrstuvwxyz';server=agent.create_server('127.0.0.1',0,token,'Compute','Read only',['compute']);port=server.server_address[1];thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
  try:self.assertEqual(self.request('/storage',token=token,port=port)[0],403);payload=json.loads(self.request('/health',token=token,port=port)[2]);self.assertFalse(payload['permissions']['storageRead'])
  finally:server.shutdown();server.server_close();thread.join(timeout=2)
 def test_only_health_and_storage_get_are_exposed(self):self.assertEqual(self.request('/command',token=self.token)[0],404);self.assertEqual(self.request('/capabilities',token=self.token)[0],404);self.assertEqual(self.request('/files',token=self.token)[0],404);self.assertEqual(self.request('/shell',token=self.token)[0],404);self.assertEqual(self.request('/health',token=self.token,method='POST')[0],405);self.assertEqual(self.request('/storage',token=self.token,method='POST')[0],405)
 def test_origin_allowlist_and_private_network_preflight(self):self.assertEqual(self.request(token=self.token,origin='https://evil.example')[0],403);status,headers,_=self.request(method='OPTIONS',private_network=True);self.assertEqual(status,204);self.assertEqual(headers.get('Access-Control-Allow-Private-Network'),'true');self.assertEqual(headers.get('Access-Control-Allow-Origin'),'null');status2,_,_=self.request('/storage',method='OPTIONS',private_network=True);self.assertEqual(status2,204)
 def test_capability_allowlist(self):self.assertEqual(agent.sanitize_capabilities(['compute','SHELL','display','remote-desktop','storage','compute']),['compute','display','remote-desktop','storage']);self.assertEqual(agent.ALLOWED_CAPABILITIES,('compute','storage','display','remote-desktop'))
 def test_fixed_contract(self):self.assertEqual(agent.PORT,18766);self.assertEqual(agent.PROTOCOL,'rah-node-health-v1');self.assertEqual(agent.STORAGE_PROTOCOL,'rah-node-storage-v1');self.assertNotIn('*',agent.ALLOWED_ORIGINS);self.assertEqual(agent.system_volume(),Path.home().anchor or '/');self.assertFalse(agent.build_permissions([])['storageRead']);self.assertTrue(agent.build_permissions(['storage'])['storageRead']);self.assertFalse(agent.build_permissions(['storage'])['commands']);self.assertFalse(agent.build_permissions(['storage'])['files']);self.assertFalse(agent.build_permissions(['storage'])['shell']);self.assertFalse(agent.build_permissions(['storage'])['remoteControl'])
if __name__=='__main__':unittest.main()
