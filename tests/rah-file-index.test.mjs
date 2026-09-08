import assert from 'node:assert/strict';
import fs from 'node:fs';

const runner = fs.readFileSync('desktop-bridge/agent_runner.py', 'utf8');
const indexer = fs.readFileSync('desktop-bridge/rah_file_index.py', 'utf8');

assert.match(runner, /"rah-file-index": Capability/);
assert.match(runner, /title="RAH filindeks"/);
assert.match(runner, /def _rah_file_index\(\)/);
assert.match(runner, /rah_file_index\.collect_index\(\)/);
assert.match(runner, /capability\.id == "rah-file-index"/);

assert.match(indexer, /INDEX_VERSION = "1\.0\.0"/);
assert.match(indexer, /MAX_ENTRIES = 300/);
assert.match(indexer, /MAX_DEPTH = 4/);
assert.match(indexer, /def fixed_roots\(\)/);
assert.match(indexer, /pathlib\.Path\(r"C:\\RAH"\)/);
assert.match(indexer, /path\.stat\(follow_symlinks=False\)/);
assert.match(indexer, /child\.is_symlink\(\)/);
assert.match(indexer, /"contents_read": False/);
assert.match(indexer, /"symlinks_followed": False/);
assert.match(indexer, /"arbitrary_paths": False/);
assert.match(indexer, /"file_writes": False/);
assert.doesNotMatch(indexer, /open\s*\(/);
assert.doesNotMatch(indexer, /read_text|read_bytes|readline|readlines/);
assert.doesNotMatch(indexer, /subprocess|socket|urllib|requests/);

console.log('RAH file index is bounded to fixed RAH roots, metadata-only, no-content and no-write.');
