from pathlib import Path
import json,re

html_path=Path('RAH-HOME-CONTROL.html')
html=html_path.read_text(encoding='utf-8')
assert 'grunnsystem v1.10' in html
html=html.replace('Punkt 1 · grunnsystem v1.10','Punkt 1 · grunnsystem v1.11')
html=html.replace('Neste oppgave: gjør oppretting av en ny enhet trygg ved lagringsfeil. Nettverkssøk og clustering står fortsatt i veikartet.','v1.11: trygg oppretting av nye enheter ved lagringsfeil. Neste: gjør de øvrige enhetsendringene like transaksjonssikre. Nettverkssøk og clustering står fortsatt i veikartet.')
pattern=r"addDevice\.onclick=\(\)=>\{.*?\};devName\.oninput=\(\)=>devName\.removeAttribute\('aria-invalid'\);"
match=re.search(pattern,html,flags=re.S)
assert match, 'addDevice handler not found'
replacement="""addDevice.onclick=()=>{const name=devName.value.trim(),ip=devIp.value.trim();hideActionNotice();devName.removeAttribute('aria-invalid');devIp.removeAttribute('aria-invalid');if(!name){devName.setAttribute('aria-invalid','true');devName.focus();return showError('Skriv inn et navn før enheten legges til.')}if(ip&&!isValidIPv4(ip)){devIp.setAttribute('aria-invalid','true');devIp.focus();return showError('Ugyldig IPv4-adresse.')}const duplicateName=state.devices.find(d=>normalizeName(d.name)===normalizeName(name));if(duplicateName){devName.setAttribute('aria-invalid','true');devName.focus();return showError(`Enheten «${duplicateName.name}» bruker allerede dette navnet.`)}const duplicateIp=ip&&state.devices.find(d=>d.ip===ip);if(duplicateIp){devIp.setAttribute('aria-invalid','true');devIp.focus();return showError(`IPv4-adressen ${ip} er allerede registrert på «${duplicateIp.name}».`)}const previousDevices=clone(state.devices);const candidate={id:createUniqueDeviceId(),name,room:devRoom.value,type:devType.value,ip:ip||'Ikke satt',connection:devConnection.value,role:devRole.value,online:false};state.devices.push(candidate);if(!save()){state.devices=previousDevices;showError('Enheten ble ikke lagt til fordi lokal lagring feilet. Skjemaet er beholdt slik at du kan prøve igjen.');renderAll();return;}devName.value='';devIp.value='';showActionNotice(`Enheten «${candidate.name}» er lagt til og lagret lokalt.`);renderAll()};devName.oninput=()=>devName.removeAttribute('aria-invalid');"""
html=re.sub(pattern,replacement,html,count=1,flags=re.S)
html_path.write_text(html,encoding='utf-8')

manifest={
  'product':'RAH Home Control',
  'version':'1.11.0',
  'stage':'working-safe-local-control',
  'released_at':'2026-08-13',
  'entry':'RAH-HOME-CONTROL.html',
  'local_only':True,
  'features':{
    'room_state':True,'device_registry':True,'device_filters':True,'spacedesk_registry':True,'cluster_registry':True,'night_task_queue':True,
    'device_add_validation':True,'device_add_unique_name':True,'device_add_unique_ipv4':True,'device_add_storage_rollback':True,
    'device_add_form_preserved_on_storage_failure':True,'device_add_form_cleared_only_after_persist':True,'automatic_network_discovery':False,'automatic_task_execution':False
  },
  'next_milestone':'transaction-safe-device-mutations'
}
Path('RAH-HOME-CONTROL-VERSION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

Path('tests/rah-home-control.test.mjs').write_text(r'''import assert from 'node:assert/strict';import fs from 'node:fs';
const html=fs.readFileSync('RAH-HOME-CONTROL.html','utf8');const manifest=JSON.parse(fs.readFileSync('RAH-HOME-CONTROL-VERSION.json','utf8'));
assert.equal(manifest.product,'RAH Home Control');assert.equal(manifest.version,'1.11.0');assert.equal(manifest.local_only,true);assert.equal(manifest.features.device_add_storage_rollback,true);assert.equal(manifest.features.device_add_form_preserved_on_storage_failure,true);assert.equal(manifest.features.device_add_form_cleared_only_after_persist,true);assert.equal(manifest.features.automatic_network_discovery,false);assert.equal(manifest.features.automatic_task_execution,false);
assert.match(html,/grunnsystem v1\.11/);assert.match(html,/const previousDevices=clone\(state\.devices\)/);assert.match(html,/const candidate=\{id:createUniqueDeviceId\(\)/);assert.match(html,/state\.devices\.push\(candidate\)/);assert.match(html,/if\(!save\(\)\)\{state\.devices=previousDevices/);assert.match(html,/Skjemaet er beholdt slik at du kan prøve igjen/);assert.match(html,/Enheten «\$\{candidate\.name\}» er lagt til og lagret lokalt/);
const addStart=html.indexOf('addDevice.onclick=()=>{'),addEnd=html.indexOf("devName.oninput=",addStart);assert.ok(addStart>0&&addEnd>addStart);const add=html.slice(addStart,addEnd);const persistGuard=add.indexOf('if(!save())');const clearName=add.indexOf("devName.value=''");const clearIp=add.indexOf("devIp.value=''");assert.ok(persistGuard>0&&clearName>persistGuard&&clearIp>persistGuard,'Form fields must clear only after successful persistence guard.');assert.ok(add.indexOf('state.devices=previousDevices')>persistGuard,'Rollback must occur only on save failure.');
assert.doesNotMatch(html,/fetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon/,'Home Control v1.11 must not add network activity.');
const script=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];assert.ok(script);new Function(script);
console.log('RAH Home Control v1.11: safe device add rolls back on storage failure and preserves form input.');
''',encoding='utf-8')
