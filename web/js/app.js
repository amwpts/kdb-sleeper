// Application shell: navigation, header, refresh, and the shared loading and
// error states.  Browser side state is a single plain object.
const App = (function () {
  const SECTIONS = {
    overview: OverviewView,
    standings: StandingsView,
    rosters: RostersView,
    matchups: MatchupsView,
    players: PlayersView,
  };

  const state = {
    section: "overview",
    league: { status: "loading", currentWeek: 1, season: "", userId: "" },
    rosterId: null,
    week: null,
    standings: { sortKey: "rank", sortDirection: "asc", filter: "" },
    roster: { sortKey: null, sortDirection: "asc", filter: "" },
    players: {
      sortKey: "points",
      sortDirection: "desc",
      filter: "",
      availability: "all",
      positions: [],
      selected: [],
    },
    comparing: false,
    compare: { fromWeek: 1, toWeek: 18 },
    refreshing: false,
  };

  let viewHost = null;
  let refreshButton = null;
  let refreshLabel = null;
  let toastTimer = null;

  // -------------------------------------------------------------------------
  // Shared pieces of UI
  // -------------------------------------------------------------------------

  function renderLoading(container, shape) {
    container.innerHTML = "";
    const wrapper = document.createElement("div");

    if (shape === "cards") {
      wrapper.className = "skeleton-grid";
      for (let i = 0; i < 4; i += 1) {
        const block = document.createElement("div");
        block.className = "skeleton skeleton-card";
        wrapper.appendChild(block);
      }
    } else {
      wrapper.className = "card";
      for (let i = 0; i < 6; i += 1) {
        const block = document.createElement("div");
        block.className = "skeleton skeleton-row";
        wrapper.appendChild(block);
      }
    }

    container.appendChild(wrapper);
  }

  function notice(title, message, actionLabel, action, isError) {
    const panel = document.createElement("section");
    panel.className = "card notice" + (isError ? " notice-error" : "");

    const heading = document.createElement("h2");
    heading.textContent = title;
    const body = document.createElement("p");
    body.textContent = message;
    panel.append(heading, body);

    if (actionLabel && action) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "button button-primary";
      button.textContent = actionLabel;
      button.addEventListener("click", action);
      panel.appendChild(button);
    }

    return panel;
  }

  function showToast(message, kind) {
    const toast = document.getElementById("toast");
    toast.textContent = message;
    toast.className = `toast is-visible ${kind === "error" ? "is-error" : "is-success"}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => {
      toast.className = "toast";
    }, kind === "error" ? 7000 : 3500);
  }

  // -------------------------------------------------------------------------
  // Header
  // -------------------------------------------------------------------------

  function initials(name) {
    const words = String(name || "").trim().split(/\s+/).filter(Boolean);
    if (!words.length) return "--";
    if (words.length === 1) return words[0].slice(0, 2).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  function paintHeader() {
    const league = state.league;
    const hasLeague = league.status === "ready";
    const settingUp = league.status === "setup";
    const title = hasLeague ? league.name : settingUp ? "Fantasy League" : "No league loaded";

    document.getElementById("league-name").textContent = title;
    document.getElementById("league-crest").textContent = initials(settingUp ? "Fantasy League" : hasLeague ? league.name : "");
    document.getElementById("season-chip").textContent = league.season ? `${league.season} season` : "Season --";

    const weekChip = document.getElementById("week-chip");
    weekChip.textContent = `Week ${league.currentWeek || 1}`;
    weekChip.classList.toggle("chip-accent", hasLeague);

    const teamsChip = document.getElementById("teams-chip");
    teamsChip.textContent = league.totalRosters ? `${league.totalRosters} teams` : "";
    teamsChip.hidden = !league.totalRosters;

    document.getElementById("last-refreshed").textContent = Format.relativeTime(league.lastRefreshed);
    document.title = hasLeague ? `${league.name} · Fantasy League` : "Fantasy League";
    paintChrome();
  }

  function paintTabs() {
    for (const tab of document.querySelectorAll(".tab")) {
      tab.setAttribute("aria-selected", String(tab.dataset.section === state.section));
    }
  }

  // Until a league has been chosen there is nothing to navigate or refresh.
  function paintChrome() {
    const settingUp = state.league.status === "setup";
    document.querySelector(".tabs").hidden = settingUp;
    document.querySelector(".identity-meta").hidden = settingUp;
    refreshButton.hidden = settingUp;
    document.querySelector(".refresh-info").hidden = settingUp;
  }

  // -------------------------------------------------------------------------
  // Views
  // -------------------------------------------------------------------------

  // Sections that carry a lot of columns get more of the window.
  const WIDE_SECTIONS = ["players"];

  async function draw() {
    paintTabs();
    paintChrome();
    viewHost.classList.toggle("view-wide", WIDE_SECTIONS.includes(state.section));

    if (state.league.status === "setup") {
      SetupView.render(viewHost);
      return;
    }

    if (state.league.status === "empty") {
      viewHost.innerHTML = "";
      viewHost.appendChild(
        notice(
          "No league data yet",
          "Nothing has been downloaded from Sleeper yet. Press Refresh to fetch your league.",
          "Download my league",
          () => refresh()
        )
      );
      return;
    }

    // Comparing is a screen of its own, reached from the players page.
    if (state.comparing && state.section === "players") {
      try {
        await CompareView.load(viewHost, state.players.selected);
      } catch (error) {
        viewHost.innerHTML = "";
        viewHost.appendChild(
          notice("Could not compare these players", error.message, "Back to players",
            () => stopComparing(), true)
        );
      }
      return;
    }

    const view = SECTIONS[state.section];
    try {
      await view.render(viewHost);
    } catch (error) {
      viewHost.innerHTML = "";
      viewHost.appendChild(
        notice("Could not load this page", error.message, "Try again", () => draw(), true)
      );
    }
  }

  function show(section) {
    if (!SECTIONS[section] || state.section === section) return;
    state.section = section;
    state.comparing = false;
    draw();
  }

  // -------------------------------------------------------------------------
  // Comparing players
  // -------------------------------------------------------------------------

  const MOST_COMPARABLE = 6;

  function toggleComparison(playerId) {
    const chosen = state.players.selected;
    const at = chosen.indexOf(playerId);
    if (at === -1) {
      if (chosen.length >= MOST_COMPARABLE) {
        showToast(`Up to ${MOST_COMPARABLE} players can be compared at once.`, "error");
        PlayersView.refreshSelection(viewHost);
        return;
      }
      chosen.push(playerId);
    } else {
      chosen.splice(at, 1);
    }
    PlayersView.refreshSelection(viewHost);
  }

  function startComparing() {
    if (state.players.selected.length < 2) return;
    state.comparing = true;
    draw();
  }

  function stopComparing() {
    state.comparing = false;
    draw();
  }

  function removeFromComparison(playerId) {
    const chosen = state.players.selected;
    const at = chosen.indexOf(playerId);
    if (at !== -1) chosen.splice(at, 1);
    if (chosen.length < 2) {
      stopComparing();
      return;
    }
    draw();
  }

  // -------------------------------------------------------------------------
  // Refreshing
  // -------------------------------------------------------------------------

  function setRefreshing(busy) {
    state.refreshing = busy;
    refreshButton.disabled = busy;
    refreshButton.classList.toggle("is-busy", busy);
    refreshLabel.textContent = busy ? "Refreshing…" : "Refresh";
  }

  // Only promise that old data is still on screen when there actually is some.
  function refreshFailureMessage(error) {
    const message = /[.!?]$/.test(error.message) ? error.message : `${error.message}.`;
    return state.league.status === "ready"
      ? `${message} The data already downloaded is still being shown.`
      : message;
  }

  async function refresh() {
    if (state.refreshing) return;
    setRefreshing(true);

    try {
      const result = await Api.refresh();
      if (result.status === "needsLeagueSelection") {
        showLeaguePicker(result.choices);
        return;
      }
      await loadLeague();
      RostersView.forget();
      PlayersView.forget();
      state.week = null;
      await draw();
      showToast("Sleeper data refreshed.", "success");
    } catch (error) {
      showToast(refreshFailureMessage(error), "error");
    } finally {
      setRefreshing(false);
    }
  }

  function showLeaguePicker(choices) {
    viewHost.innerHTML = "";

    const panel = document.createElement("section");
    panel.className = "card notice";
    const heading = document.createElement("h2");
    heading.textContent = "Choose a league";
    const body = document.createElement("p");
    body.textContent = "You belong to more than one league this season. Pick the one you want to follow.";
    panel.append(heading, body);

    const picker = document.createElement("div");
    picker.className = "team-picker";
    for (const league of choices) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "team-pill";
      const name = document.createElement("span");
      name.textContent = league.name;
      const detail = document.createElement("span");
      detail.className = "team-record";
      detail.textContent = `${league.totalRosters} teams`;
      button.append(name, detail);
      button.addEventListener("click", async () => {
        button.disabled = true;
        picker.classList.add("is-busy");
        try {
          await Api.selectLeague(league.leagueId);
          await reload();
          showToast(`Now following ${league.name}.`, "success");
        } catch (error) {
          button.disabled = false;
          picker.classList.remove("is-busy");
          showToast(error.message, "error");
        }
      });
      picker.appendChild(button);
    }

    panel.appendChild(picker);
    viewHost.appendChild(panel);
  }

  // -------------------------------------------------------------------------
  // Start-up
  // -------------------------------------------------------------------------

  async function loadLeague() {
    state.league = await Api.league();
    paintHeader();
    paintChrome();
  }

  // Re-read the league and redraw from scratch, after a refresh or a setup.
  async function reload() {
    await loadLeague();
    RostersView.forget();
    PlayersView.forget();
    state.week = null;
    state.section = "overview";
    await draw();
  }

  async function start() {
    viewHost = document.getElementById("view");
    refreshButton = document.getElementById("refresh-button");
    refreshLabel = document.getElementById("refresh-label");

    refreshButton.addEventListener("click", refresh);
    for (const tab of document.querySelectorAll(".tab")) {
      tab.addEventListener("click", () => show(tab.dataset.section));
    }

    renderLoading(viewHost, "cards");

    try {
      await loadLeague();
    } catch (error) {
      viewHost.innerHTML = "";
      viewHost.appendChild(
        notice("Could not talk to the q server", error.message, "Try again", () => start(), true)
      );
      return;
    }

    await draw();

    // Tables use the rest of the window, so they have to be remeasured when it
    // changes size.
    window.addEventListener("resize", Tables.fitScrollers);

    // Keep the "last refreshed" wording current without asking the server.
    setInterval(paintHeader, 30000);
  }

  return { state, show, draw, reload, refresh, showLeaguePicker, renderLoading, notice, showToast,
           toggleComparison, startComparing, stopComparing, removeFromComparison, start };
})();

document.addEventListener("DOMContentLoaded", App.start);
