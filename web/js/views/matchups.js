// Matchups: one card per head-to-head game, with week navigation.
const MatchupsView = (function () {
  function sideRow(team, isWinner) {
    const row = document.createElement("div");
    row.className = "matchup-side" + (isWinner ? " is-winning" : "");

    const names = document.createElement("div");
    const name = document.createElement("div");
    name.className = "side-name";
    name.textContent = team.teamName;
    const owner = document.createElement("div");
    owner.className = "side-owner";
    owner.textContent = team.ownerName;
    names.append(name, owner);

    const score = document.createElement("div");
    score.className = "side-score";
    score.textContent = Format.points(team.points);

    row.append(names, score);
    return row;
  }

  function card(matchup) {
    const node = document.createElement("article");
    node.className = "matchup-card";

    const head = document.createElement("div");
    head.className = "matchup-head";
    const title = document.createElement("span");
    title.textContent = matchup.matchupId ? `Matchup ${matchup.matchupId}` : "Bye";
    const status = document.createElement("span");
    status.className = "matchup-status" + (matchup.started ? " is-live" : "");
    status.textContent = matchup.started ? "Scoring" : "Not started";
    head.append(title, status);
    node.appendChild(head);

    const [home, away] = matchup.teams;
    node.appendChild(sideRow(home, matchup.winnerRosterId === home.rosterId));

    if (away) {
      const divider = document.createElement("div");
      divider.className = "matchup-divider";
      divider.textContent = "VS";
      node.appendChild(divider);
      node.appendChild(sideRow(away, matchup.winnerRosterId === away.rosterId));
    } else {
      const bye = document.createElement("p");
      bye.className = "matchup-bye";
      bye.textContent = "No opponent this week.";
      node.appendChild(bye);
    }

    return node;
  }

  function weekControls(container, data) {
    const bar = document.createElement("div");
    bar.className = "toolbar";

    const nav = document.createElement("div");
    nav.className = "week-nav";

    const weeks = data.weeks.length ? data.weeks : [data.week];
    const index = weeks.indexOf(data.week);

    const previous = document.createElement("button");
    previous.type = "button";
    previous.className = "button button-ghost";
    previous.textContent = "← Previous";
    previous.disabled = index <= 0;
    previous.addEventListener("click", () => {
      App.state.week = weeks[index - 1];
      render(container);
    });

    const label = document.createElement("label");
    label.className = "visually-hidden";
    label.setAttribute("for", "week-select");
    label.textContent = "Week";

    const select = document.createElement("select");
    select.id = "week-select";
    for (const week of weeks) {
      const option = document.createElement("option");
      option.value = String(week);
      option.textContent = `Week ${week}`;
      option.selected = week === data.week;
      select.appendChild(option);
    }
    select.addEventListener("change", () => {
      App.state.week = Number(select.value);
      render(container);
    });

    const next = document.createElement("button");
    next.type = "button";
    next.className = "button button-ghost";
    next.textContent = "Next →";
    next.disabled = index < 0 || index >= weeks.length - 1;
    next.addEventListener("click", () => {
      App.state.week = weeks[index + 1];
      render(container);
    });

    nav.append(previous, label, select, next);

    const summary = document.createElement("span");
    summary.className = "result-count";
    summary.textContent = `${data.matchups.length} ${data.matchups.length === 1 ? "matchup" : "matchups"}`;

    bar.append(nav, summary);
    return bar;
  }

  async function render(container) {
    App.renderLoading(container, "cards");

    const data = await Api.matchups(App.state.week);
    App.state.week = data.week;

    container.innerHTML = "";

    const panel = document.createElement("section");
    panel.className = "card";

    const heading = document.createElement("div");
    heading.className = "section-heading";
    const title = document.createElement("h2");
    title.textContent = `Week ${data.week}`;
    const hint = document.createElement("span");
    hint.className = "hint";
    hint.textContent = "Leading team shown in green";
    heading.append(title, hint);
    panel.appendChild(heading);
    panel.appendChild(weekControls(container, data));

    if (!data.matchups.length) {
      const empty = document.createElement("p");
      empty.className = "empty-state";
      empty.textContent = "No matchups have been downloaded for this week.";
      panel.appendChild(empty);
      container.appendChild(panel);
      return;
    }

    container.appendChild(panel);

    const grid = document.createElement("div");
    grid.className = "matchup-grid";
    for (const matchup of data.matchups) {
      grid.appendChild(card(matchup));
    }
    container.appendChild(grid);
  }

  return { render };
})();
