from pathlib import Path
import json

html_path=Path('RAH-HOME-CONTROL.html')
html=html_path.read_text(encoding='utf-8')
assert 'grunnsystem v1.13' in html
html=html.replace('Punkt 1 · grunnsystem v1.13','Punkt 1 · stabil lokal kontroll v1.14')
old_footer='v1.13: rom, enheter, skjermer og cluster-noder rulles tilbake ved lokal lagringsfeil. Neste: stabilitetsgate og backup av Home Control-konfigurasjonen. Nettverkssøk og clustering står fortsatt i veikartet.'
new_footer='v1.14 Stable: lokal kontroll, rollback-sikkerhet og eksplisitt konfigurasjons-backup/restore er verifisert. Videre utvikling er satt på pause til en reell feil eller en eksplisitt ny fase åpnes.'
assert old_footer in html
html=html.replace(old_footer,new_footer)

old_ui='<section class="panel"><div class="buttons"><button id="addTask" class="primary">+ Testoppgave</button><button id="clearTasks">Tøm kø</button><button id="stopTasks">Stopp alle</button></div><div id="tasks" class="items"></div></section>\n<p class="footer">'
new_ui='''<section class="panel"><div class="buttons"><button id="addTask" class="primary">+ Testoppgave</button><button id="clearTasks">Tøm kø</button><button id="stopTasks">Stopp alle</button></div><div id="tasks" class="items"></div></section>
<div class="section-title"><div><h2>💾 Lokal konfigurasjon</h2><div class="sub">Eksporter eller gjenopprett Home Control-tilstanden. Backupen inneholder rom, enheter, skjermer, noder og den manuelle oppgavekøen — ikke andre Raven-data.</div></div><span class="pill">BACKUP v1</span></div>
<section class="panel"><div class="buttons"><button id="exportConfig" class="primary">Last ned backup</button><button id="importConfig">Gjenopprett backup</button><input id="configFile" type="file" accept="application/json,.json" hidden></div><div class="sub" style="margin-top:10px">Gjenoppretting valideres først og krever eksplisitt bekreftelse. Visningsfiltre er ikke en del av backupen.</div></section>
<p class="footer">'''
assert old_ui in html
html=html.replace(old_ui,new_ui)

old_const="const KEY='rah-home-control-v03',FILTER_KEY='rah-home-control-filters-v01',clone=x=>JSON.parse(JSON.stringify(x));"
new_const="const KEY='rah-home-control-v03',FILTER_KEY='rah-home-control-filters-v01',BACKUP_SCHEMA='rah-home-control-config',BACKUP_VERSION=1,clone=x=>JSON.parse(JSON.stringify(x));"
assert old_const in html
html=html.replace(old_const,new_const)

old_valid="function validState(x){return x&&Array.isArray(x.rooms)&&Array.isArray(x.devices)&&Array.isArray(x.screens)&&Array.isArray(x.nodes)&&Array.isArray(x.tasks)}"
new_valid="""function validState(x){return x&&Array.isArray(x.rooms)&&Array.isArray(x.devices)&&Array.isArray(x.screens)&&Array.isArray(x.nodes)&&Array.isArray(x.tasks)}
function safeBackupText(v,max=180){return typeof v==='string'&&v.length>0&&v.length<=max&&!/[<>]/.test(v)}
function validBackupState(x){return validState(x)&&x.rooms.length<=100&&x.devices.length<=500&&x.screens.length<=200&&x.nodes.length<=200&&x.tasks.length<=500&&x.rooms.every(r=>r&&safeBackupText(r.id,100)&&safeBackupText(r.name)&&safeBackupText(r.icon,24)&&typeof r.active==='boolean')&&x.devices.every(d=>d&&safeBackupText(d.id,100)&&safeBackupText(d.name)&&safeBackupText(d.room)&&safeBackupText(d.type)&&safeBackupText(d.ip)&&safeBackupText(d.connection)&&safeBackupText(d.role)&&typeof d.online==='boolean')&&x.screens.every(s=>s&&safeBackupText(s.id,100)&&safeBackupText(s.name)&&safeBackupText(s.room)&&safeBackupText(s.mode)&&typeof s.active==='boolean')&&x.nodes.every(n=>n&&safeBackupText(n.id,100)&&safeBackupText(n.name)&&safeBackupText(n.role)&&safeBackupText(n.connection)&&typeof n.ready==='boolean')&&x.tasks.every(t=>t&&safeBackupText(t.name,240)&&safeBackupText(t.status,80))}
function validConfigBackup(x){return !!(x&&x.schema===BACKUP_SCHEMA&&x.version===BACKUP_VERSION&&x.product==='RAH Home Control'&&validBackupState(x.state))}"
assert old_valid in html
html=html.replace(old_valid,new_valid)

anchor="function renderFilters(){document.querySelectorAll('[data-status-filter]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.statusFilter===statusFilter)));document.querySelectorAll('[data-room-filter]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.roomFilter===roomFilter)))}"
backup_code="""function backupPayload(){return{schema:BACKUP_SCHEMA,version:BACKUP_VERSION,product:'RAH Home Control',exportedAt:new Date().toISOString(),state:clone(state)}}
function downloadConfigBackup(){hideError();hideActionNotice();const blob=new Blob([JSON.stringify(backupPayload(),null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=`RAH-Home-Control-Backup-${new Date().toISOString().slice(0,10)}.json`;document.body.appendChild(a);a.click();a.remove();URL.revokeObjectURL(url);showActionNotice('Home Control-backup er laget lokalt. Ingen data ble sendt over nettverket.')}
async function restoreConfigFile(file){hideError();hideActionNotice();if(!file)return;if(file.size>1000000)return showError('Backupfilen er for stor. Maksimal tillatt størrelse er 1 MB.');let payload;try{payload=JSON.parse(await file.text())}catch{return showError('Backupfilen kunne ikke leses som gyldig JSON.')}if(!validConfigBackup(payload))return showError('Backupfilen har feil format eller inneholder ugyldige Home Control-data.');const candidate=clone(payload.state),previousState=clone(state),previousEditingDeviceId=editingDeviceId;if(!window.confirm(`Gjenopprett Home Control-backup? Dette erstatter dagens lokale Home Control-konfigurasjon med ${candidate.rooms.length} rom, ${candidate.devices.length} enheter, ${candidate.screens.length} skjermer, ${candidate.nodes.length} noder og ${candidate.tasks.length} oppgaver.`)){showActionNotice('Gjenoppretting avbrutt. Ingen data ble endret.');return;}state=candidate;editingDeviceId=null;if(!save()){state=previousState;editingDeviceId=previousEditingDeviceId;showError('Gjenoppretting ble rullet tilbake fordi lokal lagring feilet. Den forrige konfigurasjonen er beholdt.');renderAll();return;}showActionNotice('Home Control-konfigurasjonen er gjenopprettet og lagret lokalt.');renderAll()}
"""+anchor
assert anchor in html
html=html.replace(anchor,backup_code)

old_end="resetData.onclick=()=>{if(!window.confirm('Gjenopprett standarddata? Registrerte Home Control-data og lagrede filtervalg nullstilles.'))return;state=clone(defaults);editingDeviceId=null;statusFilter='all';roomFilter='all';hideActionNotice();try{localStorage.removeItem(KEY);localStorage.removeItem(FILTER_KEY)}catch{}save();saveFilters();renderAll()};renderAll();"
new_end="resetData.onclick=()=>{if(!window.confirm('Gjenopprett standarddata? Registrerte Home Control-data og lagrede filtervalg nullstilles.'))return;state=clone(defaults);editingDeviceId=null;statusFilter='all';roomFilter='all';hideActionNotice();try{localStorage.removeItem(KEY);localStorage.removeItem(FILTER_KEY)}catch{}save();saveFilters();renderAll()};exportConfig.onclick=downloadConfigBackup;importConfig.onclick=()=>configFile.click();configFile.onchange=async()=>{const file=configFile.files&&configFile.files[0];await restoreConfigFile(file);configFile.value=''};renderAll();"
assert old_end in html
html=html.replace(old_end,new_end)
html_path.write_text(html,encoding='utf-8')

manifest_path=Path('RAH-HOME-CONTROL-VERSION.json')
m=json.loads(manifest_path.read_text(encoding='utf-8'))
assert m['version']=='1.13.0'
m['version']='1.14.0';m['stage']='stable-local-home-control';m['released_at']='2026-08-13';m['stable']=True
m['features'].update({
  'config_backup_export':True,
  'config_backup_restore':True,
  'config_backup_schema_version':1,
  'config_backup_state_only':True,
  'config_backup_filters_included':False,
  'config_backup_other_raven_data_included':False,
  'config_restore_validates_schema':True,
  'config_restore_requires_explicit_confirmation':True,
  'config_restore_storage_rollback':True,
  'config_restore_never_runs_automatically':True,
  'external_network_calls':False
})
m['next_milestone']='paused-stable-phase1'
m['release_gate']={
  'stage':'stable',
  'runtime':'browser-local',
  'backup_contract':'state-only-explicit-restore',
  'automatic_network_discovery':False,
  'automatic_task_execution':False,
  'development_paused':True,
  'change_policy':'bugfix-only-until-explicit-reopen'
}
manifest_path.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

Path('tests/rah-home-control.test.mjs').write_text(r'''import assert from 'node:assert/strict';import fs from 'node:fs';
const html=fs.readFileSync('RAH-HOME-CONTROL.html','utf8');const manifest=JSON.parse(fs.readFileSync('RAH-HOME-CONTROL-VERSION.json','utf8'));
assert.equal(manifest.product,'RAH Home Control');assert.equal(manifest.version,'1.14.0');assert.equal(manifest.local_only,true);assert.equal(manifest.features.device_mutations_transaction_safe,true);assert.equal(manifest.features.room_screen_node_mutations_transaction_safe,true);assert.equal(manifest.features.all_primary_local_status_mutations_transaction_safe,true);assert.equal(manifest.features.automatic_network_discovery,false);assert.equal(manifest.features.automatic_task_execution,false);assert.equal(manifest.features.external_network_calls,false);
assert.match(html,/stabil lokal kontroll v1\.14/);assert.match(html,/Romstatusen ble rullet tilbake/);assert.match(html,/Statusendringen ble rullet tilbake/);assert.match(html,/Skjermstatusen ble rullet tilbake/);assert.match(html,/Node-statusen ble rullet tilbake/);
assert.doesNotMatch(html,/fetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon/,'Home Control v1.14 must not add external network activity.');
const script=html.match(/<script>([\s\S]*?)<\/script>/)?.[1];assert.ok(script);new Function(script);
console.log('RAH Home Control v1.14: primary local controls remain transaction-safe and network-free.');
''',encoding='utf-8')

Path('tests/rah-home-control-backup.test.mjs').write_text(r'''import assert from 'node:assert/strict';import fs from 'node:fs';
const html=fs.readFileSync('RAH-HOME-CONTROL.html','utf8');const manifest=JSON.parse(fs.readFileSync('RAH-HOME-CONTROL-VERSION.json','utf8'));
assert.equal(manifest.version,'1.14.0');assert.equal(manifest.features.config_backup_export,true);assert.equal(manifest.features.config_backup_restore,true);assert.equal(manifest.features.config_backup_schema_version,1);assert.equal(manifest.features.config_backup_state_only,true);assert.equal(manifest.features.config_backup_filters_included,false);assert.equal(manifest.features.config_backup_other_raven_data_included,false);assert.equal(manifest.features.config_restore_validates_schema,true);assert.equal(manifest.features.config_restore_requires_explicit_confirmation,true);assert.equal(manifest.features.config_restore_storage_rollback,true);assert.equal(manifest.features.config_restore_never_runs_automatically,true);
assert.match(html,/id="exportConfig"/);assert.match(html,/id="importConfig"/);assert.match(html,/id="configFile" type="file" accept="application\/json,\.json" hidden/);assert.match(html,/BACKUP_SCHEMA='rah-home-control-config'/);assert.match(html,/BACKUP_VERSION=1/);assert.match(html,/function validConfigBackup\(x\)/);assert.match(html,/function downloadConfigBackup\(\)/);assert.match(html,/async function restoreConfigFile\(file\)/);
const payloadStart=html.indexOf('function backupPayload()'),downloadStart=html.indexOf('function downloadConfigBackup()',payloadStart);assert.ok(payloadStart>0&&downloadStart>payloadStart);const payload=html.slice(payloadStart,downloadStart);assert.match(payload,/state:clone\(state\)/);assert.doesNotMatch(payload,/FILTER_KEY|statusFilter|roomFilter|localStorage/,'Backup payload must be state-only and exclude view filters/storage internals.');
const restoreStart=html.indexOf('async function restoreConfigFile(file)'),filtersStart=html.indexOf('function renderFilters()',restoreStart);assert.ok(restoreStart>0&&filtersStart>restoreStart);const restore=html.slice(restoreStart,filtersStart);const validateAt=restore.indexOf('validConfigBackup(payload)'),confirmAt=restore.indexOf('window.confirm'),assignAt=restore.indexOf('state=candidate');assert.ok(validateAt>=0&&confirmAt>validateAt&&assignAt>confirmAt,'Restore must validate and confirm before state mutation.');assert.match(restore,/previousState=clone\(state\)/);assert.match(restore,/state=previousState/);assert.match(restore,/Gjenoppretting ble rullet tilbake/);assert.match(restore,/file\.size>1000000/);
assert.doesNotMatch(html,/fetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon/,'Backup/restore must remain local-only.');
console.log('RAH Home Control v1.14 backup: state-only export, validated explicit restore and rollback are present.');
''',encoding='utf-8')

Path('tests/rah-home-control-stable.test.mjs').write_text(r'''import assert from 'node:assert/strict';import fs from 'node:fs';
const m=JSON.parse(fs.readFileSync('RAH-HOME-CONTROL-VERSION.json','utf8'));
assert.equal(m.version,'1.14.0');assert.equal(m.stage,'stable-local-home-control');assert.equal(m.stable,true);assert.equal(m.next_milestone,'paused-stable-phase1');assert.equal(m.release_gate.stage,'stable');assert.equal(m.release_gate.runtime,'browser-local');assert.equal(m.release_gate.backup_contract,'state-only-explicit-restore');assert.equal(m.release_gate.automatic_network_discovery,false);assert.equal(m.release_gate.automatic_task_execution,false);assert.equal(m.release_gate.development_paused,true);assert.equal(m.release_gate.change_policy,'bugfix-only-until-explicit-reopen');
assert.equal(fs.existsSync('.github/scripts/build_home_control_v1_14.py'),false,'Temporary v1.14 builder script must not ship.');assert.equal(fs.existsSync('.github/workflows/build-home-control-v1.14.yml'),false,'Temporary v1.14 builder workflow must not ship.');
console.log('RAH Home Control v1.14 Stable Release Gate: temporary builders absent and phase 1 is paused stable.');
''',encoding='utf-8')
