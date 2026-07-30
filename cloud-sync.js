/* RAH Raven Cloud Sync v1.0
 * Local-first synchronization for Command Center state.
 * Requires Supabase table from supabase/001_project_brain_sync.sql.
 */
(() => {
  "use strict";

  const SUPABASE_URL = "https://zespiaujgkyclsfhayji.supabase.co";
  const SUPABASE_KEY = "sb_publishable_NkxP_f5GMH9hCqZvW94YOw_8g_VXe42";
  const META_KEY = "rah-cloud-sync-meta-v1";
  const SYNC_INTERVAL_MS = 30000;
  const DEBOUNCE_MS = 1800;

  let client = null;
  let session = null;
  let timer = null;
  let debounceTimer = null;
  let syncing = false;
  let schemaReady = true;

  const meta = loadMeta();

  function loadMeta() {
    try {
      return Object.assign({
        enabled: true,
        lastLocalChange: null,
        lastCloudSync: null,
        lastCloudUpdatedAt: null,
        lastError: null
      }, JSON.parse(localStorage.getItem(META_KEY) || "{}"));
    } catch {
      return { enabled: true };
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
          <h2>☁️ Project Brain Cloud Sync</h2>
          <div class="meta">Privat synkronisering mellom enhetene dine. Lokal lagring virker alltid.</div>
        </div>
        <span class="pill" id="rahCloudSyncPill">LOKAL</span>
      </div>
      <div class="list-item"><span>Innlogging</span><span id="rahCloudUser" class="meta">Ikke innlogget</span></div>
      <div class="list-item"><span>Siste synk</span><span id="rahCloudLastSync" class="meta">Aldri</span></div>
      <div id="rahCloudSyncStatus" class="muted" style="margin:10px 0">Venter på innlogging.</div>
      <div class="row">
        <button class="btn primary" id="rahCloudSyncNow">↕ Synkroniser nå</button>
        <button class="btn" id="rahCloudUpload">⬆ Bruk denne enheten</button>
        <button class="btn" id="rahCloudDownload">⬇ Hent fra skyen</button>
        <button class="btn" id="rahCloudToggle">Auto-sync: PÅ</button>
      </div>`;
    target.appendChild(panel);

    document.getElementById("rahCloudSyncNow").onclick = () => sync("auto", true);
    document.getElementById("rahCloudUpload").onclick = () => sync("upload", true);
    document.getElementById("rahCloudDownload").onclick = () => sync("download", true);
    document.getElementById("rahCloudToggle").onclick = () => {
      meta.enabled = !meta.enabled;
      saveMeta();
      renderStatus();
      configureTimer();
    };
    renderStatus();
  }

  function renderStatus() {
    const pill = document.getElementById("rahCloudSyncPill");
    const user = document.getElementById("rahCloudUser");
    const last = document.getElementById("rahCloudLastSync");
    const toggle = document.getElementById("rahCloudToggle");

    if (pill) pill.textContent = session ? (schemaReady ? "CLOUD" : "SETUP") : "LOKAL";
    if (user) user.textContent = session?.user?.email || "Ikke innlogget";
    if (last) last.textContent = meta.lastCloudSync
      ? new Date(meta.lastCloudSync).toLocaleString("no-NO")
      : "Aldri";
    if (toggle) toggle.textContent = `Auto-sync: ${meta.enabled ? "PÅ" : "AV"}`;

    if (!session) setStatus("Logg inn som RAH-medlem for å aktivere sky-synk.");
    else if (!schemaReady) setStatus("Supabase-tabellen mangler. Kjør supabase/001_project_brain_sync.sql.", "sync-warn");
    else if (meta.lastError) setStatus(meta.lastError, "sync-warn");
    else if (syncing) setStatus("Synkroniserer…", "sync-good");
    else setStatus(meta.enabled ? "Auto-sync er aktiv." : "Auto-sync er deaktivert.");
  }

  function markLocalChanged() {
    meta.lastLocalChange = new Date().toISOString();
    saveMeta();
    if (!meta.enabled || !session) return;
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => sync("auto"), DEBOUNCE_MS);
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
      .upsert({
        user_id: session.user.id,
        state: current,
        client_updated_at: meta.lastLocalChange || now
      }, { onConflict: "user_id" })
      .select("updated_at")
      .single();
    if (error) throw error;
    meta.lastCloudUpdatedAt = data.updated_at;
    meta.lastCloudSync = now;
    meta.lastError = null;
    saveMeta();
  }

  async function downloadCloud(row) {
    if (!row?.state) return false;
    const ok = applyState(row.state);
    if (!ok) throw new Error("Kunne ikke gjenopprette Project Brain fra skyen.");
    meta.lastCloudUpdatedAt = row.updated_at;
    meta.lastCloudSync = new Date().toISOString();
    meta.lastLocalChange = row.client_updated_at || row.updated_at;
    meta.lastError = null;
    saveMeta();
    return true;
  }

  async function sync(mode = "auto", visible = false) {
    if (syncing || !meta.enabled && mode === "auto") return;
    if (!session || !client) {
      if (visible) setStatus("Logg inn før synkronisering.", "sync-warn");
      return;
    }

    syncing = true;
    renderStatus();
    try {
      const cloud = await fetchCloud();
      schemaReady = true;

      if (mode === "upload") {
        await uploadLocal();
      } else if (mode === "download") {
        if (!cloud) throw new Error("Ingen Project Brain-data finnes i skyen ennå.");
        await downloadCloud(cloud);
      } else if (!cloud) {
        await uploadLocal();
      } else {
        const localTime = Date.parse(meta.lastLocalChange || 0);
        const cloudTime = Date.parse(cloud.client_updated_at || cloud.updated_at || 0);
        if (cloudTime > localTime) await downloadCloud(cloud);
        else await uploadLocal();
      }

      if (typeof addActivity === "function") {
        addActivity("Project Brain synkronisert med Supabase");
        saveState();
      }
      setStatus("Project Brain er synkronisert.", "sync-good");
    } catch (error) {
      const message = error?.message || String(error);
      schemaReady = !/rah_user_state|relation .* does not exist|schema cache/i.test(message);
      meta.lastError = schemaReady
        ? `Cloud Sync: ${message}`
        : "Cloud Sync må aktiveres i Supabase SQL Editor.";
      saveMeta();
      setStatus(meta.lastError, "sync-warn");
      console.error("RAH Cloud Sync", error);
    } finally {
      syncing = false;
      renderStatus();
    }
  }

  function configureTimer() {
    clearInterval(timer);
    if (meta.enabled) timer = setInterval(() => sync("auto"), SYNC_INTERVAL_MS);
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
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });

    const { data } = await client.auth.getSession();
    session = data.session;
    renderStatus();

    client.auth.onAuthStateChange((_event, nextSession) => {
      session = nextSession;
      renderStatus();
      if (session && meta.enabled) setTimeout(() => sync("auto"), 500);
    });

    const originalSave = window.saveState;
    if (typeof originalSave === "function") {
      window.saveState = function rahCloudAwareSaveState(...args) {
        const result = originalSave.apply(this, args);
        markLocalChanged();
        return result;
      };
    }

    document.addEventListener("change", markLocalChanged, true);
    document.addEventListener("click", event => {
      if (event.target.closest("button") && !event.target.closest("#rahCloudSyncPanel")) {
        setTimeout(markLocalChanged, 50);
      }
    }, true);

    configureTimer();
    if (session && meta.enabled) sync("auto");
  }

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start);
  else start();
})();
