// Standings: one sortable, filterable table.
const StandingsView = (function () {
  const SEARCH_FIELDS = ["teamName", "ownerName", "username"];

  let rows = [];

  function columns(myUserId) {
    return [
      {
        key: "rank",
        label: "#",
        render: (row) => {
          const node = document.createElement("span");
          node.className = "rank-cell";
          node.textContent = row.rank;
          return node;
        },
      },
      {
        key: "teamName",
        label: "Team",
        render: (row) => {
          const node = document.createElement("span");
          node.className = "team-cell";
          node.textContent = row.teamName;
          if (row.userId && row.userId === myUserId) {
            const tag = document.createElement("span");
            tag.className = "you-tag";
            tag.textContent = "YOU";
            node.appendChild(tag);
          }
          return node;
        },
      },
      {
        key: "ownerName",
        label: "Owner",
        render: (row) => {
          const node = document.createElement("span");
          node.className = "muted";
          node.textContent = row.ownerName;
          return node;
        },
      },
      { key: "wins", label: "W", numeric: true, render: (row) => String(row.wins) },
      { key: "losses", label: "L", numeric: true, render: (row) => String(row.losses) },
      { key: "ties", label: "T", numeric: true, render: (row) => String(row.ties) },
      { key: "pointsFor", label: "Points for", numeric: true, render: (row) => Format.points(row.pointsFor) },
      { key: "pointsAgainst", label: "Points against", numeric: true, render: (row) => Format.points(row.pointsAgainst) },
    ];
  }

  // Ties are only worth a column when somebody has actually tied.
  function visibleColumns(myUserId, data) {
    const anyTies = data.some((row) => row.ties > 0);
    return columns(myUserId).filter((column) => column.key !== "ties" || anyTies);
  }

  function draw(container) {
    const state = App.state.standings;
    const myUserId = App.state.league.userId;

    const filtered = Tables.filterRows(rows, state.filter, SEARCH_FIELDS);
    const sorted = Tables.sortRows(filtered, state.sortKey, state.sortDirection);

    const count = container.querySelector("[data-result-count]");
    count.textContent =
      filtered.length === rows.length
        ? `${rows.length} ${rows.length === 1 ? "team" : "teams"}`
        : `${filtered.length} of ${rows.length} teams`;

    Tables.render(container.querySelector("[data-table]"), {
      columns: visibleColumns(myUserId, rows),
      rows: sorted,
      sortKey: state.sortKey,
      sortDirection: state.sortDirection,
      rowClass: (row) => (row.userId && row.userId === myUserId ? "is-me" : ""),
      emptyMessage: state.filter
        ? `No team or owner matches “${state.filter}”.`
        : "No standings have been downloaded yet.",
      onSort: (key, preferred) => {
        state.sortDirection = Tables.nextSortDirection(state.sortKey, state.sortDirection, key, preferred);
        state.sortKey = key;
        draw(container);
      },
    });
  }

  async function render(container) {
    App.renderLoading(container, "table");
    rows = await Api.standings();

    container.innerHTML = "";

    const card = document.createElement("section");
    card.className = "card";

    const heading = document.createElement("div");
    heading.className = "section-heading";
    const title = document.createElement("h2");
    title.textContent = "Standings";
    const hint = document.createElement("span");
    hint.className = "hint";
    hint.textContent = "Click a column heading to sort";
    heading.append(title, hint);
    card.appendChild(heading);

    const toolbar = document.createElement("div");
    toolbar.className = "toolbar";

    const search = document.createElement("div");
    search.className = "search";
    const label = document.createElement("label");
    label.className = "visually-hidden";
    label.setAttribute("for", "standings-search");
    label.textContent = "Filter teams";
    const input = document.createElement("input");
    input.id = "standings-search";
    input.type = "search";
    input.placeholder = "Filter by team, owner or username";
    input.value = App.state.standings.filter;
    input.addEventListener("input", () => {
      App.state.standings.filter = input.value;
      draw(container);
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
    draw(container);
  }

  return { render };
})();
