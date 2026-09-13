// Rosters: pick a team, then look through its players.
const RostersView = (function () {
  const SEARCH_FIELDS = ["fullName", "position", "team"];

  let teams = [];
  let detail = null;

  const columns = [
    {
      key: "fullName",
      label: "Player",
      render: (player) => {
        const node = document.createElement("span");
        node.className = "team-cell";
        node.textContent = player.fullName;
        if (player.injuryStatus) {
          const badge = document.createElement("span");
          badge.className = Format.injuryClass(player.injuryStatus);
          badge.textContent = Format.injuryLabel(player.injuryStatus);
          node.appendChild(badge);
        }
        return node;
      },
    },
    {
      key: "team",
      label: "NFL team",
      render: (player) => {
        const node = document.createElement("span");
        node.className = "muted";
        node.textContent = player.team || "FA";
        return node;
      },
    },
    {
      key: "position",
      label: "Pos",
      render: (player) => {
        const badge = document.createElement("span");
        badge.className = Format.positionClass(player.position);
        badge.textContent = player.position || "—";
        return badge;
      },
    },
    {
      key: "starter",
      label: "Line-up",
      render: (player) => {
        if (player.starter) {
          const badge = document.createElement("span");
          badge.className = "badge badge-starter";
          badge.textContent = "STARTER";
          return badge;
        }
        const node = document.createElement("span");
        node.className = "muted";
        node.textContent = player.reserve ? "Reserve" : "Bench";
        return node;
      },
    },
    {
      key: "injuryStatus",
      label: "Status",
      render: (player) => {
        const node = document.createElement("span");
        node.className = "muted";
        node.textContent = player.injuryStatus || player.status || "—";
        return node;
      },
    },
  ];

  function picker(container) {
    const wrapper = document.createElement("div");
    wrapper.className = "team-picker";

    for (const team of teams) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "team-pill";
      button.setAttribute("aria-pressed", String(team.rosterId === App.state.rosterId));

      const name = document.createElement("span");
      name.textContent = team.teamName;

      const record = document.createElement("span");
      record.className = "team-record";
      record.textContent = Format.record(team.wins, team.losses, team.ties);

      button.append(name, record);
      button.addEventListener("click", () => {
        if (team.rosterId === App.state.rosterId) return;
        App.state.rosterId = team.rosterId;
        render(container);
      });
      wrapper.appendChild(button);
    }
    return wrapper;
  }

  function summaryCard(team) {
    const card = document.createElement("section");
    card.className = "card roster-summary";

    const left = document.createElement("div");
    const name = document.createElement("div");
    name.className = "roster-summary-name";
    name.textContent = team.teamName;
    const owner = document.createElement("div");
    owner.className = "roster-summary-owner";
    owner.textContent = team.username ? `${team.ownerName} · @${team.username}` : team.ownerName;
    left.append(name, owner);

    const stats = document.createElement("div");
    stats.className = "summary-stats";
    const entries = [
      ["Record", Format.record(team.wins, team.losses, team.ties)],
      ["Points for", Format.points(team.pointsFor)],
      ["Points against", Format.points(team.pointsAgainst)],
    ];
    for (const [label, value] of entries) {
      const stat = document.createElement("div");
      stat.className = "summary-stat";
      const labelNode = document.createElement("span");
      labelNode.className = "stat-label";
      labelNode.textContent = label;
      const valueNode = document.createElement("span");
      valueNode.className = "value";
      valueNode.textContent = value;
      stat.append(labelNode, valueNode);
      stats.appendChild(stat);
    }

    card.append(left, stats);
    return card;
  }

  function drawPlayers(host) {
    const state = App.state.roster;
    const players = detail ? detail.players : [];

    const filtered = Tables.filterRows(players, state.filter, SEARCH_FIELDS);
    const sorted = state.sortKey
      ? Tables.sortRows(filtered, state.sortKey, state.sortDirection)
      : filtered;

    const count = host.querySelector("[data-result-count]");
    count.textContent =
      filtered.length === players.length
        ? `${players.length} players`
        : `${filtered.length} of ${players.length} players`;

    Tables.render(host.querySelector("[data-table]"), {
      columns,
      rows: sorted,
      sortKey: state.sortKey,
      sortDirection: state.sortDirection,
      rowClass: (player) => (player.starter ? "" : "is-bench"),
      emptyMessage: state.filter
        ? `No player matches “${state.filter}”.`
        : "This roster has no players yet.",
      onSort: (key, preferred) => {
        state.sortDirection = Tables.nextSortDirection(state.sortKey, state.sortDirection, key, preferred);
        state.sortKey = key;
        drawPlayers(host);
      },
    });
  }

  async function render(container) {
    App.renderLoading(container, "table");

    if (!teams.length) {
      teams = await Api.teams();
    }

    if (!teams.length) {
      container.innerHTML = "";
      container.appendChild(
        App.notice("No teams yet", "Refresh to download the teams in your league.")
      );
      return;
    }

    if (!teams.some((team) => team.rosterId === App.state.rosterId)) {
      App.state.rosterId = teams[0].rosterId;
    }

    detail = await Api.roster(App.state.rosterId);

    container.innerHTML = "";
    container.appendChild(picker(container));
    container.appendChild(summaryCard(detail.team));

    const card = document.createElement("section");
    card.className = "card";

    const heading = document.createElement("div");
    heading.className = "section-heading";
    const title = document.createElement("h2");
    title.textContent = "Roster";
    const hint = document.createElement("span");
    hint.className = "hint";
    hint.textContent = "Starters are listed first";
    heading.append(title, hint);
    card.appendChild(heading);

    const toolbar = document.createElement("div");
    toolbar.className = "toolbar";

    const search = document.createElement("div");
    search.className = "search";
    const label = document.createElement("label");
    label.className = "visually-hidden";
    label.setAttribute("for", "roster-search");
    label.textContent = "Filter players";
    const input = document.createElement("input");
    input.id = "roster-search";
    input.type = "search";
    input.placeholder = "Filter by player, position or NFL team";
    input.value = App.state.roster.filter;
    input.addEventListener("input", () => {
      App.state.roster.filter = input.value;
      drawPlayers(card);
    });
    search.append(label, input);

    const count = document.createElement("span");
    count.className = "result-count";
    count.setAttribute("data-result-count", "");

    toolbar.append(search, count);
    card.appendChild(toolbar);

    const tableHost = document.createElement("div");
    tableHost.setAttribute("data-table", "");
    card.appendChild(tableHost);

    container.appendChild(card);
    drawPlayers(card);
  }

  function forget() {
    teams = [];
    detail = null;
  }

  return { render, forget };
})();
