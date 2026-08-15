/* RAH Raven Project Brain Cloud Sync v1.1
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
