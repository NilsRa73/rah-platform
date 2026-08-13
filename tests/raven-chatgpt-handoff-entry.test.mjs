import assert from "node:assert/strict";
import fs from "node:fs";
const now=fs.readFileSync("RAH-RAVEN-NOW-V2.html","utf8");
const studio=fs.readFileSync("RAH-RAVEN-START.html","utf8");
const core=fs.readFileSync("RAH-RAVEN-CORE-DEMO.html","utf8");
assert.match(now,/RAH Raven Now v2\.13/);
assert.match(studio,/RAH Raven Studio v2\.4/);
assert.match(now,/id="nowChatgptHandoff" href="RAH-RAVEN-CORE-DEMO\.html\?handoffFrom=now#chatgptHandoffCenter"/);
assert.match(studio,/id="studioChatgptHandoff" href="RAH-RAVEN-CORE-DEMO\.html\?handoffFrom=studio#chatgptHandoffCenter"/);
assert.match(core,/id="chatgptHandoffCenter"/);
const nowTag=(now.match(/<a class="btn" id="nowChatgptHandoff"[^>]*>/)||[])[0]||"";
const studioTag=(studio.match(/<a class="btn" id="studioChatgptHandoff"[^>]*>/)||[])[0]||"";
for(const tag of [nowTag,studioTag]){
  assert.ok(tag);
  assert.doesNotMatch(tag,/onclick=|data-launch=|handoffStatus=|handoffImage=/);
}
assert.equal((now.match(/id="nowChatgptHandoff"/g)||[]).length,1);
assert.equal((studio.match(/id="studioChatgptHandoff"/g)||[]).length,1);
assert.doesNotMatch(nowTag,/api\.openai\.com|chatgpt\.com\/backend/i);
assert.doesNotMatch(studioTag,/api\.openai\.com|chatgpt\.com\/backend/i);
console.log("Raven 2.0.25 exposes source-aware navigation-only ChatGPT Handoff entries in Now and Studio.");
