from __future__ import annotations

"""One-command, self-diagnosing acceptance runner for RAH Home Control Stable/MVP."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TEST_DIR = ROOT / "tests"
RUNTIME = ROOT / "RAH-HOME-CONTROL.html"
ROADMAP = ROOT / "RAH-HOME-CONTROL-ROADMAP.md"

CONTRACTS = [
    "test_home_control_stable_contract.py",
    "test_home_control_task_queue_contract.py",
    "test_home_control_reset_defaults_contract.py",
    "test_home_control_restore_backup_contract.py",
    "test_home_control_screen_status_contract.py",
    "test_home_control_node_status_contract.py",
    "test_home_control_room_status_contract.py",
    "test_home_control_device_status_contract.py",
    "test_home_control_add_device_contract.py",
    "test_home_control_edit_device_contract.py",
    "test_home_control_remove_device_contract.py",
    "test_home_control_filter_storage_contract.py",
    "test_home_control_main_storage_contract.py",
    "test_home_control_load_state_contract.py",
]


def fail(message: str) -> None:
    print(f"[FAIL] PRECHECK: {message}")
    raise SystemExit(2)


def main() -> int:
    print("=" * 68)
    print(" RAH HOME CONTROL v1.25 - FINAL/STABLE ACCEPTANCE")
    print("=" * 68)
    print(f"Python : {sys.version.split()[0]}")
    print(f"Repo   : {ROOT}")

    if not RUNTIME.is_file():
        fail("RAH-HOME-CONTROL.html mangler")
    if not ROADMAP.is_file():
        fail("RAH-HOME-CONTROL-ROADMAP.md mangler")

    missing = [name for name in CONTRACTS if not (TEST_DIR / name).is_file()]
    if missing:
        fail("manglende Stable-kontrakter: " + ", ".join(missing))

    discovered = sorted(p.name for p in TEST_DIR.glob("test_home_control_*_contract.py"))
    expected = sorted(CONTRACTS)
    unregistered = sorted(set(discovered) - set(expected))
    if unregistered:
        fail("nye Home Control-kontrakter er ikke registrert i acceptance-runneren: " + ", ".join(unregistered))

    print(f"[PASS] PRECHECK: runtime + roadmap + {len(CONTRACTS)} kontrakter funnet")
    print()

    failures: list[tuple[str, int]] = []
    for index, name in enumerate(CONTRACTS, 1):
        print(f"[{index:02d}/{len(CONTRACTS):02d}] {name}")
        result = subprocess.run([sys.executable, str(TEST_DIR / name)], cwd=ROOT)
        if result.returncode == 0:
            print("      -> PASS")
        else:
            print(f"      -> FAIL (exit {result.returncode})")
            failures.append((name, result.returncode))
        print()

    print("=" * 68)
    if failures:
        print(f"RAH HOME CONTROL FINAL/STABLE: FAIL ({len(failures)} feil)")
        for name, code in failures:
            print(f" - {name}: exit {code}")
        print("Minste fix: reparer bare kontraktene listet over og kjør denne runneren igjen.")
        return 1

    print(f"RAH HOME CONTROL FINAL/STABLE: PASS ({len(CONTRACTS)}/{len(CONTRACTS) kontrakter)")
    print("Punkt 1 er verifisert som lokal Stable/MVP.")
    print("Discovery, pairing, clustering, AI-utvidelser og Raven Vision er ikke del av denne gaten.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
