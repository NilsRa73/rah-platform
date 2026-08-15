(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.RAHCommandCenterCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const CC_VERSION = '0.5.0';
  const RAVEN_VERSION = '2.0.32';
  const BRIDGE_BASE = 'http://127.0.0.1:18765';
  const DEVICE_STORAGE_KEY = 'rah.cc.devices.v1';
  const NODE_AGENT_PORT = 18766;
  const NODE_AGENT_PROTOCOL = 'rah-node-health-v1';

  const FALLBACK_STABLE_COMPONENTS = Object.freeze({
    raven_vision: '0.6', raven_council: '0.3', agent_runner: '0.3', memory_sync: '0.2',
    mission_control: '2.9', project_focus: '2.4', raven_core: '1.12', raven_now: '2.17', raven_studio: '2.8'
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

  const PACKAGE_COMPONENTS = Object.freeze([
    { id: 'mission_engine', label: 'Mission Engine', entry: 'index.html' },
    { id: 'home_control', label: 'Home Control', entry: 'RAH-HOME-CONTROL.html' },
    { id: 'ai_photos', label: 'AI Photos · Golden Gallery', entry: 'RAH-AI-PHOTOS.html' },
    { id: 'system_health', label: 'System Health', entry: 'RAH-RAVEN-NOW-V2.html' },
    { id: 'voice_control', label: 'Voice Control', entry: 'RAH-RAVEN-NOW-V2.html' },
    { id: 'cloud_sync', label: 'Project Brain Cloud Sync', entry: 'index.html' }
  ]);

  const DEFAULT_DEVICES = Object.freeze([
    Object.freeze({ id: 'main-pc', label: 'Main PC', role: 'Command Center host', platform: 'Windows 11', kind: 'desktop', status: 'unverified', source: 'seed' }),
    Object.freeze({ id: 'hp-omen', label: 'HP Omen', role: 'Secondary compute', platform: 'Windows', kind: 'laptop', status: 'unverified', source: 'seed' }),
    Object.freeze({ id: 'lenovo-kali', label: 'Lenovo / Kali', role: 'Security lab node', platform: 'Kali Linux', kind: 'laptop', status: 'unverified', source: 'seed' }),
    Object.freeze({ id: 'mobile-display', label: 'Mobile / Display Node', role: 'Remote control / extended display', platform: 'Mobile', kind: 'mobile', status: 'unverified', source: 'seed' })
  ]);

  const DEVICE_KINDS = Object.freeze(['desktop', 'laptop', 'mobile', 'tv', 'projector', 'other']);
  const DEVICE_STATUSES = Object.freeze(['unverified', 'this-device']);

  function isPlainObject(value) { return !!value && typeof value === 'object' && !Array.isArray(value); }

  function cleanText(value, fallback, maxLength) {
    if (typeof value !== 'string') return fallback;
    const text = value.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim();
    return text ? text.slice(0, maxLength || 80) : fallback;
  }

  function cleanDeviceId(value, fallback) {
    const candidate = cleanText(value, '', 64).toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, '');
    return candidate || fallback;
  }

  function cloneDefaultDevices() { return DEFAULT_DEVICES.map((item) => ({ ...item })); }

  function isSafeRelativeEntry(value) {
    if (typeof value !== 'string' || !value.trim()) return false;
    const v = value.trim();
    if (/^[a-z][a-z0-9+.-]*:/i.test(v) || v.startsWith('//') || v.startsWith('\\\\') || v.includes('..')) return false;
    return /^[A-Za-z0-9 _./-]+$/.test(v);
  }

  function normalizeStableComponents(manifest) {
    const candidate = manifest && manifest.release_gate && manifest.release_gate.stable_components;
    const source = isPlainObject(candidate) ? candidate : FALLBACK_STABLE_COMPONENTS;
    const result = {};
    for (const id of Object.keys(FALLBACK_STABLE_COMPONENTS)) {
      const version = source[id];
      result[id] = typeof version === 'string' && version.trim() ? version.trim() : FALLBACK_STABLE_COMPONENTS[id];
    }
    return result;
  }

  function buildCoreSnapshot(manifest, sourceName) {
    const stable = normalizeStableComponents(manifest);
    const version = manifest && typeof manifest.version === 'string' ? manifest.version : RAVEN_VERSION;
    const stage = manifest && manifest.release_gate && typeof manifest.release_gate.stage === 'string' ? manifest.release_gate.stage : 'temporary-stable';
    const components = Object.keys(FALLBACK_STABLE_COMPONENTS).map((id) => ({ id, label: COMPONENT_META[id].label, version: stable[id], entry: COMPONENT_META[id].entry, stable: true }));
    return { commandCenterVersion: CC_VERSION, ravenVersion: version, stage, source: sourceName || (manifest ? 'manifest' : 'embedded-fallback'), stableCount: components.length, totalCount: components.length, components };
  }

  function parseIpv4(value) {
    if (typeof value !== 'string') return null;
    const text = value.trim();
    if (!/^\d{1,3}(?:\.\d{1,3}){3}$/.test(text)) return null;
    const parts = text.split('.').map(Number);
    if (parts.some((part) => !Number.isInteger(part) || part < 0 || part > 255)) return null;
    return parts;
  }

  function isAllowedNodeIpv4(value) {
    const p = parseIpv4(value);
    if (!p) return false;
    if (p[0] === 127) return true;
    if (p[0] === 10) return true;
    if (p[0] === 172 && p[1] >= 16 && p[1] <= 31) return true;
    if (p[0] === 192 && p[1] === 168) return true;
    return false;
  }

  function normalizeNodeIpv4(value) {
    const p = parseIpv4(value);
    return p && isAllowedNodeIpv4(value) ? p.join('.') : '';
  }

  function nodeHealthUrl(value) {
    const ip = normalizeNodeIpv4(value);
    return ip ? 'http://' + ip + ':' + NODE_AGENT_PORT + '/health' : '';
  }

  function sanitizeNodeHealth(payload) {
    if (!isPlainObject(payload) || payload.protocol !== NODE_AGENT_PROTOCOL || payload.status !== 'ready') return null;
    return {
      protocol: NODE_AGENT_PROTOCOL,
      agentVersion: cleanText(payload.agentVersion, 'unknown', 24),
      hostname: cleanText(payload.hostname, 'Unknown host', 80),
      platform: cleanText(payload.platform, 'Unknown platform', 80),
      platformRelease: cleanText(payload.platformRelease, '', 80),
      machine: cleanText(payload.machine, '', 40),
      nodeName: cleanText(payload.nodeName, '', 80),
      nodeRole: cleanText(payload.nodeRole, '', 100)
    };
  }

  function normalizeDeviceRecord(value, index) {
    if (!isPlainObject(value)) return null;
    const fallbackId = 'device-' + String((index || 0) + 1);
    const kind = DEVICE_KINDS.includes(value.kind) ? value.kind : 'other';
    const status = DEVICE_STATUSES.includes(value.status) ? value.status : 'unverified';
    const endpointIp = normalizeNodeIpv4(value.endpointIp || '');
    const enrolled = value.enrolled === true && !!endpointIp;
    return {
      id: cleanDeviceId(value.id, fallbackId),
      label: cleanText(value.label, 'Unnamed device', 80),
      role: cleanText(value.role, 'Unassigned role', 100),
      platform: cleanText(value.platform, 'Unknown platform', 80),
      kind, status, source: value.source === 'seed' ? 'seed' : 'local',
      enrolled,
      endpointIp: enrolled ? endpointIp : '',
      agentHostname: enrolled ? cleanText(value.agentHostname, '', 80) : '',
      agentVersion: enrolled ? cleanText(value.agentVersion, '', 24) : '',
      agentProtocol: enrolled ? NODE_AGENT_PROTOCOL : '',
      remoteControlEnabled: false,
      commandsEnabled: false
    };
  }

  function normalizeDeviceRegistry(value) {
    const source = Array.isArray(value) ? value : cloneDefaultDevices();
    const normalized = [], used = new Set();
    source.slice(0, 32).forEach((item, index) => {
      const record = normalizeDeviceRecord(item, index);
      if (!record) return;
      let id = record.id, suffix = 2;
      while (used.has(id)) id = record.id + '-' + suffix++;
      record.id = id; used.add(id); normalized.push(record);
    });
    return normalized;
  }

  function createDeviceRecord(input, existing) {
    const current = normalizeDeviceRegistry(Array.isArray(existing) ? existing : []);
    const base = normalizeDeviceRecord({ id: isPlainObject(input) ? input.id : '', label: isPlainObject(input) ? input.label : '', role: isPlainObject(input) ? input.role : '', platform: isPlainObject(input) ? input.platform : '', kind: isPlainObject(input) ? input.kind : 'other', status: 'unverified', source: 'local' }, current.length);
    const used = new Set(current.map((item) => item.id));
    let id = base.id, suffix = 2;
    while (used.has(id)) id = base.id + '-' + suffix++;
    base.id = id;
    return base;
  }

  function markThisDevice(records, id) {
    const normalized = normalizeDeviceRegistry(records), target = cleanDeviceId(id, '');
    return normalized.map((item) => ({ ...item, status: item.id === target ? 'this-device' : 'unverified', remoteControlEnabled: false, commandsEnabled: false }));
  }

  function enrollDevice(records, id, ip, healthPayload) {
    const normalized = normalizeDeviceRegistry(records);
    const target = cleanDeviceId(id, '');
    const endpointIp = normalizeNodeIpv4(ip);
    const health = sanitizeNodeHealth(healthPayload);
    if (!target || !endpointIp || !health) return normalized;
    return normalized.map((item) => item.id !== target ? item : ({
      ...item,
      enrolled: true,
      endpointIp,
      agentHostname: health.hostname,
      agentVersion: health.agentVersion,
      agentProtocol: NODE_AGENT_PROTOCOL,
      platform: health.platformRelease ? (health.platform + ' ' + health.platformRelease).slice(0, 80) : health.platform,
      remoteControlEnabled: false,
      commandsEnabled: false
    }));
  }

  function forgetEnrollment(records, id) {
    const normalized = normalizeDeviceRegistry(records), target = cleanDeviceId(id, '');
    return normalized.map((item) => item.id !== target ? item : ({ ...item, enrolled: false, endpointIp: '', agentHostname: '', agentVersion: '', agentProtocol: '', remoteControlEnabled: false, commandsEnabled: false }));
  }

  function buildDeviceSnapshot(records) {
    const devices = normalizeDeviceRegistry(records);
    return { devices, totalCount: devices.length, enrolledCount: devices.filter((item) => item.enrolled).length, thisDeviceCount: devices.filter((item) => item.status === 'this-device').length, remoteControlCount: 0, commandCount: 0 };
  }

  function isCanonicalBridgeUrl(value) {
    if (typeof value !== 'string') return false;
    try { const url = new URL(value); return url.protocol === 'http:' && url.hostname === '127.0.0.1' && url.port === '18765' && (url.pathname === '/' || url.pathname === ''); } catch (_) { return false; }
  }

  function bridgeHealthUrl(base) { const safeBase = isCanonicalBridgeUrl(base) ? base.replace(/\/$/, '') : BRIDGE_BASE; return safeBase + '/health'; }

  function summarizeBridgeHealth(payload) {
    if (!isPlainObject(payload)) return { ok: false, services: [], detail: 'Invalid health response' };
    const keys = ['case_center', 'chronicle', 'council_proxy', 'agent_runner'];
    const services = keys.map((key) => ({ id: key, ok: payload[key] === true }));
    return { ok: services.every((item) => item.ok), services, detail: services.every((item) => item.ok) ? 'Bridge core services ready' : 'One or more Bridge services are unavailable' };
  }

  return {
    CC_VERSION, RAVEN_VERSION, BRIDGE_BASE, DEVICE_STORAGE_KEY, NODE_AGENT_PORT, NODE_AGENT_PROTOCOL,
    FALLBACK_STABLE_COMPONENTS, COMPONENT_META, PACKAGE_COMPONENTS, DEFAULT_DEVICES, DEVICE_KINDS, DEVICE_STATUSES,
    isSafeRelativeEntry, normalizeStableComponents, buildCoreSnapshot, parseIpv4, isAllowedNodeIpv4, normalizeNodeIpv4, nodeHealthUrl,
    sanitizeNodeHealth, normalizeDeviceRecord, normalizeDeviceRegistry, createDeviceRecord, markThisDevice, enrollDevice, forgetEnrollment,
    buildDeviceSnapshot, isCanonicalBridgeUrl, bridgeHealthUrl, summarizeBridgeHealth
  };
});
