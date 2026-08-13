from pathlib import Path
import json

html_path=Path('RAH-RAVEN-COUNCIL.html')
core_path=Path('raven-council.js')
test_path=Path('tests/raven-council.test.mjs')
release_test_path=Path('tests/raven-release-gate.test.mjs')
manifest_path=Path('RAH-RAVEN-VERSION.json')

html=html_path.read_text(encoding='utf-8')
core=core_path.read_text(encoding='utf-8')
test=test_path.read_text(encoding='utf-8')
release_test=release_test_path.read_text(encoding='utf-8')
manifest=json.loads(manifest_path.read_text(encoding='utf-8'))

assert 'RAH Raven Council v0.2' in html
assert 'const VERSION = "0.1.0";' in core
assert 'raven-council.js?v=0.1' in html

core=core.replace('/* RAH Raven Council Core v0.1.0','/* RAH Raven Council Core v0.3.0',1)
core=core.replace('const VERSION = "0.1.0";','const VERSION = "0.3.0";\n  const DEFAULT_BRIDGE_BASE = "http://127.0.0.1:18765";',1)
marker='  const safeText = (value, max = 12000) => String(value ?? "").trim().slice(0, max);\n'
insert='''  function normalizeBridgeBase(value = DEFAULT_BRIDGE_BASE) {\n    let url;\n    try { url = new URL(String(value || DEFAULT_BRIDGE_BASE)); }\n    catch { throw new Error("Council Bridge må bruke en lokal loopback-adresse."); }\n    const host = String(url.hostname || "").toLowerCase();\n    if (!["127.0.0.1", "localhost", "::1"].includes(host)) throw new Error("Council Bridge må bruke en lokal loopback-adresse.");\n    if (!["http:", "https:"].includes(url.protocol)) throw new Error("Council Bridge må bruke HTTP på lokal loopback.");\n    if (url.username || url.password || url.search || url.hash || !["", "/"].includes(url.pathname)) throw new Error("Council Bridge-adressen kan ikke inneholde sti, innlogging, søk eller fragment.");\n    return `${url.protocol}//${url.host}`;\n  }\n\n  function endpoints(value = DEFAULT_BRIDGE_BASE) {\n    const root = normalizeBridgeBase(value);\n    return Object.freeze({ health: `${root}/health`, models: `${root}/lm/models`, chat: `${root}/lm/chat` });\n  }\n\n'''
assert marker in core
core=core.replace(marker,insert+marker,1)
core=core.replace('Raven Council v0.1 lager og overfører en kontrollert plan til Mission Control.','Raven Council v0.3 lager og overfører en kontrollert plan til Mission Control.',1)
core=core.replace('Council v0.1 gir strukturerte råd. Det utfører ingen skjulte PC-handlinger.','Council v0.3 gir strukturerte råd. Det utfører ingen skjulte PC-handlinger.',1)
core=core.replace('    VERSION,\n    ROLE_ORDER:', '    VERSION,\n    DEFAULT_BRIDGE_BASE,\n    normalizeBridgeBase,\n    endpoints,\n    ROLE_ORDER:',1)

html=html.replace('RAH Raven Council v0.2','RAH Raven Council v0.3')
html=html.replace('<span class="badge">v0.2</span>','<span class="badge">v0.3</span>',1)
html=html.replace('Raven Council v0.2 · Bridge 18765', 'Raven Council v0.3 · Bridge 18765',1)
html=html.replace('raven-council.js?v=0.1','raven-council.js?v=0.3',1)
old_field='<div class="field"><label>Bridge-adresse</label><input id="bridgeBase" value="http://127.0.0.1:18765"></div>'
new_field='<div class="field"><label>Bridge-adresse</label><input id="bridgeBase" value="http://127.0.0.1:18765"><small style="color:var(--muted)">Kun lokal loopback er tillatt: 127.0.0.1, localhost eller ::1. Eksterne adresser blokkeres før nettverkskall.</small></div>'
assert old_field in html
html=html.replace(old_field,new_field,1)
old_base='const base = () => String($("bridgeBase").value || "http://127.0.0.1:18765").replace(/\\/+$/, "");'
new_base='const base = () => CORE.normalizeBridgeBase($("bridgeBase").value || CORE.DEFAULT_BRIDGE_BASE);'
assert old_base in html
html=html.replace(old_base,new_base,1)

# Council component test: version sync + loopback boundary.
test=test.replace('const context = { console, structuredClone, Date, globalThis: {} };','const context = { console, structuredClone, Date, URL, globalThis: {} };',1)
test=test.replace("assert.equal(core.VERSION, '0.1.0');","assert.equal(core.VERSION, '0.3.0');",1)
test=test.replace("assert.match(html, /Raven Council v0\\.2/);","assert.match(html, /Raven Council v0\\.3/);",1)
test=test.replace("assert.match(html, /raven-council\\.js\\?v=0\\.1/);","assert.match(html, /raven-council\\.js\\?v=0\\.3/);",1)
boundary="""\nassert.equal(core.DEFAULT_BRIDGE_BASE, 'http://127.0.0.1:18765');\nfor (const url of ['http://127.0.0.1:18765','http://localhost:18765','http://[::1]:18765']) assert.doesNotThrow(() => core.normalizeBridgeBase(url));\nfor (const url of ['https://example.com','http://192.168.1.5:18765','file:///tmp/council','javascript:alert(1)']) assert.throws(() => core.normalizeBridgeBase(url), /lokal loopback|HTTP på lokal loopback/);\nconst endpoints=core.endpoints('http://127.0.0.1:18765/');\nassert.equal(endpoints.health,'http://127.0.0.1:18765/health');\nassert.equal(endpoints.models,'http://127.0.0.1:18765/lm/models');\nassert.equal(endpoints.chat,'http://127.0.0.1:18765/lm/chat');\nassert.match(html, /Kun lokal loopback er tillatt/);\nassert.match(html, /Eksterne adresser blokkeres før nettverkskall/);\nassert.match(html, /CORE\\.normalizeBridgeBase/);\n"""
needle="assert.deepEqual(Array.from(core.ROLE_ORDER), ['archivist', 'planner', 'builder', 'reviewer', 'safety']);\n"
assert needle in test
test=test.replace(needle,needle+boundary,1)
test=test.replace("console.log('Raven Council v0.2 Bridge validation passed.');","console.log('Raven Council v0.3 local Bridge boundary and version-sync validation passed.');",1)

# Raven package identity remains 2.0.32; Council is a bugfix-only component update.
manifest['summary']='RAH Raven 2.0.32 remains the temporary stable freeze. Vision Core v0.6 is stable, and Council v0.3 is a bugfix-only safety patch that synchronizes its helper version and restricts Bridge endpoints to local loopback addresses. No new Raven product features are added.'
manifest['privacy']['council_local_bridge_only']=True
manifest['privacy']['council_external_bridge_addresses_allowed']=False
manifest['privacy']['council_helper_version_synced']=True
manifest['release_gate']['component_versions']['raven_council']='0.3'
updates=manifest['release_gate'].setdefault('bugfix_component_updates',{})
updates['raven_vision']='0.6'
updates['raven_council']='0.3'

release_test=release_test.replace('assert.equal(manifest.release_gate?.bugfix_component_updates?.raven_vision,"0.6");','assert.equal(manifest.release_gate?.bugfix_component_updates?.raven_vision,"0.6");\nassert.equal(manifest.release_gate?.bugfix_component_updates?.raven_council,"0.3");',1)
release_test=release_test.replace('raven_council:["RAH-RAVEN-COUNCIL.html","RAH Raven Council v0.2","0.2"]','raven_council:["RAH-RAVEN-COUNCIL.html","RAH Raven Council v0.3","0.3"]',1)
privacy_needle='  "vision_helper_version_synced",\n'
assert privacy_needle in release_test
release_test=release_test.replace(privacy_needle,privacy_needle+'  "council_local_bridge_only",\n  "council_helper_version_synced",\n',1)
release_test=release_test.replace('assert.equal(privacy.vision_external_bridge_addresses_allowed,false,"Vision external Bridge addresses must stay blocked");','assert.equal(privacy.vision_external_bridge_addresses_allowed,false,"Vision external Bridge addresses must stay blocked");\nassert.equal(privacy.council_external_bridge_addresses_allowed,false,"Council external Bridge addresses must stay blocked");',1)

core_path.write_text(core,encoding='utf-8')
html_path.write_text(html,encoding='utf-8')
test_path.write_text(test,encoding='utf-8')
release_test_path.write_text(release_test,encoding='utf-8')
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
