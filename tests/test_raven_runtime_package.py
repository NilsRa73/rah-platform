"""Validate local Python dependency closure without importing Windows services."""
import ast
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
BRIDGE = ROOT / 'desktop-bridge'


def missing_dependencies(files):
    packaged = set(files)
    modules = {p.stem: p for p in BRIDGE.glob('*.py')}
    pending = [BRIDGE / Path(p).name for p in packaged
               if p.startswith('desktop-bridge/') and p.endswith('.py')]
    visited, missing = set(), set()
    while pending:
        path = pending.pop()
        if path in visited:
            continue
        visited.add(path)
        tree = ast.parse(path.read_text(encoding='utf-8-sig'))
        for node in ast.walk(tree):
            names = []
            if isinstance(node, ast.Import):
                names = [a.name.split('.')[0] for a in node.names]
            elif isinstance(node, ast.ImportFrom) and node.module:
                names = [node.module.split('.')[0]]
            for name in names:
                if name in modules:
                    dependency = 'desktop-bridge/' + modules[name].name
                    if dependency not in packaged:
                        missing.add(dependency)
                    pending.append(modules[name])
    return missing


class RuntimePackageTest(unittest.TestCase):
    def test_manifest_contains_transitive_local_imports(self):
        files = json.loads((ROOT / 'RAH-RAVEN-VERSION.json').read_text())['files']
        self.assertEqual(missing_dependencies(files), set())

    def test_detects_original_missing_module_regression(self):
        files = json.loads((ROOT / 'RAH-RAVEN-VERSION.json').read_text())['files']
        files = [p for p in files if not p.endswith('/hovedpc_local_status.py')]
        self.assertIn('desktop-bridge/hovedpc_local_status.py', missing_dependencies(files))


if __name__ == '__main__':
    unittest.main()
