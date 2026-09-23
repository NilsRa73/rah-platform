import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(name: str) -> str:
    return (ROOT / name).read_text(encoding="utf-8")


class RavenCore7WorkerProofContract(unittest.TestCase):
    def test_worker_proof_files_and_install_contract(self):
        self.assertTrue((ROOT / "WORKER-PROOF.cmd").is_file())
        self.assertTrue((ROOT / "RAVEN-CORE-7-WORKER-PROOF.ps1").is_file())

        installer = read("INSTALL-RAVEN-CORE-7.cmd")
        self.assertIn("WORKER-PROOF.cmd", installer)
        self.assertIn("RAVEN-CORE-7-WORKER-PROOF.ps1", installer)

        launcher = read("WORKER-PROOF.cmd")
        self.assertIn("-Mode Prepare", launcher)
        self.assertIn("RAVEN-CORE-7-WORKER-PROOF.ps1", launcher)

    def test_worker_proof_validates_existing_evidence_only(self):
        ps1 = read("RAVEN-CORE-7-WORKER-PROOF.ps1")
        low = ps1.lower()

        self.assertIn("rah-2pc-real-hardware-acceptance-v1", ps1)
        self.assertIn("REAL-HARDWARE-ACCEPTANCE.json", ps1)
        self.assertIn("last-inventory.json", ps1)
        self.assertIn("Get-FileHash", ps1)
        self.assertIn("SHA256", ps1)
        self.assertIn("START-HER-RAH-2PC-GRID.cmd", ps1)

        # Core 7 may open the existing fixed GUI, but it must never consume
        # the fresh Node credential itself or introduce a remote transport.
        for forbidden in (
            "read-host",
            "invoke-webrequest",
            "invoke-restmethod",
            "new-netfirewallrule",
            "set-netfirewallrule",
            "remove-netfirewallrule",
            "invoke-expression",
            "tcpclient",
        ):
            self.assertNotIn(forbidden, low)

        self.assertNotIn("[string]$token", low)
        self.assertIn("tokenRead = $false", ps1)
        self.assertIn("tokenStored = $false", ps1)
        self.assertIn("networkDiscovery = $false", ps1)
        self.assertIn("remoteActionAdded = $false", ps1)

    def test_worker_pass_requires_strict_safety_evidence(self):
        ps1 = read("RAVEN-CORE-7-WORKER-PROOF.ps1")
        for marker in (
            "targetPort -ne 18766",
            "ravenPort -ne 18765",
            "readOnly -ne $true",
            "arbitraryCommands -ne $false",
            "callerArguments -ne $false",
            "tokenPersisted -ne $false",
            "localRavenHopOnly -ne $true",
            "Inventory SHA-256 no longer matches acceptance evidence.",
        ):
            self.assertIn(marker, ps1)

    def test_core_and_front_door_surface_worker_state(self):
        core = read("RAVEN-CORE-7.ps1")
        front = read("RAH-OS-CONTROL.ps1")
        acceptance = read("RAVEN-CORE-7-ACCEPTANCE.ps1")

        self.assertIn("worker-proof.json", core)
        self.assertIn("Worker Proof", core)
        self.assertIn("WORKER PROOF", front)
        self.assertIn("worker-proof.json", front)
        self.assertIn("rah-raven-core-7-worker-proof-v1", acceptance)
        self.assertIn("physicalSecondPcAcceptance = $physicalSecondPc", acceptance)


if __name__ == "__main__":
    unittest.main()
