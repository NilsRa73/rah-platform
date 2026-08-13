from pathlib import Path
import json,re

html_path=Path('RAH-HOME-CONTROL.html')
html=html_path.read_text(encoding='utf-8')
assert 'grunnsystem v1.11' in html
html=html.replace('Punkt 1 · grunnsystem v1.11','Punkt 1 · grunnsystem v1.12')
html=html.replace('v1.11: trygg oppretting av nye enheter ved lagringsfeil. Neste: gjør de øvrige enhetsendringene like transaksjonssikre. Nettverkssøk og clustering står fortsatt i veikartet.','v1.12: oppretting, statusendring, redigering og fjerning av enheter er transaksjonssikre ved lagringsfeil. Neste: samme sikkerhetsmønster for rom, skjermer og noder. Nettverkssøk og clustering står fortsatt i veikartet.')

old_online="document.querySelectorAll('[data-online]').forEach(b=>b.onclick=()=>{const d=state.devices.find(x=>x.id===b.dataset.online);if(!d)return showError('Enheten finnes ikke lenger.');d.online=!d.online;save();renderAll()});"
new_online="document.querySelectorAll('[data-online]').forEach(b=>b.onclick=()=>{const d=state.devices.find(x=>x.id===b.dataset.online);if(!d)return showError('Enheten finnes ikke lenger.');hideActionNotice();const previousOnline=d.online;d.online=!d.online;if(!save()){d.online=previousOnline;showError('Statusendringen ble rullet tilbake fordi lokal lagring feilet.');}else showActionNotice(`Status for «${d.name}» er lagret lokalt.`);renderAll()});"
assert old_online in html
html=html.replace(old_online,new_online)

old_edit="document.querySelectorAll('[data-save-edit]').forEach(b=>b.onclick=()=>{const id=b.dataset.saveEdit,d=state.devices.find(x=>x.id===id);if(!d){editingDeviceId=null;showError('Enheten finnes ikke lenger.');return renderAll()}d.room=document.querySelector(`[data-edit-room=\"${id}\"]`).value;d.connection=document.querySelector(`[data-edit-connection=\"${id}\"]`).value;d.role=document.querySelector(`[data-edit-role=\"${id}\"]`).value;if(save())editingDeviceId=null;renderAll()});"
new_edit="document.querySelectorAll('[data-save-edit]').forEach(b=>b.onclick=()=>{const id=b.dataset.saveEdit,d=state.devices.find(x=>x.id===id);if(!d){editingDeviceId=null;showError('Enheten finnes ikke lenger.');return renderAll()}hideActionNotice();const previousDevice=clone(d);d.room=document.querySelector(`[data-edit-room=\"${id}\"]`).value;d.connection=document.querySelector(`[data-edit-connection=\"${id}\"]`).value;d.role=document.querySelector(`[data-edit-role=\"${id}\"]`).value;if(save()){editingDeviceId=null;showActionNotice(`Endringene for «${d.name}» er lagret lokalt.`);}else{Object.assign(d,previousDevice);showError('Redigeringen ble rullet tilbake fordi lokal lagring feilet. Redigeringspanelet er beholdt.');}renderAll()});"
assert old_edit in html
html=html.replace(old_edit,new_edit)

old_remove="document.querySelectorAll('[data-remove]').forEach(b=>b.onclick=()=>{const id=b.dataset.remove,d=state.devices.find(x=>x.id===id);if(!d)return showError('Enheten finnes ikke lenger.');if(!window.confirm(`Fjern «${d.name}» fra enhetsregisteret?`))return;state.devices=state.devices.filter(x=>x.id!==id);if(editingDeviceId===id)editingDeviceId=null;if(save())showActionNotice(`Enheten «${d.name}» ble fjernet.`);renderAll()})"
new_remove="document.querySelectorAll('[data-remove]').forEach(b=>b.onclick=()=>{const id=b.dataset.remove,d=state.devices.find(x=>x.id===id);if(!d)return showError('Enheten finnes ikke lenger.');if(!window.confirm(`Fjern «${d.name}» fra enhetsregisteret?`))return;hideActionNotice();const previousDevices=clone(state.devices),previousEditingDeviceId=editingDeviceId;state.devices=state.devices.filter(x=>x.id!==id);if(editingDeviceId===id)editingDeviceId=null;if(save())showActionNotice(`Enheten «${d.name}» ble fjernet og endringen er lagret lokalt.`);else{state.devices=previousDevices;editingDeviceId=previousEditingDeviceId;showError('Fjerningen ble rullet tilbake fordi lokal lagring feilet.');}renderAll()})"
assert old_remove in html
html=html.replace(old_remove,new_remove)
html_path.write_text(html,encoding='utf-8')

manifest_path=Path('RAH-HOME-CONTROL-VERSION.json')
m=json.loads(manifest_path.read_text(encoding='utf-8'))
assert m['version']=='1.11.0'
m['version']='1.12.0';m['stage']='working-transaction-safe-device-control';m['released_at']='2026-08-13'
m['features'].update({
  'device_status_storage_rollback':True,
  'device_edit_storage_rollback':True,
  'device_edit_context_preserved_on_storage_failure':True,
  'device_remove_storage_rollback':True,
  'device_remove_edit_context_restore':True,
  'device_mutations_transaction_safe':True
})
m['next_milestone']='transaction-safe-room-screen-node-mutations'
manifest_path.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

Path('tests/rah-home-control.test.mjs').write_text(r'''import assert from 'node:assert/strict';import fs from 'node:fs';
const html=fs.readFileSync('RAH-HOME-CONTROL.html','utf8');const manifest=JSON.parse(fs.readFileSync('RAH-HOME-CONTROL-VERSION.json','utf8'));
assert.equal(manifest.product,'RAH Home Control');assert.equal(manifest.version,'1.12.0');assert.equal(manifest.local_only,true);assert.equal(manifest.features.device_add_storage_rollback,true);assert.equal(manifest.features.device_status_storage_rollback,true);assert.equal(manifest.features.device_edit_storage_rollback,true);assert.equal(manifest.features.device_edit_context_preserved_on_storage_failure,true);assert.equal(manifest.features.device_remove_storage_rollback,true);assert.equal(manifest.features.device_remove_edit_context_restore,true);assert.equal(manifest.features.device_mutations_transaction_safe,true);assert.equal(manifest.features.automatic_network_discovery,false);assert.equal(manifest.features.automatic_task_execution,false);
assert.match(html,/grunnsystem v1\.12/);assert.match(html,/const previousDevices=clone\(state\.devices\)/);assert.match(html,/if\(!save\(\)\)\{state\.devices=previousDevices/);
const onlineStart=html.indexOf("document.querySelectorAll('[data-online]')"),editStart=html.indexOf("document.querySelectorAll('[data-save-edit]')"),removeStart=html.indexOf("document.querySelectorAll('[data-remove]')");assert.ok(onlineStart>0&&editStart>onlineStart&&removeStart>editStart);
const online=html.slice(onlineStart,html.indexOf("document.querySelectorAll('[data-edit]')",onlineStart));assert.match(online,/const previousOnline=d\.online/);assert.match(online,/if\(!save\(\)\)\{d\.online=previousOnline/);assert.match(online,/Statusendringen ble rullet tilbake/);
const edit=html.slice(editStart,removeStart);assert.match(edit,/const previousDevice=clone\(d\)/);assert.match(edit,/Object\.assign\(d,previousDevice\)/);assert.match(edit,/Redigeringen ble rullet tilbake/);assert.match(edit,/Redigeringspanelet er beholdt/);
const remove=html.slice(removeStart,html.indexOf('function renderScreens',removeStart));assert.match(remove,/const previousDevices=clone\(state\.devices\),previousEditingDeviceId=editingDeviceId/);assert.match(remove,/state\.devices=previousDevices/);assert.match(remove,/editingDeviceId=previousEditingDeviceId/);assert.match(remove,/Fjerningen ble rullet tilbake/);
assert.doesNotMatch(html,/fetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon/,'Home Control v1.12 must not add network activity.');
const script=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];assert.ok(script);new Function(script);
console.log('RAH Home Control v1.12: device add/status/edit/remove are transaction-safe on local storage failure.');
''',encoding='utf-8')
