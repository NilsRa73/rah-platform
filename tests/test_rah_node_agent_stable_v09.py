import importlib.util
import json
import re
import threading
import unittest
import urllib.request
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
STABLE=ROOT/'rah-node-agent-v0.9.py'
spec=importlib.util.spec_from_file_location('rah_node_agent_stable_v09',STABLE)
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class StableV09Tests(unittest.TestCase):
    def test_versions_policy_and_authority_surface_are_pinned(self):
        self.assertEqual(module.AGENT_VERSION,'0.9.0')
        self.assertEqual(module.ACTIONS_PROTOCOL,'rah-node-actions-v4')
        self.assertEqual(module.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(tuple(module.ALLOWED_CAPABILITIES),('compute','storage','display','remote-desktop'))
        self.assertEqual(set(module.ACTION_CATALOG),{'storage-summary.read','rustdesk.launch','rustdesk.connect'})

    def test_actions_payload_carries_policy_without_new_actions(self):
        payload=module.build_actions_payload(['compute','storage','display','remote-desktop'],{'rustdesk':'/fixed/rustdesk'},'ABCDEFGHIJKLMNOPQRSTUVWX')
        self.assertEqual(payload['protocol'],'rah-node-actions-v4')
        self.assertEqual(payload['policyId'],'rah-capability-allowlist-v1')
        self.assertEqual([row['id'] for row in payload['actions']],['storage-summary.read','rustdesk.launch','rustdesk.connect'])

    def test_fresh_challenge_preserves_policy_id(self):
        base=module.build_actions_payload(['storage'],{},'ABCDEFGHIJKLMNOPQRSTUVWX')
        state={}
        lock=threading.Lock()
        payload=module.issue_action_challenges(base,state,lock,ttl_seconds=60,now=10)
        self.assertEqual(payload['protocol'],'rah-node-actions-v4')
        self.assertEqual(payload['policyId'],'rah-capability-allowlist-v1')
        self.assertEqual([row['id'] for row in payload['actions']],['storage-summary.read'])
        self.assertTrue(payload['actions'][0]['challenge'])
        self.assertEqual(payload['actions'][0]['challengeTtlSeconds'],60)

    def test_live_actions_endpoint_is_policy_bound(self):
        token='stable-v09-test-token'
        server=module.create_server('127.0.0.1',0,token,capabilities=['storage'])
        thread=threading.Thread(target=server.serve_forever,daemon=True)
        thread.start()
        try:
            host,port=server.server_address
            request=urllib.request.Request(f'http://{host}:{port}/actions')
            request.add_header('Origin','http://127.0.0.1:18765')
            request.add_header('Authorization','Bearer '+token)
            with urllib.request.urlopen(request,timeout=3) as response:
                payload=json.loads(response.read().decode('utf-8'))
            self.assertEqual(payload['protocol'],'rah-node-actions-v4')
            self.assertEqual(payload['policyId'],'rah-capability-allowlist-v1')
            self.assertEqual([row['id'] for row in payload['actions']],['storage-summary.read'])
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=3)

    def test_no_new_generic_route_is_defined_by_v09_wrapper(self):
        source=STABLE.read_text(encoding='utf-8')
        forbidden_endpoint=re.compile(r'''["']/(?:shell|exec|command|commands|file|files|remote-control|remote_control|token|auth/refresh)(?:/|["'?])''',re.I)
        self.assertIsNone(forbidden_endpoint.search(source))
        self.assertIn('create_server=_base.create_server',source)
        self.assertIn("BASE_PATH=Path(__file__).with_name('rah-node-agent.py')",source)

if __name__=='__main__':
    unittest.main()
