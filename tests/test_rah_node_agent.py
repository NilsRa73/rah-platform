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
  self.assertEqual(self.request()[0],401);status,headers,body=self.request(token=self.token);self.assertEqual(status,200);payload=json.loads(body);self.assertEqual(payload['agentVersion'],'0.4.0');self.assertEqual(payload['capabilities'],['compute','storage']);self.assertEqual(payload['permissions'],{'healthRead':True,'capabilityRead':True,'actionCatalogRead':True,'storageRead':True,'commands':False,'files':False,'shell':False,'remoteControl':False});self.assertNotIn('token',payload)
 def test_action_catalog_is_fixed_authenticated_and_non_mutating(self):
  self.assertEqual(self.request('/actions')[0],401);status,headers,body=self.request('/actions',token=self.token);self.assertEqual(status,200);payload=json.loads(body);self.assertEqual(payload['protocol'],'rah-node-actions-v1');self.assertEqual(payload['status'],'ready');self.assertEqual(payload['approvalMode'],'command-center-local');self.assertEqual(payload['actions'],[{'id':'storage-summary.read','label':'Read system-volume storage','capability':'storage','method':'GET','path':'/storage','scope':'system-volume','mutating':False}]);self.assertNotIn('url',payload['actions'][0]);self.assertNotIn('command',payload['actions'][0])
 def test_storage_summary_is_fixed_read_only_payload(self):
  self.assertEqual(self.request('/storage')[0],401);status,headers,body=self.request('/storage',token=self.token);self.assertEqual(status,200);payload=json.loads(body);self.assertEqual(payload['protocol'],'rah-node-storage-v1');self.assertEqual(payload['status'],'ok');self.assertEqual(payload['scope'],'system-volume');self.assertIsInstance(payload['totalBytes'],int);self.assertIsInstance(payload['usedBytes'],int);self.assertIsInstance(payload['freeBytes'],int);self.assertGreaterEqual(payload['totalBytes'],payload['usedBytes']);self.assertNotIn('files',payload);self.assertNotIn('entries',payload);self.assertNotIn('requestedPath',payload)
 def test_storage_and_action_catalog_follow_explicit_capability(self):
  token='compute-only-token-abcdefghijklmnopqrstuvwxyz';server=agent.create_server('127.0.0.1',0,token,'Compute','Read only',['compute']);port=server.server_address[1];thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
  try:self.assertEqual(self.request('/storage',token=token,port=port)[0],403);health=json.loads(self.request('/health',token=token,port=port)[2]);actions=json.loads(self.request('/actions',token=token,port=port)[2]);self.assertFalse(health['permissions']['storageRead']);self.assertEqual(actions['actions'],[])
  finally:server.shutdown();server.server_close();thread.join(timeout=2)
 def test_only_health_actions_and_storage_get_are_exposed(self):
  for path in ['/command','/action','/action/run','/capabilities','/files','/shell']:self.assertEqual(self.request(path,token=self.token)[0],404,path)
  for path in ['/health','/actions','/storage']:self.assertEqual(self.request(path,token=self.token,method='POST')[0],405,path)
 def test_origin_allowlist_and_private_network_preflight(self):
  self.assertEqual(self.request(token=self.token,origin='https://evil.example')[0],403)
  for path in ['/health','/actions','/storage']:
   status,headers,_=self.request(path,method='OPTIONS',private_network=True);self.assertEqual(status,204);self.assertEqual(headers.get('Access-Control-Allow-Private-Network'),'true');self.assertEqual(headers.get('Access-Control-Allow-Origin'),'null')
 def test_capability_and_action_allowlists(self):
  self.assertEqual(agent.sanitize_capabilities(['compute','SHELL','display','remote-desktop','storage','compute']),['compute','display','remote-desktop','storage']);self.assertEqual(agent.ALLOWED_CAPABILITIES,('compute','storage','display','remote-desktop'));self.assertEqual(tuple(agent.ACTION_CATALOG.keys()),('storage-summary.read',));self.assertFalse(agent.ACTION_CATALOG['storage-summary.read']['mutating']);self.assertEqual(agent.ACTION_CATALOG['storage-summary.read']['path'],'/storage')
 def test_fixed_contract(self):
  self.assertEqual(agent.PORT,18766);self.assertEqual(agent.PROTOCOL,'rah-node-health-v1');self.assertEqual(agent.STORAGE_PROTOCOL,'rah-node-storage-v1');self.assertEqual(agent.ACTIONS_PROTOCOL,'rah-node-actions-v1');self.assertNotIn('*',agent.ALLOWED_ORIGINS);self.assertEqual(agent.system_volume(),Path.home().anchor or '/');self.assertFalse(agent.build_permissions([])['storageRead']);self.assertTrue(agent.build_permissions(['storage'])['storageRead']);self.assertTrue(agent.build_permissions([])['actionCatalogRead']);self.assertFalse(agent.build_permissions(['storage'])['commands']);self.assertFalse(agent.build_permissions(['storage'])['files']);self.assertFalse(agent.build_permissions(['storage'])['shell']);self.assertFalse(agent.build_permissions(['storage'])['remoteControl'])
if __name__=='__main__':unittest.main()
