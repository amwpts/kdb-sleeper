// Players: everybody worth knowing about in this league, and who has them.
const PlayersView = (function () {
  const SEARCH_FIELDS = ["fullName", "position", "team", "rosteredBy"];

  const AVAILABILITY_CHOICES = [
    { key: "all", label: "All" },
    { key: "available", label: "Available" },
    { key: "rostered", label: "Rostered" },
  ];

  let pool = [];

  // Pure, so they can be tested on their own.
  function byAvailability(rows, choice) {
    if (choice === "available") return rows.filter((player) => player.available);
    if (choice === "rostered") return rows.filter((player) => !player.available);
    return rows.slice();
  }

  function byPositions(rows, chosen) {
    if (!chosen || chosen.length === 0) return rows.slice();
    return rows.filter((player) => chosen.includes(player.position));
  }

  // Quick filter buttons, in the order people think about the positions, with
  // anything unusual the league rosters (defensive players, say) after them.
  const POSITION_ORDER = ["QB", "RB", "WR", "TE", "K", "DEF"];

  function positionsIn(rows) {
    const present = [...new Set(rows.map((player) => player.position).filter(Boolean))];
    const known = POSITION_ORDER.filter((position) => present.includes(position));
    const rest = present.filter((position) => !POSITION_ORDER.includes(position)).sort();
    return known.concat(rest);
  }

  // Built per render so the week columns can name the week they are about.
  function columnsFor(week) {
    return [
    {
      key: "fullName",
      label: "Player",
      render: (player) => {
        const node = document.createElement("span");
        node.className = "player-cell";

        const pick = document.createElement("input");
        pick.type = "checkbox";
        pick.className = "player-pick";
        pick.checked = App.state.players.selected.includes(player.playerId);
        pick.setAttribute("aria-label", `Compare ${player.fullName}`);
        pick.addEventListener("change", () => App.toggleComparison(player.playerId));

        const name = document.createElement("span");
        name.className = "team-cell";
        name.textContent = player.fullName;
        node.append(pick, name);

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
      key: "available",
      label: "Availability",
      defaultSort: "desc",
      render: (player) => {
        if (player.available) {
          const badge = document.createElement("span");
          badge.className = "badge badge-available";
          badge.textContent = "AVAILABLE";
          return badge;
        }
        const node = document.createElement("span");
        node.className = "muted";
        node.textContent = player.rosteredBy;
        return node;
      },
    },
    {
      key: "points",
      label: "Season",
      title: "Season points so far",
      numeric: true,
      render: (player) => Format.score(player.points, player.games),
    },
    {
      key: "games",
      label: "G",
      title: "Games played",
      numeric: true,
      render: (player) => String(player.games || 0),
    },
    {
      key: "pointsPerGame",
      label: "Per game",
      title: "Average points per game played",
      numeric: true,
      render: (player) => Format.score(player.pointsPerGame, player.games),
    },
    {
      key: "lastThree",
      label: "Last 3",
      title: "Average points over the last three games played",
      numeric: true,
      render: (player) => Format.score(player.lastThree),
    },
    {
      key: "currentWeekPoints",
      label: `Wk ${week}`,
      title: `Points scored in week ${week}`,
      numeric: true,
      render: (player) => Format.score(player.currentWeekPoints),
    },
    {
      key: "currentWeekProjected",
      label: `Wk ${week} proj`,
      title: `Projected points for week ${week}`,
      numeric: true,
      projection: true,
      render: (player) => Format.score(player.currentWeekProjected),
    },
    {
      key: "nextWeekProjected",
      label: `Wk ${week + 1} proj`,
      title: `Projected points for week ${week + 1}`,
      numeric: true,
      projection: true,
      render: (player) => Format.score(player.nextWeekProjected),
    },
    {
      key: "nextThreeProjected",
      label: "Next 3 proj",
      title: `Average projection for weeks ${week} to ${week + 2}, counting a bye as nothing scored`,
      numeric: true,
      projection: true,
      render: (player) => Format.score(player.nextThreeProjected),
    },
    {
      key: "seasonProjected",
      label: "Season proj",
      title: "Projected points for the whole season, added up week by week",
      numeric: true,
      projection: true,
      render: (player) => Format.score(player.seasonProjected),
    },
    {
      key: "restOfSeasonProjected",
      label: "ROS proj",
      title: `Projected points from week ${week} to the end of the season`,
      numeric: true,
      projection: true,
      render: (player) => Format.score(player.restOfSeasonProjected),
    },
    {
      key: "overUnderProjected",
      label: "vs proj",
      title: "Average points above or below projection, over the games played",
      numeric: true,
      render: (player) => {
        const node = document.createElement("span");
        const value = player.overUnderProjected;
        if (value !== null && value !== undefined) {
          node.className = value > 0 ? "over" : value < 0 ? "under" : "muted";
        }
        node.textContent = Format.signed(value);
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
  }

  function draw(host) {
    const state = App.state.players;

    const chosen = byPositions(byAvailability(pool, state.availability), state.positions);
    const filtered = Tables.filterRows(chosen, state.filter, SEARCH_FIELDS);
    const sorted = Tables.sortRows(filtered, state.sortKey, state.sortDirection);

    const available = pool.filter((player) => player.available).length;
    const count = host.querySelector("[data-result-count]");
    count.textContent =
      filtered.length === pool.length
        ? `${pool.length} players · ${available} available`
        : `${filtered.length} of ${pool.length} players`;

    const clear = host.querySelector("[data-clear]");
    clear.hidden = !(state.filter || state.availability !== "all" || state.positions.length);

    const compare = host.querySelector("[data-compare]");
    const picked = state.selected.length;
    compare.hidden = picked === 0;
    compare.disabled = picked < 2;
    compare.textContent = picked < 2 ? `Pick another to compare (${picked})` : `Compare ${picked} players`;

    Tables.render(host.querySelector("[data-table]"), {
      columns: columnsFor(App.state.league.currentWeek || 1),
      rows: sorted,
      stickyFirstColumn: true,
      sortKey: state.sortKey,
      sortDirection: state.sortDirection,
      emptyMessage:
        state.filter || state.availability !== "all" || state.positions.length
          ? "No player matches what you are looking for."
          : "No players have been downloaded yet.",
      onSort: (key, preferred) => {
        state.sortDirection = Tables.nextSortDirection(state.sortKey, state.sortDirection, key, preferred);
        state.sortKey = key;
        draw(host);
      },
    });
  }

  function availabilityControl(host) {
    const group = document.createElement("div");
    group.className = "segmented";
    group.setAttribute("role", "group");
    group.setAttribute("aria-label", "Show");

    for (const choice of AVAILABILITY_CHOICES) {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = choice.label;
      button.setAttribute("aria-pressed", String(App.state.players.availability === choice.key));
      button.addEventListener("click", () => {
        App.state.players.availability = choice.key;
        for (const other of group.querySelectorAll("button")) {
          other.setAttribute("aria-pressed", String(other === button));
        }
        draw(host);
      });
      group.appendChild(button);
    }
    return group;
  }

  function positionControl(host) {
    const row = document.createElement("div");
    row.className = "chip-row";
    row.setAttribute("role", "group");
    row.setAttribute("aria-label", "Positions");

    for (const position of positionsIn(pool)) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "chip-toggle";
      button.textContent = position;
      button.setAttribute("aria-pressed", String(App.state.players.positions.includes(position)));
      button.addEventListener("click", () => {
        const chosen = App.state.players.positions;
        const at = chosen.indexOf(position);
        if (at === -1) chosen.push(position);
        else chosen.splice(at, 1);
        button.setAttribute("aria-pressed", String(at === -1));
        draw(host);
      });
      row.appendChild(button);
    }
    return row;
  }

  // Only shown once there is something to compare.
  function compareButton(host) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "button button-primary button-small";
    button.setAttribute("data-compare", "");
    button.hidden = true;
    button.addEventListener("click", () => App.startComparing());
    return button;
  }

  function clearButton(host) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "button button-ghost button-small";
    button.textContent = "Clear filters";
    button.setAttribute("data-clear", "");
    button.hidden = true;
    button.addEventListener("click", () => {
      App.state.players.filter = "";
      App.state.players.availability = "all";
      App.state.players.positions = [];
      render(host.closest(".view") || host.parentNode);
    });
    return button;
  }

  async function render(container) {
    App.renderLoading(container, "table");
    pool = await Api.players();

    container.innerHTML = "";

    const card = document.createElement("section");
    card.className = "card";

    const heading = document.createElement("div");
    heading.className = "section-heading";
    const title = document.createElement("h2");
    title.textContent = "Players";
    const hint = document.createElement("span");
    hint.className = "hint";
    hint.textContent = "Everyone on an NFL team, plus anyone on a roster here";
    heading.append(title, hint);
    card.appendChild(heading);

    const toolbar = document.createElement("div");
    toolbar.className = "toolbar";

    const search = document.createElement("div");
    search.className = "search";
    const label = document.createElement("label");
    label.className = "visually-hidden";
    label.setAttribute("for", "players-search");
    label.textContent = "Filter players";
    const input = document.createElement("input");
    input.id = "players-search";
    input.type = "search";
    input.placeholder = "Filter by player, position, NFL team or manager";
    input.value = App.state.players.filter;
    input.addEventListener("input", () => {
      App.state.players.filter = input.value;
      draw(card);
    });
    search.append(label, input);

    const right = document.createElement("div");
    right.className = "toolbar-right";
    const count = document.createElement("span");
    count.className = "result-count";
    count.setAttribute("data-result-count", "");
    right.append(availabilityControl(card), count, compareButton(card), clearButton(card));

    // One row: searching, filtering and counting all belong together, and every
    // line above the table is a line of the table nobody can see.
    toolbar.append(search, positionControl(card), right);
    card.appendChild(toolbar);

    const tableHost = document.createElement("div");
    tableHost.setAttribute("data-table", "");
    card.appendChild(tableHost);

    container.appendChild(card);
    draw(card);
  }

  function forget() {
    pool = [];
  }

  // Redraw just the toolbar and rows, so ticking a box does not reload.
  function refreshSelection(container) {
    const card = container.querySelector(".card");
    if (card) draw(card);
  }

  return { render, forget, refreshSelection, byAvailability, byPositions, positionsIn };
})();

if (typeof window === "undefined") globalThis.PlayersView = PlayersView;
