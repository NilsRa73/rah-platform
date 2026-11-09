#!/usr/bin/env python3
import os,pathlib,subprocess,tempfile,unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]
SCRIPT=ROOT/'config/includes.chroot/usr/local/bin/raven-flash-status'

class Status(unittest.TestCase):
    def fixture(self, connected=True, ai=True):
        td=tempfile.TemporaryDirectory(); root=pathlib.Path(td.name); binp=root/'bin'; binp.mkdir()
        def cmd(name,body):
            p=binp/name;p.write_text('#!/bin/sh\n'+body+'\n');p.chmod(0o755)
        cmd('nmcli',"echo connected" if connected else "echo disconnected")
        cmd('ip',"echo 'eth0 UP 192.0.2.5/24'")
        cmd('curl',"echo '{\"data\":[{\"id\":\"qwen-r15-test\"}]}'" if ai else "exit 22")
        env={**os.environ,'HOME':str(root/'home'),'XDG_DATA_HOME':str(root/'data'),'PATH':str(binp)+':'+os.environ['PATH']}
        subprocess.run(['sh',str(SCRIPT)],env=env,check=True,capture_output=True,text=True)
        page=(root/'data/raven-flash/status.html').read_text()
        return td,page
    def test_online_model_is_measured(self):
        td,page=self.fixture(True,True)
        try:
            self.assertIn('Nettverk: ONLINE',page);self.assertIn('Lokal AI: FOUND',page);self.assertIn('qwen-r15-test',page)
        finally: td.cleanup()
    def test_offline_and_missing_ai_are_not_false_pass(self):
        td,page=self.fixture(False,False)
        try:
            self.assertIn('Nettverk: OFFLINE',page);self.assertIn('Lokal AI: NOT_FOUND',page);self.assertNotIn('Lokal AI: PASS',page)
        finally: td.cleanup()
if __name__=='__main__': unittest.main()
