const DEFAULTS = {
  enabled: true,
  includeNonWorkTitles: false,
  workDomains: [
    "chatgpt.com",
    "github.com",
    "dash.cloudflare.com",
    "cloudflare.com",
    "localhost",
    "127.0.0.1"
  ]
};

let current = null;

async function settings() {
  return await chrome.storage.local.get(DEFAULTS);
}

function safeUrl(raw) {
  try {
    const u = new URL(raw || "");
    if (!["http:", "https:"].includes(u.protocol)) return null;
    return u;
  } catch (_) {
    return null;
  }
}

function domainMatches(hostname, patterns) {
  const h = (hostname || "").toLowerCase();
  return patterns.some((p) => {
    const x = String(p || "").trim().toLowerCase();
    return x && (h === x || h.endsWith("." + x));
  });
}

async function sanitizeTab(tab) {
  if (!tab || tab.incognito) return null;
  const cfg = await settings();
  if (!cfg.enabled) return null;
  const u = safeUrl(tab.url);
  if (!u) return null;
  const work = domainMatches(u.hostname, cfg.workDomains || []);
  return {
    tab_id: tab.id ?? null,
    domain: u.hostname,
    url: work ? `${u.origin}${u.pathname}` : u.origin,
    title: work || cfg.includeNonWorkTitles ? (tab.title || u.hostname) : "Private tab",
    work: !!work
  };
}

async function sendEvent(event) {
  try {
    await fetch("http://127.0.0.1:18766/event", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...event, ts: Date.now() / 1000 })
    });
  } catch (_) {
    // Collector may be stopped; tracking resumes automatically when it returns.
  }
}

async function closeCurrent(reason = "switch") {
  if (!current) return;
  const now = Date.now();
  const duration = Math.max(0, Math.round((now - current.startedAt) / 1000));
  await sendEvent({
    type: "focus_end",
    reason,
    duration_s: duration,
    ...current.tab
  });
  current = null;
}

async function beginTab(tab, reason = "activate") {
  const clean = await sanitizeTab(tab);
  if (!clean) return;
  await closeCurrent("switch");
  current = { tab: clean, startedAt: Date.now() };
  await sendEvent({ type: "focus_start", reason, duration_s: 0, ...clean });
}

async function refreshActive(reason = "refresh") {
  try {
    const win = await chrome.windows.getLastFocused({ populate: false });
    if (!win || win.focused === false) {
      await closeCurrent("browser_unfocused");
      return;
    }
    const [tab] = await chrome.tabs.query({ active: true, lastFocusedWindow: true });
    if (!tab) return;
    const clean = await sanitizeTab(tab);
    if (!clean) {
      await closeCurrent("unsupported_tab");
      return;
    }
    if (current && current.tab.tab_id === clean.tab_id && current.tab.url === clean.url && current.tab.title === clean.title) {
      await sendEvent({ type: "heartbeat", reason, duration_s: 0, ...clean });
      return;
    }
    await beginTab(tab, reason);
  } catch (_) {}
}

chrome.runtime.onInstalled.addListener(async () => {
  const currentSettings = await chrome.storage.local.get(DEFAULTS);
  await chrome.storage.local.set({ ...DEFAULTS, ...currentSettings });
  chrome.alarms.create("rah-chronicle-heartbeat", { periodInMinutes: 1 });
  await refreshActive("installed");
});

chrome.runtime.onStartup.addListener(async () => {
  chrome.alarms.create("rah-chronicle-heartbeat", { periodInMinutes: 1 });
  await refreshActive("startup");
});

chrome.tabs.onActivated.addListener(async ({ tabId }) => {
  try { await beginTab(await chrome.tabs.get(tabId), "activated"); } catch (_) {}
});

chrome.tabs.onUpdated.addListener(async (tabId, changeInfo, tab) => {
  if (!tab.active) return;
  if (changeInfo.url || changeInfo.title || changeInfo.status === "complete") {
    await refreshActive("updated");
  }
});

chrome.tabs.onRemoved.addListener(async (tabId) => {
  if (current && current.tab.tab_id === tabId) await closeCurrent("tab_closed");
});

chrome.windows.onFocusChanged.addListener(async (windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) await closeCurrent("browser_unfocused");
  else await refreshActive("window_focus");
});

chrome.idle.onStateChanged.addListener(async (state) => {
  if (state === "active") await refreshActive("idle_return");
  else await closeCurrent("idle_" + state);
});

chrome.alarms.onAlarm.addListener(async (alarm) => {
  if (alarm.name === "rah-chronicle-heartbeat") await refreshActive("heartbeat");
});
