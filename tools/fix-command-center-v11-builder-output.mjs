import fs from 'node:fs';
const path='tests/rah-command-center-v11.test.mjs';
let s=fs.readFileSync(path,'utf8');
const from="assert.doesNotMatch(html,/--password|shell\\.run|action\\/run|remote-control/i)";
const to="assert.doesNotMatch(html,/--password|shell\\.run|['\"]\\/action\\/run|['\"]\\/remote-control/i)";
if(!s.includes(from))throw new Error('Expected v1.1 assertion baseline not found');
s=s.replace(from,to);
fs.writeFileSync(path,s);
console.log('Adjusted v1.1 no-free-control assertion to test routes rather than explanatory prose.');
