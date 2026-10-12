from __future__ import annotations

import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class RavenLmStudioRecoveryContractTests(unittest.TestCase):
    def test_recovery_uses_explicit_cpu_only_load(self):
        ps = (ROOT / "RAH-LM-STUDIO-RECOVERY.ps1").read_text(encoding="utf-8")
        self.assertIn("RahLmStudioRecoveryVersion = '1.1.0'", ps)
        self.assertIn("[ValidateSet('off','auto','max')][string]$GpuMode = 'off'", ps)
        self.assertIn("[int]$ContextLength = 4096", ps)
        self.assertIn("Invoke-RahExplicitModelLoad", ps)
        self.assertIn("'--gpu',$GpuMode", ps)
        self.assertIn("'--context-length',([string]$ContextLength)", ps)
        self.assertIn("result='LOAD_FAILED'", ps)
        self.assertIn("result='PROBE_FAILED'", ps)

    def test_process_runner_never_forces_empty_argument_list(self):
        ps = (ROOT / "RAH-LM-STUDIO-RECOVERY.ps1").read_text(encoding="utf-8")
        self.assertIn("[string[]]$Arguments=@()", ps)
        self.assertIn("if(-not [string]::IsNullOrWhiteSpace($joined))", ps)
        self.assertIn("$params['ArgumentList']=$joined", ps)
        self.assertNotIn(
            "Start-Process -FilePath $File -ArgumentList ($quoted -join ' ')",
            ps,
        )

    def test_recovery_prefers_gemma_3_4b_family(self):
        ps = (ROOT / "RAH-LM-STUDIO-RECOVERY.ps1").read_text(encoding="utf-8")
        self.assertIn("'gemma-3-4b-it','gemma-3-4b'", ps)


if __name__ == "__main__":
    unittest.main()
