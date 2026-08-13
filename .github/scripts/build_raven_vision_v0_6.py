from pathlib import Path
import json

html_path=Path('RAH-RAVEN-VISION-CORE.html')
html=html_path.read_text(encoding='utf-8')
assert 'RAH Raven Vision Core v0.5' in html
assert '<span class="badge">v0.5</span>' in html
assert 'raven-vision-core.js?v=0.5' in html
html=html.replace('RAH Raven Vision Core v0.5','RAH Raven Vision Core v0.6')
html=html.replace('<span class="badge">v0.5</span>','<span class="badge">v0.6</span>')
html=html.replace('RAH Raven Vision Core v0.5 · Bridge-proxy reduserer CORS-problemer · Bilde lagres ikke i historikk eller Project Brain.','RAH Raven Vision Core v0.6 · Kun lokal loopback-Bridge · Bilde lagres ikke i historikk eller Project Brain.')
html=html.replace('raven-vision-core.js?v=0.5','raven-vision-core.js?v=0.6')
old_field='<div class="field"><label>Bridge-adresse</label><input id="bridgeBase" value="http://127.0.0.1:18765"></div>'
new_field='<div class="field"><label>Bridge-adresse</label><input id="bridgeBase" value="http://127.0.0.1:18765" aria-describedby="bridgePolicy"><small id="bridgePolicy" class="sub">Kun lokal loopback er tillatt: 127.0.0.1, localhost eller ::1. Eksterne adresser blokkeres før nettverkskall.</small></div>'
assert old_field in html
html=html.replace(old_field,new_field)
html_path.write_text(html,encoding='utf-8')

core_path=Path('raven-vision-core.js')
core=core_path.read_text(encoding='utf-8')
assert 'RAH Raven Vision Core v0.1.0' in core
assert 'const VERSION = "0.1.0";' in core
old_norm='''  function normalizeBase(value, fallback = DEFAULT_BRIDGE_BASE) {
    const candidate = safeText(value, 500) || fallback;
    return candidate.replace(/\\/+$/, "");
  }
'''
new_norm='''  function isLoopbackBase(value) {
    const candidate = safeText(value, 500);
    if (!candidate) return false;
    try {
      const parsed = new URL(candidate);
      const host = parsed.hostname.toLowerCase();
      return (parsed.protocol === "http:" || parsed.protocol === "https:") &&
        !parsed.username && !parsed.password &&
        (host === "127.0.0.1" || host === "localhost" || host === "[::1]" || host === "::1");
    } catch {
      return false;
    }
  }

  function normalizeBase(value, fallback = DEFAULT_BRIDGE_BASE) {
    const candidate = safeText(value, 500) || fallback;
    if (!isLoopbackBase(candidate)) throw new Error("Vision Bridge må bruke lokal loopback-adresse.");
    return candidate.replace(/\\/+$/, "");
  }
'''
assert old_norm in core
core=core.replace('RAH Raven Vision Core v0.1.0','RAH Raven Vision Core v0.6.0')
core=core.replace('const VERSION = "0.1.0";','const VERSION = "0.6.0";')
core=core.replace(old_norm,new_norm)
old_export='''    STATE_KEY,
    normalizeBase,
    endpoints,
'''
new_export='''    STATE_KEY,
    isLoopbackBase,
    normalizeBase,
    endpoints,
'''
assert old_export in core
core=core.replace(old_export,new_export)
core_path.write_text(core,encoding='utf-8')

test_path=Path('tests/raven-vision-core.test.mjs')
test=test_path.read_text(encoding='utf-8')
test=test.replace('const context = { console, structuredClone, Date, globalThis: {} };','const context = { console, structuredClone, Date, URL, globalThis: {} };')
test=test.replace("assert.equal(core.VERSION, '0.1.0');","assert.equal(core.VERSION, '0.6.0');")
test=test.replace("assert.match(html, /RAH Raven Vision Core v0\\.5/);","assert.match(html, /RAH Raven Vision Core v0\\.6/);")
test=test.replace("assert.match(html, /<span class=\"badge\">v0\\.5<\\/span>/);","assert.match(html, /<span class=\"badge\">v0\\.6<\\/span>/);")
test=test.replace("console.log('Raven Vision Core v0.5 source-preserving URL-only return handoff validation passed.');","console.log('Raven Vision Core v0.6 local-boundary and source-preserving handoff validation passed.');")
insert="""
assert.equal(core.isLoopbackBase('http://127.0.0.1:18765'), true);
assert.equal(core.isLoopbackBase('http://localhost:18765'), true);
assert.equal(core.isLoopbackBase('http://[::1]:18765'), true);
assert.equal(core.isLoopbackBase('https://example.com'), false);
assert.equal(core.isLoopbackBase('http://192.168.1.10:18765'), false);
assert.throws(() => core.endpoints('https://example.com'), /lokal loopback-adresse/);
assert.throws(() => core.endpoints('http://192.168.1.10:18765'), /lokal loopback-adresse/);
"""
anchor="assert.equal(core.DEFAULT_BRIDGE_BASE, 'http://127.0.0.1:18765');\n"
assert anchor in test
test=test.replace(anchor,anchor+insert)
assert 'Kun lokal loopback er tillatt' not in test
test=test.replace("assert.match(html, /http:\\/\\/127\\.0\\.0\\.1:18765/);","assert.match(html, /http:\\/\\/127\\.0\\.0\\.1:18765/);\nassert.match(html, /Kun lokal loopback er tillatt/);\nassert.match(html, /Eksterne adresser blokkeres før nettverkskall/);")
test_path.write_text(test,encoding='utf-8')

manifest={
  'product':'RAH Raven Vision Core',
  'version':'0.6.0',
  'stage':'local-boundary-hardening',
  'released_at':'2026-08-13',
  'entry':'RAH-RAVEN-VISION-CORE.html',
  'helper':'raven-vision-core.js',
  'helper_version':'0.6.0',
  'local_only':True,
  'features':{
    'explicit_capture_only':True,
    'hidden_capture':False,
    'local_bridge_only':True,
    'loopback_hosts':['127.0.0.1','localhost','::1'],
    'external_bridge_addresses_allowed':False,
    'external_ai_endpoints':False,
    'image_stored_in_history':False,
    'image_stored_in_project_brain':False,
    'chatgpt_handoff_manual_only':True,
    'clipboard_or_png_share_explicit_only':True
  },
  'next_milestone':'vision-stable-release-gate'
}
Path('RAH-RAVEN-VISION-VERSION.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

Path('tests/raven-vision-local-boundary.test.mjs').write_text(r'''import assert from 'node:assert/strict';import fs from 'node:fs';import vm from 'node:vm';
const source=fs.readFileSync('raven-vision-core.js','utf8');const html=fs.readFileSync('RAH-RAVEN-VISION-CORE.html','utf8');const manifest=JSON.parse(fs.readFileSync('RAH-RAVEN-VISION-VERSION.json','utf8'));
const context={console,structuredClone,Date,URL,globalThis:{}};context.globalThis=context;vm.runInNewContext(source,context);const core=context.RavenVisionCore;
assert.equal(core.VERSION,'0.6.0');assert.equal(manifest.version,'0.6.0');assert.equal(manifest.helper_version,'0.6.0');assert.equal(manifest.local_only,true);assert.equal(manifest.features.explicit_capture_only,true);assert.equal(manifest.features.hidden_capture,false);assert.equal(manifest.features.local_bridge_only,true);assert.equal(manifest.features.external_bridge_addresses_allowed,false);assert.equal(manifest.features.external_ai_endpoints,false);assert.equal(manifest.features.chatgpt_handoff_manual_only,true);
for(const url of ['http://127.0.0.1:18765','http://localhost:18765','http://[::1]:18765']) assert.equal(core.isLoopbackBase(url),true,url);
for(const url of ['https://example.com','http://192.168.1.5:18765','file:///tmp/bridge','javascript:alert(1)']){assert.equal(core.isLoopbackBase(url),false,url);assert.throws(()=>core.endpoints(url),/lokal loopback-adresse/);}
assert.match(html,/Kun lokal loopback er tillatt/);assert.match(html,/Eksterne adresser blokkeres før nettverkskall/);assert.match(html,/Raven tar aldri skjermbilder skjult/);assert.match(html,/Ingenting sendes automatisk/);assert.doesNotMatch(html,/api\.openai\.com|openai\.com\/v1|chatgpt\.com\/backend/i);
console.log('Raven Vision v0.6 Local Bridge Boundary: loopback-only endpoint policy verified.');
''',encoding='utf-8')
