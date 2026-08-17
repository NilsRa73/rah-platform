import importlib.util
from pathlib import Path
import unittest

PATH=Path(__file__).resolve().parents[1]/'rah-node-agent-v1.1.py'
spec=importlib.util.spec_from_file_location('rah_node_agent_stable_v11',PATH)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

class StableV11Tests(unittest.TestCase):
    def test_identity_protocol_policy_and_fixed_surface(self):
        self.assertEqual(mod.AGENT_VERSION,'1.1.0')
        self.assertEqual(mod.ACTIONS_PROTOCOL,'rah-node-actions-v5')
        self.assertEqual(mod.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(tuple(mod.ALLOWED_CAPABILITIES),('compute','storage','display','remote-desktop'))
        self.assertEqual(tuple(mod.MUTATING_ACTION_IDS),('rustdesk.launch','rustdesk.connect'))
        self.assertEqual(tuple(mod.ROUTES),('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'))

    def test_health_reports_stable_identity(self):
        payload=mod.build_health_payload('node','test',['remote-desktop'],'ABCDEFGHIJKLMNOPQRSTUVWX')
        self.assertEqual(payload['agentVersion'],'1.1.0')

    def test_requester_source_policy_is_ipv4_loopback_or_rfc1918_only(self):
        self.assertEqual(mod.normalize_requester_source('127.0.0.1'),'127.0.0.1')
        self.assertEqual(mod.normalize_requester_source('10.1.2.3'),'10.1.2.3')
        self.assertEqual(mod.normalize_requester_source('172.31.1.2'),'172.31.1.2')
        self.assertEqual(mod.normalize_requester_source('192.168.1.2'),'192.168.1.2')
        self.assertEqual(mod.normalize_requester_source('8.8.8.8'),'')
        self.assertEqual(mod.normalize_requester_source('::1'),'')

    def test_source_bound_pair_rejects_wrong_requester_and_consumes_once_for_correct_requester(self):
        tokens=iter(['challenge-AAAAAAAAAAAAAAAAAAAA','proof-BBBBBBBBBBBBBBBBBBBBBBBB'])
        coordinator=mod.SourceBoundConfirmationCoordinator(
            'ABCDEFGHIJKLMNOPQRSTUVWX',interactive=True,input_func=lambda prompt:'yes',
            token_func=lambda:next(tokens),cooldown_seconds=0,start_thread=True,
        )
        result=coordinator.request('rustdesk.launch','','192.168.1.20')
        self.assertTrue(result['ok'])
        grant=result['grant']
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.21'),'requester_mismatch')
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.20'),'ok')
        self.assertEqual(coordinator.consume('rustdesk.launch','',grant['challenge'],grant['localApprovalProof'],'192.168.1.20'),'missing')

    def test_headless_mutating_confirmation_fails_closed(self):
        coordinator=mod.SourceBoundConfirmationCoordinator('ABCDEFGHIJKLMNOPQRSTUVWX',interactive=False,start_thread=False)
        result=coordinator.request('rustdesk.launch','','127.0.0.1')
        self.assertFalse(result['ok'])
        self.assertEqual(result['error'],'local_confirmation_unavailable')

    def test_fixed_input_digest_never_accepts_generic_action(self):
        self.assertEqual(mod.canonical_input_digest('shell',''), '')
        self.assertEqual(mod.canonical_input_digest('rustdesk.launch','unexpected'), '')
        self.assertTrue(mod.canonical_input_digest('rustdesk.launch',''))
        self.assertTrue(mod.canonical_input_digest('rustdesk.connect','123456789'))

    def test_handler_stable_server_identity(self):
        coordinator=mod.SourceBoundConfirmationCoordinator('ABCDEFGHIJKLMNOPQRSTUVWX',interactive=False,start_thread=False)
        handler=mod.make_handler('token','node','test',['remote-desktop'],{'rustdesk':'C:/fixed/RustDesk.exe'},session_id='ABCDEFGHIJKLMNOPQRSTUVWX',coordinator=coordinator)
        self.assertEqual(handler.server_version,'RAHNodeAgent/1.1')

if __name__=='__main__':unittest.main()