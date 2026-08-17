import importlib.util
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location('rah_node_agent_v121_stable',ROOT/'rah-node-agent-v1.2.1.py')
agent=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(agent)
CTX='RequesterContext_abcdefghijklmnopqrstuvwxyz1234567890'
OTHER='RequesterContext_ZYXWVUTSRQPONMLKJIHGFEDCBA9876543210'
UNICODE='é'*40

class StableNode121Tests(unittest.TestCase):
    def test_identity_protocol_policy_and_exact_authority(self):
        self.assertEqual(agent.AGENT_VERSION,'1.2.1')
        self.assertEqual(agent.ACTIONS_PROTOCOL,'rah-node-actions-v6')
        self.assertEqual(agent.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(tuple(agent.ALLOWED_CAPABILITIES),('compute','storage','display','remote-desktop'))
        self.assertEqual(set(agent.ACTION_CATALOG),{'storage-summary.read','rustdesk.launch','rustdesk.connect'})
        self.assertEqual(tuple(agent.ROUTES),('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'))
    def test_health_reports_patch_identity(self):
        payload=agent.build_health_payload('node','test',['remote-desktop'],'ABCDEFGHIJKLMNOPQRSTUVWX')
        self.assertEqual(payload['agentVersion'],'1.2.1')
    def test_strict_ascii_context_is_inherited_from_promoted_blob(self):
        self.assertTrue(agent.valid_requester_context(CTX))
        self.assertFalse(agent.valid_requester_context(UNICODE))
        self.assertEqual(agent.requester_context_digest(UNICODE),'')
    def test_context_and_source_mismatch_preserve_pair_until_correct_consume(self):
        coordinator=agent.ContextBoundConfirmationCoordinator('SessionId_abcdefghijklmnop',interactive=True,input_func=lambda prompt:'y')
        result=coordinator.request('rustdesk.launch','','192.168.1.10',CTX);self.assertTrue(result.get('ok'),result);grant=result['grant']
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.10',OTHER),'requester_context_mismatch')
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.11',CTX),'requester_mismatch')
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.10',CTX),'ok')
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.10',CTX),'missing')
    def test_create_server_uses_patch_handler(self):
        coordinator=agent.ContextBoundConfirmationCoordinator('SessionId_abcdefghijklmnop',interactive=False,start_thread=False)
        server=agent.create_server('127.0.0.1',0,'token','node','test',['remote-desktop'],{'rustdesk':'C:/fixed/RustDesk.exe'},session_id='ABCDEFGHIJKLMNOPQRSTUVWX',coordinator=coordinator)
        try:
            self.assertEqual(server.RequestHandlerClass.server_version,'RAHNodeAgent/1.2.1')
            self.assertGreater(server.server_address[1],0)
        finally:server.server_close()
    def test_wrapper_uses_promoted_not_candidate_path(self):
        source=(ROOT/'rah-node-agent-v1.2.1.py').read_text(encoding='utf-8')
        self.assertIn("PROMOTED_PATH=Path(__file__).with_name('rah-node-agent-v1.2-promoted.py')",source)
        self.assertNotIn("with_name('rah-node-agent-v1.2-candidate.py')",source)

if __name__=='__main__':unittest.main()
