from pathlib import Path

path = Path('vision-module.js')
text = path.read_text(encoding='utf-8')


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected exactly 1 match, found {count}')
    return source.replace(old, new, 1)

text = replace_once(
    text,
    '  const DEFAULT_ENDPOINT = "http://127.0.0.1:1234/v1";\n  const HISTORY_KEY = "rah-raven-vision-history-v1";',
    '  const DEFAULT_ENDPOINT = "http://127.0.0.1:1234/v1";\n  const LOOPBACK_HOSTS = new Set(["127.0.0.1", "localhost", "[::1]", "::1"]);\n  const HISTORY_KEY = "rah-raven-vision-history-v1";',
    'loopback host constant',
)

old_normalize = '''  function normalizeEndpoint(value) {
    let endpoint = String(value || "").trim().replace(/\\/+$/, "");
    if (!endpoint) endpoint = DEFAULT_ENDPOINT;
    if (!/\\/v1$/i.test(endpoint)) endpoint += "/v1";
    return endpoint;
  }
'''

new_normalize = '''  function normalizeEndpoint(value) {
    let raw = String(value || "").trim();
    if (!raw) raw = DEFAULT_ENDPOINT;

    let url;
    try {
      url = new URL(raw);
    } catch {
      notifyUser("Vision-endepunktet er ugyldig. Standard lokal loopback brukes.");
      return DEFAULT_ENDPOINT;
    }

    const protocol = url.protocol.toLowerCase();
    const hostname = url.hostname.toLowerCase();
    const path = url.pathname.replace(/\\/+$/, "");
    const unsafe =
      !["http:", "https:"].includes(protocol) ||
      !LOOPBACK_HOSTS.has(hostname) ||
      Boolean(url.username || url.password || url.search || url.hash) ||
      (path && path.toLowerCase() !== "/v1");

    if (unsafe) {
      notifyUser("Eksternt Vision-endepunkt ble blokkert. Kun lokal loopback (127.0.0.1, localhost eller ::1) er tillatt.");
      return DEFAULT_ENDPOINT;
    }

    url.pathname = "/v1";
    url.search = "";
    url.hash = "";
    return url.toString().replace(/\\/+$/, "");
  }
'''

text = replace_once(text, old_normalize, new_normalize, 'normalizeEndpoint')

# Fail closed if the old permissive normalizer survives anywhere.
if 'if (!/\\/v1$/i.test(endpoint)) endpoint += "/v1";' in text:
    raise SystemExit('legacy permissive endpoint normalizer still present')
if 'LOOPBACK_HOSTS' not in text or 'new URL(raw)' not in text:
    raise SystemExit('loopback boundary transform missing')

path.write_text(text, encoding='utf-8', newline='\n')
print('Legacy Vision loopback-boundary transform complete')
