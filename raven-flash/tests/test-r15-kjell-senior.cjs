'use strict';
const fs=require('node:fs');
const assert=require('node:assert/strict');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../config/includes.chroot/opt/raven-flash');
const html=fs.readFileSync(path.join(root,'kjell-senior.html'),'utf8');
const session=fs.readFileSync(path.join(__dirname,'../config/includes.chroot/usr/local/bin/raven-flash-session'),'utf8');
const menu=fs.readFileSync(path.join(root,'menu.xml'),'utf8');
const start=fs.readFileSync(path.join(root,'start.html'),'utf8');
assert.ok(html.includes('lang="nb"'));
assert.ok(html.includes("connect-src 'none'"));
assert.ok(html.includes("default-src 'none'"));
for (const id of ['mail','news','weather','notes','radio','photos','help','desktops']) {
  assert.ok(html.includes('data-action="'+id+'"'),id);
  assert.ok(html.includes('id="tpl-'+id+'"'),id);
}
assert.ok(html.includes("KJELL-NOTAT.txt"));
assert.ok(html.includes("RAH Raven Flash"));
assert.ok(html.includes("Datamaskintest: IKKE TESTET"));
assert.ok(html.includes('five-desktop.html#picasso'));
assert.ok(session.includes('file:///opt/raven-flash/kjell-senior.html'));
assert.ok(menu.includes('kjell-senior.html') && menu.includes('five-desktop.html#kjell') && menu.includes('hakoya.html'));
assert.ok(start.includes('kjell-senior.html'));
const inline=html.match(/<script>([\s\S]*?)<\/script>/);
assert.ok(inline);
new vm.Script(inline[1]);
console.log('PASS: Kjell Senior HTML offline contract, eight functions, JS parse and Linux session/menu integration');
