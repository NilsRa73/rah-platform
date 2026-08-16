import importlib.util
from pathlib import Path
import unittest

PATH=Path(__file__).resolve().parents[1]/'rah-node-agent-v1.0.py'
spec=importlib.util.spec_from_file_location('rah_node_agent_stable_v10',PATH)
mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)

class StableV10Tests(unittest.TestCase):
    def test_identity_protocol_and_fixed_surface(self):
        self.assertEqual(mod.AGENT_VERSION,'1.0.0')
        self.assertEqual(mod.ACTIONS_PROTOCOL,'rah-node-actions-v5')
        self.assertEqual(mod.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1')
        self.assertEqual(tuple(mod.ALLOWED_CAPABILITIES),('compute','storage','display','remote-desktop'))
        self.assertEqual(tuple(mod.MUTATING_ACTION_IDS),('rustdesk.launch','rustdesk.connect'))
        self.assertEqual(tuple(mod.ROUTES),('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'))
    def test_health_reports_stable_identity(self):
        payload=mod.build_health_payload('node','test',['remote-desktop'],'ABCDEFGHIJKLMNOPQRSTUVWX')
        self.assertEqual(payload['agentVersion'],'1.0.0')
    def test_headless_mutating_confirmation_fails_closed(self):
        coordinator=mod.LocalConfirmationCoordinator('ABCDEFGHIJKLMNOPQRSTUVWX',interactive=False,start_thread=False)
        result=coordinator.request('rustdesk.launch','')
        self.assertFalse(result['ok'])
        self.assertEqual(result['error'],'local_confirmation_unavailable')
    def test_fixed_input_digest_never_accepts_generic_action(self):
        self.assertEqual(mod.canonical_input_digest('shell',''), '')
        self.assertEqual(mod.canonical_input_digest('rustdesk.launch','unexpected'), '')
        self.assertTrue(mod.canonical_input_digest('rustdesk.launch',''))
        self.assertTrue(mod.canonical_input_digest('rustdesk.connect','123456789'))
    def test_handler_stable_server_identity(self):
        coordinator=mod.LocalConfirmationCoordinator('ABCDEFGHIJKLMNOPQRSTUVWX',interactive=False,start_thread=False)
        handler=mod.make_handler('token','node','test',['remote-desktop'],{'rustdesk':'C:/fixed/RustDesk.exe'},session_id='ABCDEFGHIJKLMNOPQRSTUVWX',coordinator=coordinator)
        self.assertEqual(handler.server_version,'RAHNodeAgent/1.0')

if __name__=='__main__':unittest.main()
