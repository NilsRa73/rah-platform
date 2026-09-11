const DEFAULTS = {
  enabled: true,
  includeNonWorkTitles: false,
  workDomains: ["chatgpt.com", "github.com", "dash.cloudflare.com", "cloudflare.com", "localhost", "127.0.0.1"]
};

async function load() {
  const cfg = await chrome.storage.local.get(DEFAULTS);
  document.getElementById("enabled").checked = !!cfg.enabled;
  document.getElementById("includeNonWorkTitles").checked = !!cfg.includeNonWorkTitles;
  document.getElementById("domains").value = (cfg.workDomains || []).join("\n");
}

async function save() {
  const workDomains = document.getElementById("domains").value
    .split(/\r?\n/).map(x => x.trim().toLowerCase()).filter(Boolean);
  await chrome.storage.local.set({
    enabled: document.getElementById("enabled").checked,
    includeNonWorkTitles: document.getElementById("includeNonWorkTitles").checked,
    workDomains: [...new Set(workDomains)]
  });
  const s = document.getElementById("status");
  s.textContent = "Saved";
  setTimeout(() => { s.textContent = ""; }, 1600);
}

document.getElementById("save").addEventListener("click", save);
load();
