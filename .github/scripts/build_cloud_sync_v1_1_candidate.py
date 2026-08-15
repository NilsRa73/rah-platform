from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path('.')
BASE_SHA = '6781f4350713b2a62b5fe7752156476568d32cbf'

FROZEN = [
    'index.html',
    'RAH-RAVEN-START.html',
    'RAH-RAVEN-CORE-DEMO.html',
    'RAH-RAVEN-VISION-CORE.html',
    'RAH-RAVEN-COUNCIL.html',
    'RAH-RAVEN-AGENT-RUNNER.html',
    'RAH-RAVEN-MEMORY-SYNC.html',
    'RAH-RAVEN-MISSION-CONTROL.html',
    'RAH-RAVEN-NOW.html',
    'RAH-RAVEN-NOW-V2.html',
    'RAH-RAVEN-PROJECT.html',
    'raven-vision-core.js',
    'raven-council.js',
    'raven-checkpoint-policy.js',
    'RAH-RAVEN-CHRONICLE.html',
    'RAH-RAVEN-CHRONICLE-LIVE.html',
    'RAH-RAVEN-CHRONICLE-VERSION.json',
    'desktop-bridge/server_v17.py',
    'system-health-v1.7.js',
    'SYSTEM_HEALTH_V1_7.md',
    'RAH-RAVEN-SYSTEM-HEALTH-VERSION.json',
    'RAH-RAVEN-CASE-CENTER.html',
    'RAH-RAVEN-CASE-CENTER-VERSION.json',
    'desktop-bridge/server_v16.py',
    'RAH-HOME-CONTROL.html',
    'RAH-HOME-CONTROL-VERSION.json',
]


def digest(path: str) -> str:
    return hashlib.sha256((ROOT / path).read_bytes()).hexdigest()

before = {p: digest(p) for p in FROZEN if (ROOT / p).exists()}

cloud_js = r'''/* RAH Raven Project Brain Cloud Sync v1.1
 * Explicit-only Supabase synchronization for Command Center state.
 * No interval, debounce, login-triggered sync, click/change watcher, or automatic state sending.
 */
(() => {
  "use strict";

  const VERSION = "1.1.0";
  const SUPABASE_URL = "https://zespiaujgkyclsfhayji.supabase.co";
  const SUPABASE_KEY = "sb_publishable_NkxP_f5GMH9hCqZvW94YOw_8g_VXe42";
  const META_KEY = "rah-cloud-sync-meta-v1";

  let client = null;
  let session = null;
  let syncing = false;
  let schemaReady = true;

  const meta = loadMeta();

  function loadMeta() {
    try {
      const saved = JSON.parse(localStorage.getItem(META_KEY) || "{}");
      return {
        lastCloudSync: saved.lastCloudSync || null,
        lastCloudUpdatedAt: saved.lastCloudUpdatedAt || null,
        lastError: saved.lastError || null
      };
    } catch {
      return { lastCloudSync: null, lastCloudUpdatedAt: null, lastError: null };
    }
  }

  function saveMeta() {
    localStorage.setItem(META_KEY, JSON.stringify(meta));
  }

  function getState() {
    try {
      return typeof state === "object" && state ? structuredClone(state) : null;
    } catch {
      try { return JSON.parse(JSON.stringify(state)); } catch { return null; }
    }
  }

  function applyState(nextState) {
    if (!nextState || typeof nextState !== "object") return false;
    try {
      state = Object.assign(structuredClone(defaults), nextState);
      saveState();
      render();
      document.dispatchEvent(new CustomEvent("rah:cloud-sync-applied", {
        detail: { explicit: true, version: VERSION, time: new Date().toISOString() }
      }));
      return true;
    } catch (error) {
      console.error("RAH Cloud Sync could not apply cloud state", error);
      return false;
    }
  }

  function setStatus(text, kind = "muted") {
    const el = document.getElementById("rahCloudSyncStatus");
    if (!el) return;
    el.textContent = text;
    el.className = kind;
  }

  function renderStatus() {
    const pill = document.getElementById("rahCloudSyncPill");
    const user = document.getElementById("rahCloudUser");
    const last = document.getElementById("rahCloudLastSync");
    if (pill) pill.textContent = session ? (schemaReady ? "MANUELL" : "SETUP") : "LOKAL";
    if (user) user.textContent = session?.user?.email || "Ikke innlogget";
    if (last) last.textContent = meta.lastCloudSync
      ? new Date(meta.lastCloudSync).toLocaleString("no-NO")
      : "Aldri";

    if (!session) setStatus("Logg inn som RAH-medlem. Ingen synk skjer automatisk.");
    else if (!schemaReady) setStatus("Supabase-tabellen mangler. Kjør supabase/001_project_brain_sync.sql.", "sync-warn");
    else if (meta.lastError) setStatus(meta.lastError, "sync-warn");
    else if (syncing) setStatus("Utfører eksplisitt skyhandling…", "sync-good");
    else setStatus("Manuell synk er klar. Raven sender ingenting i bakgrunnen.");
  }

  function injectUi() {
    if (document.getElementById("rahCloudSyncPanel")) return;
    const target = document.querySelector("#settings .grid") || document.querySelector("#settings");
    if (!target) return;

    const panel = document.createElement("section");
    panel.id = "rahCloudSyncPanel";
    panel.className = "panel full";
    panel.innerHTML = `
      <div class="row between">
        <div>
          <h2>☁️ Project Brain Cloud Sync v1.1</h2>
          <div class="meta">Eksplisitt synk mellom enhetene dine. Ingen timer, klikk-overvåking eller bakgrunnssending.</div>
        </div>
        <span class="pill" id="rahCloudSyncPill">LOKAL</span>
      </div>
      <div class="list-item"><span>Innlogging</span><span id="rahCloudUser" class="meta">Ikke innlogget</span></div>
      <div class="list-item"><span>Siste eksplisitte skyhandling</span><span id="rahCloudLastSync" class="meta">Aldri</span></div>
      <div class="list-item"><span>Bakgrunnssynk</span><span class="meta">AV · låst</span></div>
      <div id="rahCloudSyncStatus" class="muted" style="margin:10px 0">Venter på innlogging.</div>
      <div class="row">
        <button class="btn" id="rahCloudInspect">↕ Sjekk sky-status</button>
        <button class="btn primary" id="rahCloudUpload">⬆ Last opp denne enheten</button>
        <button class="btn" id="rahCloudDownload">⬇ Hent fra skyen</button>
      </div>`;
    target.appendChild(panel);

    document.getElementById("rahCloudInspect").onclick = inspectCloudExplicit;
    document.getElementById("rahCloudUpload").onclick = uploadExplicit;
    document.getElementById("rahCloudDownload").onclick = downloadExplicit;
    renderStatus();
  }

  function requireSession() {
    if (session && client) return true;
    setStatus("Logg inn før du bruker Cloud Sync.", "sync-warn");
    return false;
  }

  function confirmAction(message) {
    return typeof window.confirm === "function" && window.confirm(message);
  }

  async function fetchCloud() {
    const { data, error } = await client
      .from("rah_user_state")
      .select("state,client_updated_at,updated_at")
      .eq("user_id", session.user.id)
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async function uploadLocal() {
    const current = getState();
    if (!current) throw new Error("Kunne ikke lese lokal Project Brain-tilstand.");
    const now = new Date().toISOString();
    const { data, error } = await client
      .from("rah_user_state")
      .upsert({ user_id: session.user.id, state: current, client_updated_at: now }, { onConflict: "user_id" })
      .select("updated_at")
      .single();
    if (error) throw error;
    meta.lastCloudUpdatedAt = data.updated_at;
    meta.lastCloudSync = now;
    meta.lastError = null;
    saveMeta();
  }

  async function runExplicit(label, action) {
    if (syncing || !requireSession()) return false;
    syncing = true;
    meta.lastError = null;
    renderStatus();
    try {
      await action();
      schemaReady = true;
      setStatus(label, "sync-good");
      return true;
    } catch (error) {
      const message = error?.message || String(error);
      schemaReady = !/rah_user_state|relation .* does not exist|schema cache/i.test(message);
      meta.lastError = schemaReady
        ? `Cloud Sync: ${message}`
        : "Cloud Sync må aktiveres i Supabase SQL Editor.";
      saveMeta();
      setStatus(meta.lastError, "sync-warn");
      console.error("RAH Cloud Sync", error);
      return false;
    } finally {
      syncing = false;
      renderStatus();
    }
  }

  async function inspectCloudExplicit() {
    if (!confirmAction("Sjekke Cloud Sync-status i Supabase nå? Ingen lokal Raven-state blir sendt eller erstattet.")) {
      setStatus("Sky-status ble ikke sjekket.");
      return false;
    }
    return runExplicit("Sky-status kontrollert. Ingen lokal state ble sendt eller erstattet.", async () => {
      const cloud = await fetchCloud();
      meta.lastCloudSync = new Date().toISOString();
      meta.lastCloudUpdatedAt = cloud?.updated_at || null;
      saveMeta();
      if (!cloud) setStatus("Ingen Project Brain-state finnes i skyen ennå.");
      else setStatus(`Sky-state finnes. Sist oppdatert ${new Date(cloud.updated_at).toLocaleString("no-NO")}.`, "sync-good");
    });
  }

  async function uploadExplicit() {
    if (!confirmAction("Laste opp hele den lokale Command Center-staten til din private Supabase-rad nå?")) {
      setStatus("Opplasting avbrutt.");
      return false;
    }
    return runExplicit("Lokal state ble lastet opp etter eksplisitt bekreftelse.", uploadLocal);
  }

  async function downloadExplicit() {
    if (!confirmAction("Hente sky-state og erstatte lokal Command Center-state nå? Dette kan overskrive lokale endringer.")) {
      setStatus("Nedlasting avbrutt.");
      return false;
    }
    return runExplicit("Sky-state ble hentet og brukt etter eksplisitt bekreftelse.", async () => {
      const cloud = await fetchCloud();
      if (!cloud?.state) throw new Error("Ingen Project Brain-data finnes i skyen ennå.");
      if (!applyState(cloud.state)) throw new Error("Kunne ikke gjenopprette Project Brain fra skyen.");
      meta.lastCloudUpdatedAt = cloud.updated_at;
      meta.lastCloudSync = new Date().toISOString();
      meta.lastError = null;
      saveMeta();
    });
  }

  async function waitForSupabase() {
    for (let i = 0; i < 80; i += 1) {
      if (window.supabase?.createClient) return true;
      await new Promise(resolve => setTimeout(resolve, 250));
    }
    return false;
  }

  async function start() {
    injectUi();
    const available = await waitForSupabase();
    if (!available) {
      setStatus("Supabase-biblioteket kunne ikke lastes.", "sync-warn");
      return;
    }

    client = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
      auth: { persistSession: true, autoRefreshToken: false, detectSessionInUrl: true }
    });
    const { data } = await client.auth.getSession();
    session = data.session;
    renderStatus();

    client.auth.onAuthStateChange((_event, nextSession) => {
      session = nextSession;
      renderStatus();
    });

    window.RAHCloudSync = Object.freeze({
      version: VERSION,
      automaticSync: false,
      inspect: inspectCloudExplicit,
      upload: uploadExplicit,
      download: downloadExplicit
    });
    console.info(`RAH Project Brain Cloud Sync v${VERSION} ready — explicit actions only`);
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
'''
(ROOT / 'cloud-sync.js').write_text(cloud_js, encoding='utf-8')

component = {
    'product': 'RAH Project Brain Cloud Sync',
    'version': '1.1.0',
    'stage': 'candidate',
    'released_at': '2026-08-15',
    'entry': 'index.html',
    'module': 'cloud-sync.js',
    'external_service': 'Supabase',
    'runtime_feature_change': False,
    'features': {
        'explicit_sync_only': True,
        'automatic_sync': False,
        'background_timer': False,
        'debounced_auto_upload': False,
        'click_change_watch': False,
        'login_triggered_sync': False,
        'auth_change_triggered_sync': False,
        'manual_cloud_inspect': True,
        'manual_upload': True,
        'manual_download': True,
        'upload_requires_confirmation': True,
        'download_requires_confirmation': True,
        'inspect_sends_local_state': False,
        'full_command_center_state_upload_disclosed': True,
        'rls_user_scoped': True,
        'anonymous_table_access_revoked': True,
        'legacy_index_mutator_retired': True,
        'automatic_sending': False,
        'capability_set_changed': False,
    },
    'next_milestone': 'stable-gate',
}
(ROOT / 'RAH-RAVEN-CLOUD-SYNC-VERSION.json').write_text(json.dumps(component, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

master_path = ROOT / 'RAH-RAVEN-VERSION.json'
master = json.loads(master_path.read_text(encoding='utf-8'))
for path in ['cloud-sync.js', 'RAH-RAVEN-CLOUD-SYNC-VERSION.json']:
    if path not in master['files']:
        master['files'].append(path)
privacy = master.setdefault('privacy', {})
privacy.update({
    'project_brain_cloud_sync_explicit_only': True,
    'project_brain_cloud_sync_automatic_sync': False,
    'project_brain_cloud_sync_background_timer': False,
    'project_brain_cloud_sync_click_change_watch': False,
    'project_brain_cloud_sync_login_triggered_sync': False,
    'project_brain_cloud_sync_upload_requires_confirmation': True,
    'project_brain_cloud_sync_download_requires_confirmation': True,
    'project_brain_cloud_sync_legacy_index_mutator_retired': True,
    'project_brain_cloud_sync_stable': False,
})
expected_core = {
    'raven_vision': '0.6', 'raven_council': '0.3', 'agent_runner': '0.3',
    'memory_sync': '0.2', 'mission_control': '2.9', 'project_focus': '2.4',
    'raven_core': '1.12', 'raven_now': '2.17', 'raven_studio': '2.8'
}
assert master['release_gate']['stable_components'] == expected_core
assert privacy.get('raven_chronicle_stable') is True
assert privacy.get('system_health_stable') is True
assert privacy.get('case_center_stable') is True
master_path.write_text(json.dumps(master, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')

test = r'''import assert from "node:assert/strict";
import fs from "node:fs";

const index = fs.readFileSync("index.html", "utf8");
const sync = fs.readFileSync("cloud-sync.js", "utf8");
const sql = fs.readFileSync("supabase/001_project_brain_sync.sql", "utf8");
const component = JSON.parse(fs.readFileSync("RAH-RAVEN-CLOUD-SYNC-VERSION.json", "utf8"));
const master = JSON.parse(fs.readFileSync("RAH-RAVEN-VERSION.json", "utf8"));

assert.match(index, /cloud-sync\.js\?v=1\.0/, "Frozen Command Center hook must remain present");
assert.match(sync, /VERSION = "1\.1\.0"/);
assert.match(sync, /rah_user_state/);
assert.match(sync, /Sjekk sky-status/);
assert.match(sync, /Last opp denne enheten/);
assert.match(sync, /Hent fra skyen/);
assert.match(sync, /window\.confirm/);
assert.match(sync, /automaticSync: false/);
assert.match(sync, /autoRefreshToken: false/);
assert.doesNotMatch(sync, /setInterval\s*\(/, "Cloud Sync must not run a background interval");
assert.doesNotMatch(sync, /markLocalChanged/, "Cloud Sync must not watch local changes for upload");
assert.doesNotMatch(sync, /DEBOUNCE_MS|SYNC_INTERVAL_MS/);
assert.doesNotMatch(sync, /window\.saveState\s*=/, "Cloud Sync must not wrap saveState");
assert.doesNotMatch(sync, /addEventListener\(["'](?:click|change)["'][\s\S]{0,200}markLocalChanged/);
assert.doesNotMatch(sync, /onAuthStateChange[\s\S]{0,300}sync\s*\(/, "Auth changes must not trigger state sync");
assert.doesNotMatch(sync, /if \(session[^\n]{0,100}sync\s*\(/, "Startup must not trigger state sync");

assert.equal(component.product, "RAH Project Brain Cloud Sync");
assert.equal(component.version, "1.1.0");
assert.equal(component.stage, "candidate");
assert.equal(component.features.explicit_sync_only, true);
assert.equal(component.features.automatic_sync, false);
assert.equal(component.features.background_timer, false);
assert.equal(component.features.click_change_watch, false);
assert.equal(component.features.login_triggered_sync, false);
assert.equal(component.features.upload_requires_confirmation, true);
assert.equal(component.features.download_requires_confirmation, true);
assert.equal(component.features.inspect_sends_local_state, false);
assert.equal(component.features.legacy_index_mutator_retired, true);
assert.equal(component.features.automatic_sending, false);
assert.equal(component.next_milestone, "stable-gate");

assert.match(sql, /enable row level security/i);
assert.match(sql, /auth\.uid\(\) = user_id/g);
assert.match(sql, /revoke all .* from anon/i);

const stable = {raven_vision:"0.6",raven_council:"0.3",agent_runner:"0.3",memory_sync:"0.2",mission_control:"2.9",project_focus:"2.4",raven_core:"1.12",raven_now:"2.17",raven_studio:"2.8"};
assert.deepEqual(master.release_gate.stable_components, stable);
assert.equal(master.privacy.raven_chronicle_stable, true);
assert.equal(master.privacy.system_health_stable, true);
assert.equal(master.privacy.case_center_stable, true);
assert.equal(master.privacy.project_brain_cloud_sync_explicit_only, true);
assert.equal(master.privacy.project_brain_cloud_sync_automatic_sync, false);
assert.equal(master.privacy.project_brain_cloud_sync_background_timer, false);
assert.equal(master.privacy.project_brain_cloud_sync_click_change_watch, false);
assert.equal(master.privacy.project_brain_cloud_sync_login_triggered_sync, false);
assert.equal(master.privacy.project_brain_cloud_sync_upload_requires_confirmation, true);
assert.equal(master.privacy.project_brain_cloud_sync_download_requires_confirmation, true);
assert.equal(master.privacy.project_brain_cloud_sync_legacy_index_mutator_retired, true);
assert.equal(master.privacy.project_brain_cloud_sync_stable, false);

console.log("RAH Project Brain Cloud Sync v1.1 candidate contract passed.");
'''
(ROOT / 'tests/cloud-sync.test.mjs').write_text(test, encoding='utf-8')

for p, expected in before.items():
    actual = digest(p)
    if actual != expected:
        raise SystemExit(f'Frozen surface changed: {p}')

print('Cloud Sync v1.1 candidate product patch applied; frozen Raven surfaces preserved.')
