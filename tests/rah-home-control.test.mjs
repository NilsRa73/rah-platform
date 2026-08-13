import assert from 'node:assert/strict';import fs from 'node:fs';
const html=fs.readFileSync('RAH-HOME-CONTROL.html','utf8');const manifest=JSON.parse(fs.readFileSync('RAH-HOME-CONTROL-VERSION.json','utf8'));
assert.equal(manifest.product,'RAH Home Control');assert.equal(manifest.version,'1.14.0');assert.equal(manifest.local_only,true);assert.equal(manifest.features.device_mutations_transaction_safe,true);assert.equal(manifest.features.room_screen_node_mutations_transaction_safe,true);assert.equal(manifest.features.all_primary_local_status_mutations_transaction_safe,true);assert.equal(manifest.features.automatic_network_discovery,false);assert.equal(manifest.features.automatic_task_execution,false);assert.equal(manifest.features.external_network_calls,false);
assert.match(html,/stabil lokal kontroll v1\.14/);assert.match(html,/Romstatusen ble rullet tilbake/);assert.match(html,/Statusendringen ble rullet tilbake/);assert.match(html,/Skjermstatusen ble rullet tilbake/);assert.match(html,/Node-statusen ble rullet tilbake/);
assert.doesNotMatch(html,/fetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon/,'Home Control v1.14 must not add external network activity.');
const script=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];assert.ok(script);new Function(script);
console.log('RAH Home Control v1.14: primary local controls remain transaction-safe and network-free.');
