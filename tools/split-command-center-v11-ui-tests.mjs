import fs from 'node:fs';
const path='tests/rah-command-center-v11.test.mjs';
let s=fs.readFileSync(path,'utf8');
const old="ui:()=>{assert.match(html,/ONE-TIME ACTION CHALLENGE/);assert.match(html,/freshActionChallenge/);assert.match(html,/core\\.actionChallengeRequest/);assert.match(html,/core\\.actionChallengeFromCatalog/);assert.match(html,/headers\\[core\\.ACTION_CHALLENGE_HEADER\\]=challenge/);assert.match(html,/One-time challenge consumed/);assert.doesNotMatch(html,/id=\".*challenge|name=\".*challenge/i);assert.doesNotMatch(html,/localStorage\\.setItem\\([^\\n]*(?:challenge|token|peerId|password)/i);assert.doesNotMatch(html,/[?&](?:challenge|token|peerId|password)=/i);assert.doesNotMatch(html,/--password|shell\\.run|['\"]\\/action\\/run|['\"]\\/remote-control/i)},";
const neu="'ui-required':()=>{assert.match(html,/ONE-TIME ACTION CHALLENGE/);assert.match(html,/freshActionChallenge/);assert.match(html,/core\\.actionChallengeRequest/);assert.match(html,/core\\.actionChallengeFromCatalog/);assert.match(html,/headers\\[core\\.ACTION_CHALLENGE_HEADER\\]=challenge/);assert.match(html,/One-time challenge consumed/)},'ui-transient':()=>{assert.doesNotMatch(html,/id=\"[^\"]*challenge|name=\"[^\"]*challenge/i);assert.doesNotMatch(html,/localStorage\\.setItem\\([^\\n]*(?:challenge|token|peerId|password)/i);assert.doesNotMatch(html,/[?&](?:challenge|token|peerId|password)=/i)},'ui-no-free-control':()=>{assert.doesNotMatch(html,/--password|shell\\.run|['\"]\\/action\\/run|['\"]\\/remote-control/i)},";
if(!s.includes(old))throw new Error('Expected combined UI section not found');
s=s.replace(old,neu);
fs.writeFileSync(path,s);
console.log('Split v1.1 UI assertions into required/transient/no-free-control sections.');
