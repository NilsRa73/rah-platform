from pathlib import Path

path = Path('vision.html')
text = path.read_text(encoding='utf-8')


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 baseline match, got {count}')
    text = text.replace(old, new, 1)


replace_once(
    '<input id="bridgeUrl" value="http://127.0.0.1:8765">',
    '<input id="bridgeUrl" value="http://127.0.0.1:18765">',
    'Bridge input default',
)

replace_once(
    "  const STORAGE_KEY = 'rah-raven-vision-v1.3';\n"
    "  const state = Object.assign({lmUrl:'http://127.0.0.1:1234',bridgeUrl:'http://127.0.0.1:8765',model:'',history:[]}, load());",
    "  const STORAGE_KEY = 'rah-raven-vision-v1.3';\n"
    "  const DEFAULT_LM_URL = 'http://127.0.0.1:1234';\n"
    "  const DEFAULT_BRIDGE_URL = 'http://127.0.0.1:18765';\n"
    "  const LOOPBACK_HOSTS = new Set(['127.0.0.1','localhost','[::1]','::1']);\n"
    "  const state = Object.assign({lmUrl:DEFAULT_LM_URL,bridgeUrl:DEFAULT_BRIDGE_URL,model:'',history:[]}, load());",
    'Vision state defaults',
)

replace_once(
    "  function normalizeUrl(value){return value.trim().replace(/\\/+$/,'')}",
    """  function normalizeLocalBase(value,fallback){
    const raw=String(value||'').trim();
    try{
      const url=new URL(raw||fallback);
      if(!['http:','https:'].includes(url.protocol))throw new Error('protocol');
      if(!LOOPBACK_HOSTS.has(url.hostname))throw new Error('host');
      if(url.username||url.password||url.search||url.hash)throw new Error('credentials-query-hash');
      if(url.pathname!==''&&url.pathname!=='/')throw new Error('path');
      return {value:url.origin,blocked:false};
    }catch{
      return {value:fallback,blocked:true};
    }
  }""",
    'Legacy free-form URL normalizer',
)

replace_once(
    "  function persistSettings(){state.lmUrl=normalizeUrl($('lmUrl').value);state.bridgeUrl=normalizeUrl($('bridgeUrl').value);state.model=$('model').value;state.instruction=$('instruction').value;save()}",
    """  function persistSettings(){
    const lm=normalizeLocalBase($('lmUrl').value,DEFAULT_LM_URL);
    const bridge=normalizeLocalBase($('bridgeUrl').value,DEFAULT_BRIDGE_URL);
    state.lmUrl=lm.value;state.bridgeUrl=bridge.value;
    $('lmUrl').value=state.lmUrl;$('bridgeUrl').value=state.bridgeUrl;
    state.model=$('model').value;state.instruction=$('instruction').value;
    if(lm.blocked||bridge.blocked)setStatus('connectionStatus','Ekstern eller ugyldig adresse blokkert. Bare lokal loopback er tillatt.','bad');
    save();
    return {lmBlocked:lm.blocked,bridgeBlocked:bridge.blocked};
  }""",
    'Persisted endpoint normalization',
)

if ':8765' in text:
    raise SystemExit('vision.html still contains retired :8765 endpoint')
if 'normalizeUrl(' in text:
    raise SystemExit('vision.html still contains free-form normalizeUrl()')
for required in (
    "const DEFAULT_LM_URL = 'http://127.0.0.1:1234';",
    "const DEFAULT_BRIDGE_URL = 'http://127.0.0.1:18765';",
    "const LOOPBACK_HOSTS = new Set(['127.0.0.1','localhost','[::1]','::1']);",
    "normalizeLocalBase($('lmUrl').value,DEFAULT_LM_URL)",
    "normalizeLocalBase($('bridgeUrl').value,DEFAULT_BRIDGE_URL)",
    "Ekstern eller ugyldig adresse blokkert. Bare lokal loopback er tillatt.",
):
    if required not in text:
        raise SystemExit(f'missing required postcondition: {required}')

path.write_text(text, encoding='utf-8')
print('vision.html local-only compatibility transform: PASS')
