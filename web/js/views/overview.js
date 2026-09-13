// Overview: a few headline numbers, this week's games and the top of the table.
const OverviewView = (function () {
  function statCard(label, value, detail, accent) {
    const card = document.createElement("div");
    card.className = "stat-card" + (accent ? " stat-accent" : "");

    const labelNode = document.createElement("div");
    labelNode.className = "stat-label";
    labelNode.textContent = label;

    const valueNode = document.createElement("div");
    valueNode.className = "stat-value" + (String(value).length > 9 ? " stat-value-small" : "");
    valueNode.textContent = value;

    card.append(labelNode, valueNode);

    if (detail) {
      const detailNode = document.createElement("div");
      detailNode.className = "stat-detail";
      detailNode.textContent = detail;
      card.appendChild(detailNode);
    }
    return card;
  }

  function highestScoring(standings) {
    return standings.reduce(
      (best, team) => (best === null || team.pointsFor > best.pointsFor ? team : best),
      null
    );
  }

  function miniRow(rank, name, detail, isMe) {
    const row = document.createElement("div");
    row.className = "mini-row";

    if (rank !== "") {
      const rankNode = document.createElement("span");
      rankNode.className = "mini-rank";
      rankNode.textContent = rank;
      row.appendChild(rankNode);
    }

    const nameNode = document.createElement("span");
    nameNode.className = "mini-name";
    nameNode.textContent = name;
    if (isMe) {
      const tag = document.createElement("span");
      tag.className = "you-tag";
      tag.textContent = "YOU";
      nameNode.appendChild(tag);
    }

    const detailNode = document.createElement("span");
    detailNode.className = "mini-detail";
    detailNode.textContent = detail;

    row.append(nameNode, detailNode);
    return row;
  }

  function standingsPanel(standings, myUserId) {
    const panel = document.createElement("section");
    panel.className = "card";

    const heading = document.createElement("div");
    heading.className = "section-heading";
    const title = document.createElement("h2");
    title.textContent = "Top of the table";
    const link = document.createElement("button");
    link.type = "button";
    link.className = "button button-ghost button-small";
    link.textContent = "Full standings";
    link.addEventListener("click", () => App.show("standings"));
    heading.append(title, link);
    panel.appendChild(heading);

    const list = document.createElement("div");
    list.className = "mini-list";
    if (!standings.length) {
      const empty = document.createElement("p");
      empty.className = "empty-state";
      empty.textContent = "No standings yet.";
      list.appendChild(empty);
    } else {
      for (const team of standings.slice(0, 5)) {
        list.appendChild(
          miniRow(
            team.rank,
            team.teamName,
            `${Format.record(team.wins, team.losses, team.ties)}  ·  ${Format.points(team.pointsFor)}`,
            team.userId && team.userId === myUserId
          )
        );
      }
    }
    panel.appendChild(list);
    return panel;
  }

  function matchupsPanel(matchupData) {
    const panel = document.createElement("section");
    panel.className = "card";

    const heading = document.createElement("div");
    heading.className = "section-heading";
    const title = document.createElement("h2");
    title.textContent = `Week ${matchupData.week} matchups`;
    const link = document.createElement("button");
    link.type = "button";
    link.className = "button button-ghost button-small";
    link.textContent = "All matchups";
    link.addEventListener("click", () => App.show("matchups"));
    heading.append(title, link);
    panel.appendChild(heading);

    const list = document.createElement("div");
    list.className = "mini-list";

    if (!matchupData.matchups.length) {
      const empty = document.createElement("p");
      empty.className = "empty-state";
      empty.textContent = "No matchups have been downloaded for this week.";
      list.appendChild(empty);
    } else {
      for (const matchup of matchupData.matchups) {
        const [home, away] = matchup.teams;
        const scoreLine = away
          ? `${Format.points(home.points)} – ${Format.points(away.points)}`
          : Format.points(home.points);
        const names = away ? `${home.teamName} v ${away.teamName}` : `${home.teamName} (bye)`;
        list.appendChild(miniRow("", names, scoreLine, false));
      }
    }

    panel.appendChild(list);
    return panel;
  }

  async function render(container) {
    App.renderLoading(container, "cards");

    const [standings, matchupData] = await Promise.all([Api.standings(), Api.matchups()]);
    const league = App.state.league;

    container.innerHTML = "";

    const stats = document.createElement("div");
    stats.className = "stat-grid";

    const best = standings.length ? standings[0] : null;
    const topScorer = highestScoring(standings);

    stats.appendChild(statCard("Current week", `Week ${league.currentWeek}`, league.season ? `${league.season} season` : "", true));
    stats.appendChild(statCard("League size", `${standings.length}`, standings.length === 1 ? "team" : "teams"));
    stats.appendChild(
      statCard(
        "Highest scoring",
        topScorer ? topScorer.teamName : "—",
        topScorer ? `${Format.points(topScorer.pointsFor)} points for` : ""
      )
    );
    stats.appendChild(
      statCard(
        "Best record",
        best ? best.teamName : "—",
        best ? Format.record(best.wins, best.losses, best.ties) : ""
      )
    );

    container.appendChild(stats);

    const columns = document.createElement("div");
    columns.className = "columns";
    columns.append(matchupsPanel(matchupData), standingsPanel(standings, league.userId));
    container.appendChild(columns);

    const links = document.createElement("div");
    links.className = "quick-links";
    for (const [label, section] of [["Standings", "standings"], ["Rosters", "rosters"], ["Matchups", "matchups"], ["Players", "players"]]) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "button button-ghost";
      button.textContent = `Go to ${label}`;
      button.addEventListener("click", () => App.show(section));
      links.appendChild(button);
    }
    container.appendChild(links);
  }

  return { render, highestScoring };
})();
