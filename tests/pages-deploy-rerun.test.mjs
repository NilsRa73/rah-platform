import assert from 'node:assert/strict';
import fs from 'node:fs';

const workflow = fs.readFileSync('.github/workflows/static.yml', 'utf8');

assert.match(workflow, /^name: Deploy static content to Pages$/m);
assert.match(workflow, /push:\n\s+branches: \["main"\]/);
assert.match(workflow, /workflow_dispatch:/);
assert.match(workflow, /contents: read/);
assert.match(workflow, /pages: write/);
assert.match(workflow, /id-token: write/);
assert.match(workflow, /group: "pages"/);
assert.match(workflow, /cancel-in-progress: false/);
assert.match(workflow, /uses: actions\/checkout@v4/);
assert.match(workflow, /uses: actions\/configure-pages@v5/);
assert.match(workflow, /uses: actions\/upload-pages-artifact@v3/);
assert.match(workflow, /uses: actions\/deploy-pages@v5/);
assert.match(workflow, /path: '\.'/);

const uploadName = workflow.match(/uses: actions\/upload-pages-artifact@v3[\s\S]*?\n\s+name: ([^\n]+)/)?.[1]?.trim();
const deployName = workflow.match(/uses: actions\/deploy-pages@v5[\s\S]*?\n\s+artifact_name: ([^\n]+)/)?.[1]?.trim();
assert.equal(uploadName, 'github-pages-${{ github.run_attempt }}');
assert.equal(deployName, uploadName, 'deploy-pages must select exactly the artifact uploaded by this run attempt');
assert.notEqual(uploadName, 'github-pages');

const fixedDefaultNames = [...workflow.matchAll(/\b(?:name|artifact_name):\s+github-pages\s*$/gm)];
assert.equal(fixedDefaultNames.length, 0, 'fixed github-pages artifact name makes failed-job reruns ambiguous');

console.log('GitHub Pages rerun artifact uniqueness contract PASS');
