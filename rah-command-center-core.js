(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.RAHCommandCenterCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const CC_VERSION = '0.3.0';
  const RAVEN_VERSION = '2.0.32';
  const BRIDGE_BASE = 'http://127.0.0.1:18765';

  const FALLBACK_STABLE_COMPONENTS = Object.freeze({
    raven_vision: '0.6',
    raven_council: '0.3',
    agent_runner: '0.3',
    memory_sync: '0.2',
    mission_control: '2.9',
    project_focus: '2.4',
    raven_core: '1.12',
    raven_now: '2.17',
    raven_studio: '2.8'
  });

  const COMPONENT_META = Object.freeze({
    raven_core: { label: 'Raven Core', entry: 'RAH-RAVEN-CORE-DEMO.html' },
    raven_now: { label: 'Raven Now', entry: 'RAH-RAVEN-NOW-V2.html' },
    raven_vision: { label: 'Raven Vision', entry: 'RAH-RAVEN-VISION-CORE.html' },
    raven_council: { label: 'Raven Council', entry: 'RAH-RAVEN-COUNCIL.html' },
    agent_runner: { label: 'Agent Runner', entry: 'RAH-RAVEN-AGENT-RUNNER.html' },
    memory_sync: { label: 'Memory Sync', entry: 'RAH-RAVEN-MEMORY-SYNC.html' },
    mission_control: { label: 'Mission Control', entry: 'RAH-RAVEN-MISSION-CONTROL.html' },
    project_focus: { label: 'Project Focus', entry: 'RAH-RAVEN-PROJECT.html' },
    raven_studio: { label: 'Raven Studio', entry: 'RAH-RAVEN-START.html' }
  });

  const EXTRA_COMPONENTS = Object.freeze([
    { id: 'mission_engine', label: 'Mission Engine', version: '1.6.0', entry: 'index.html', stable: true },
    { id: 'home_control', label: 'Home Control', version: '1.15.0', entry: 'RAH-HOME-CONTROL.html', stable: true },
    { id: 'ai_photos', label: 'AI Photos · Golden Gallery', version: '1.0.0', entry: 'RAH-AI-PHOTOS.html', stable: true },
    { id: 'system_health', label: 'System Health', version: '1.7', entry: 'RAH-RAVEN-NOW-V2.html', stable: true },
    { id: 'voice_control', label: 'Voice Control', version: '1.7', entry: 'RAH-RAVEN-NOW-V2.html', stable: true },
    { id: 'cloud_sync', label: 'Project Brain Cloud Sync', version: '1.1', entry: 'index.html', stable: true }
  ]);

  function isPlainObject(value) {
    return !!value && typeof value === 'object' && !Array.isArray(value);
  }

  function isSafeRelativeEntry(value) {
    if (typeof value !== 'string' || !value.trim()) return false;
    const v = value.trim();
    if (/^[a-z][a-z0-9+.-]*:/i.test(v)) return false;
    if (v.startsWith('//') || v.startsWith('\\\\')) return false;
    if (v.includes('..')) return false;
    return /^[A-Za-z0-9 _./-]+$/.test(v);
  }

  function normalizeStableComponents(manifest) {
    const candidate = manifest && manifest.release_gate && manifest.release_gate.stable_components;
    const source = isPlainObject(candidate) ? candidate : FALLBACK_STABLE_COMPONENTS;
    const result = {};
    for (const id of Object.keys(FALLBACK_STABLE_COMPONENTS)) {
      const version = source[id];
      result[id] = typeof version === 'string' && version.trim()
        ? version.trim()
        : FALLBACK_STABLE_COMPONENTS[id];
    }
    return result;
  }

  function buildCoreSnapshot(manifest, sourceName) {
    const stable = normalizeStableComponents(manifest);
    const version = manifest && typeof manifest.version === 'string' ? manifest.version : RAVEN_VERSION;
    const stage = manifest && manifest.release_gate && typeof manifest.release_gate.stage === 'string'
      ? manifest.release_gate.stage
      : 'temporary-stable';
    const components = Object.keys(FALLBACK_STABLE_COMPONENTS).map((id) => ({
      id,
      label: COMPONENT_META[id].label,
      version: stable[id],
      entry: COMPONENT_META[id].entry,
      stable: true
    }));
    return {
      commandCenterVersion: CC_VERSION,
      ravenVersion: version,
      stage,
      source: sourceName || (manifest ? 'manifest' : 'embedded-fallback'),
      stableCount: components.length,
      totalCount: components.length,
      components
    };
  }

  function isCanonicalBridgeUrl(value) {
    if (typeof value !== 'string') return false;
    try {
      const url = new URL(value);
      return url.protocol === 'http:' && url.hostname === '127.0.0.1' && url.port === '18765' && (url.pathname === '/' || url.pathname === '');
    } catch (_) {
      return false;
    }
  }

  function bridgeHealthUrl(base) {
    const safeBase = isCanonicalBridgeUrl(base) ? base.replace(/\/$/, '') : BRIDGE_BASE;
    return safeBase + '/health';
  }

  function summarizeBridgeHealth(payload) {
    if (!isPlainObject(payload)) return { ok: false, services: [], detail: 'Invalid health response' };
    const keys = ['case_center', 'chronicle', 'council_proxy', 'agent_runner'];
    const services = keys.map((key) => ({ id: key, ok: payload[key] === true }));
    return {
      ok: services.every((item) => item.ok),
      services,
      detail: services.every((item) => item.ok) ? 'Bridge core services ready' : 'One or more Bridge services are unavailable'
    };
  }

  return {
    CC_VERSION,
    RAVEN_VERSION,
    BRIDGE_BASE,
    FALLBACK_STABLE_COMPONENTS,
    COMPONENT_META,
    EXTRA_COMPONENTS,
    isSafeRelativeEntry,
    normalizeStableComponents,
    buildCoreSnapshot,
    isCanonicalBridgeUrl,
    bridgeHealthUrl,
    summarizeBridgeHealth
  };
});
