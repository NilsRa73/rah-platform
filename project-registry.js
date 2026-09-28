/* RAH Project Registry Bridge v1.0
 * Connects raven/projects.json to the existing Command Center.
 * Safe defaults: registry reads only; no project files are modified or deleted.
 */
(() => {
  "use strict";

  const VERSION = "1.0.0";
  const REGISTRY_PATH = "raven/projects.json";
  const LEGACY_SEED_NAMES = new Set([
    "RAH Raven Command Center",
    "RAH Vision",
    "RAH Raven Browser"
  ]);
  const STAGE_PROGRESS = Object.freeze({
    planned: 10,
    prototype: 25,
    active: 55,
    candidate: 75,
    stabilize: 85,
    stable: 100,
    paused: 40,
    blocked: 40
  });
  const registryState = {
    status: "idle",
    loadedAt: null,
    error: null,
    data: null
  };

  function registryUrl() {
    return new URL(REGISTRY_PATH, window.location.href).toString();
  }

  function normalizeProject(project) {
    const stage = String(project?.stage || "planned").toLowerCase();
    return {
      registryManaged: true,
      registryId: String(project?.id || ""),
      priority: Number(project?.priority || 999),
      name: String(project?.name || project?.id || "RAH Project"),
      url: project?.repo
        ? `https://github.com/${project.repo}`
        : String(project?.url || ""),
      progress: Number(STAGE_PROGRESS[stage] ?? 0),
      status: stage,
      stage,
      stable: project?.stable ?? null,
      candidate: project?.candidate ?? null,
      next: String(project?.next || ""),
      paths: Array.isArray(project?.paths) ? project.paths : [],
      checks: Array.isArray(project?.checks) ? project.checks : []
    };
  }

  function isActiveMission(mission) {
    return Boolean(
      mission &&
      !["COMPLETED", "CANCELLED"].includes(String(mission.status || "").toUpperCase())
    );
  }

  function mergeRegistryProjects(registryProjects) {
    const current = Array.isArray(state.projects) ? state.projects : [];
    const byId = new Map(
      current
        .filter(project => project?.registryId)
        .map(project => [project.registryId, project])
    );
    const managed = registryProjects
      .map(normalizeProject)
      .sort((a, b) => a.priority - b.priority)
      .map(project => ({ ...byId.get(project.registryId), ...project }));

    const preserved = current.filter(project =>
      !project?.registryManaged &&
      !LEGACY_SEED_NAMES.has(String(project?.name || ""))
    );

    const previous = current[state.activeProject];
    const previousId = previous?.registryId || null;
    state.projects = [...managed, ...preserved];

    const restoredIndex = previousId
      ? state.projects.findIndex(project => project.registryId === previousId)
      : -1;
    state.activeProject = restoredIndex >= 0 ? restoredIndex : 0;
    state.registryVersion = registryState.data?.schema_version || 1;
    state.registryUpdated = registryState.data?.updated || null;
    state.registryLoadedAt = new Date().toISOString();
    saveState();
  }

  function projectMeta(project) {
    if (!project?.registryManaged) {
      return `${project?.status || "Ukjent"} • ${project?.progress ?? 0}% fullført`;
    }
    const labels = [
      `#${project.priority}`,
      String(project.stage || project.status || "tracked").toUpperCase()
    ];
    if (project.candidate) labels.push(`Candidate: ${project.candidate}`);
    if (project.stable) labels.push(`Stable: ${project.stable}`);
    return labels.join(" • ");
  }

  function activeRegistryProject() {
    const active = state.projects?.[state.activeProject];
    if (active?.registryManaged) return active;
    return (state.projects || []).find(project => project?.registryManaged) || active || null;
  }

  function createRegistryMission(project) {
    const stamp = Date.now();
    return {
      id: `registry-${project.registryId || "project"}-${stamp}`,
      presetId: "registry",
      projectId: project.registryId || null,
      projectPriority: project.priority || null,
      title: `Fortsett: ${project.name}`,
      description: project.next || "Finn neste konkrete, testbare handling.",
      ravens: [
        "Raven Supervisor",
        "Huginn Scout",
        "Brokkr Builder",
        "Heimdall Tester",
        "Mímir Analyst"
      ],
      status: "RUNNING",
      currentStep: 0,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      steps: [
        {
          id: `registry-${stamp}-scan`,
          title: "Åpne prosjektet og bekreft dagens status",
          detail: project.next || "Kontroller Candidate, kjent-good status og blokkere.",
          action: "open-project",
          done: false,
          status: "PENDING"
        },
        {
          id: `registry-${stamp}-task`,
          title: "Registrer neste konkrete handling",
          detail: project.next || `Fortsett arbeid på ${project.name}`,
          action: "create-project-task",
          done: false,
          status: "PENDING"
        },
        {
          id: `registry-${stamp}-brain`,
          title: "Arbeid fra Candidate og dokumenter resultatet",
          detail: "Bruk Project Brain som arbeidslogg. Behold STABLE urørt til testene er grønne.",
          action: "open-brain",
          done: false,
          status: "PENDING"
        },
        {
          id: `registry-${stamp}-result`,
          title: "Lagre delresultat og teststatus",
          detail: "Oppsummer hva som ble gjort, testresultat og neste blokkering.",
          action: "save-mission-result",
          done: false,
          status: "PENDING"
        }
      ]
    };
  }

  function updateContinueButton() {
    const button = document.getElementById("continueBtn");
    if (!button) return;
    const project = activeRegistryProject();
    if (isActiveMission(state.activeMission)) {
      button.innerHTML = `<span>▶ FORTSETT AKTIV MISSION</span><span>${String(state.activeMission.title || "Mission")}</span>`;
      return;
    }
    if (project) {
      button.innerHTML = `<span>▶ CONTINUE • #${project.priority} ${escapeHtml(project.name)}</span><span>Supervisor →</span>`;
    }
  }

  function decorateProjectUi() {
    const active = activeRegistryProject();
    const activeCard = document.getElementById("activeProjectCard");
    if (activeCard && active?.registryManaged) {
      activeCard.innerHTML = `
        <div class="list-item">
          <div>
            <strong>#${active.priority} • ${escapeHtml(active.name)}</strong>
            <div class="meta">${escapeHtml(projectMeta(active))}</div>
            <div class="meta">Neste: ${escapeHtml(active.next || "Ikke satt")}</div>
          </div>
          <div class="row">
            <div class="progress"><i style="width:${Math.min(100, Math.max(0, active.progress))}%"></i></div>
            <button class="btn primary" data-registry-open>Åpne</button>
          </div>
        </div>`;
      activeCard.querySelector("[data-registry-open]")?.addEventListener("click", () => openUrl(active.url || state.repo));
    }

    const list = document.getElementById("projectList");
    if (list && registryState.data) {
      list.querySelectorAll(".list-item").forEach((row, index) => {
        const project = state.projects[index];
        if (!project?.registryManaged) return;
        const meta = row.querySelector(".meta");
        if (meta) {
          meta.textContent = `${projectMeta(project)} • Neste: ${project.next || "Ikke satt"}`;
        }
      });
    }
    updateContinueButton();
  }

  function escapeHtml(value) {
    return String(value ?? "").replace(/[&<>"']/g, char => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;"
    }[char]));
  }

  function continueProject() {
    if (isActiveMission(state.activeMission)) {
      switchView("missions");
      notify("Fortsetter aktiv mission");
      return;
    }

    const project = activeRegistryProject();
    if (!project) {
      notify("Prosjektregisteret er ikke klart ennå");
      return;
    }

    const index = state.projects.findIndex(item => item.registryId === project.registryId);
    if (index >= 0) state.activeProject = index;
    state.activeMission = createRegistryMission(project);
    addActivity(`Supervisor mission startet: ${project.name}`);
    saveState();
    render();
    switchView("missions");
    notify(`Mission klar for #${project.priority}: ${project.name}`);
  }

  async function loadRegistry() {
    registryState.status = "loading";
    registryState.error = null;

    try {
      const response = await fetch(registryUrl(), { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      if (!Array.isArray(data?.projects) || !data.projects.length) {
        throw new Error("projects.json mangler prosjekter");
      }
      registryState.data = data;
      registryState.status = "ready";
      registryState.loadedAt = new Date().toISOString();
      mergeRegistryProjects(data.projects);

      const oldRender = window.render;
      if (typeof oldRender === "function" && !oldRender.__rahRegistryWrapped) {
        const wrapped = function rahRegistryRender(...args) {
          const result = oldRender.apply(this, args);
          decorateProjectUi();
          return result;
        };
        wrapped.__rahRegistryWrapped = true;
        window.render = wrapped;
      }

      const continueButton = document.getElementById("continueBtn");
      if (continueButton) continueButton.onclick = continueProject;
      render();
      document.dispatchEvent(new CustomEvent("rah:project-registry-ready", {
        detail: { version: VERSION, projects: data.projects.length }
      }));
      console.info(`RAH Project Registry Bridge v${VERSION} ready — ${data.projects.length} projects`);
      return data;
    } catch (error) {
      registryState.status = "error";
      registryState.error = error?.message || String(error);
      updateContinueButton();
      console.warn("RAH Project Registry unavailable:", registryState.error);
      return null;
    }
  }

  window.rahProjectMeta = projectMeta;
  window.rahProjectRegistry = Object.freeze({
    version: VERSION,
    state: registryState,
    reload: loadRegistry,
    active: activeRegistryProject,
    continue: continueProject,
    createMission: createRegistryMission
  });

  loadRegistry();
})();
