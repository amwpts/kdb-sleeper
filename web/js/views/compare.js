// Players side by side: one column each, one row per thing worth comparing.
const CompareView = (function () {
  const FANTASY_ROWS = [
    { key: "points", label: "Season points" },
    { key: "games", label: "Games played", whole: true },
    { key: "pointsPerGame", label: "Points per game" },
    { key: "lastThree", label: "Last 3 games" },
    { key: "currentWeekPoints", label: "This week" },
    { key: "currentWeekProjected", label: "This week projected" },
    { key: "nextWeekProjected", label: "Next week projected" },
    { key: "nextThreeProjected", label: "Next 3 weeks projected" },
    { key: "seasonProjected", label: "Season projected" },
    { key: "restOfSeasonProjected", label: "Rest of season projected" },
    { key: "overUnderProjected", label: "Above or below projection", signed: true },
  ];

  let comparison = null;

  function headerCell(player, onRemove) {
    const cell = document.createElement("th");
    cell.className = "compare-player";

    const name = document.createElement("div");
    name.className = "compare-name";
    name.textContent = player.fullName;

    const meta = document.createElement("div");
    meta.className = "compare-meta";
    const position = document.createElement("span");
    position.className = Format.positionClass(player.position);
    position.textContent = player.position || "—";
    const team = document.createElement("span");
    team.className = "muted";
    team.textContent = player.team || "FA";
    meta.append(position, team);

    if (player.injuryStatus) {
      const injury = document.createElement("span");
      injury.className = Format.injuryClass(player.injuryStatus);
      injury.textContent = Format.injuryLabel(player.injuryStatus);
      meta.appendChild(injury);
    }

    const owner = document.createElement("div");
    owner.className = "compare-owner";
    if (player.available) {
      const badge = document.createElement("span");
      badge.className = "badge badge-available";
      badge.textContent = "AVAILABLE";
      owner.appendChild(badge);
    } else {
      owner.textContent = player.rosteredBy;
    }

    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "compare-remove";
    remove.title = `Remove ${player.fullName} from the comparison`;
    remove.setAttribute("aria-label", `Remove ${player.fullName}`);
    remove.textContent = "×";
    remove.addEventListener("click", () => onRemove(player.playerId));

    cell.append(remove, name, meta, owner);
    return cell;
  }

  function sectionRow(table, title, columnCount) {
    const row = document.createElement("tr");
    row.className = "compare-section";
    const cell = document.createElement("td");
    cell.colSpan = columnCount;
    cell.textContent = title;
    row.appendChild(cell);
    table.appendChild(row);
  }

  function valueRow(table, label, values, render, higher) {
    const row = document.createElement("tr");
    const heading = document.createElement("th");
    heading.scope = "row";
    heading.textContent = label;
    row.appendChild(heading);

    const winners = Stats.bestIndexes(values, higher);
    values.forEach((value, index) => {
      const cell = document.createElement("td");
      cell.className = "numeric";
      if (winners.includes(index)) cell.classList.add("best");
      cell.textContent = render(value);
      row.appendChild(cell);
    });
    table.appendChild(row);
  }

  function wholeNumber(value) {
    return value === null || value === undefined ? "—" : String(Math.round(value));
  }

  function statNumber(value) {
    if (value === null || value === undefined) return "—";
    return Number.isInteger(value) ? String(value) : Number(value).toFixed(1);
  }

  const ROOF_LABELS = { indoor: "Indoors", retractable: "Retractable roof", outdoor: "Outdoors" };

  // -------------------------------------------------------------------------
  // Who wins a week, and a period
  // -------------------------------------------------------------------------

  // A week that has been played is judged on what was actually scored; one
  // still to come is judged on the projection.  Either way, nothing recorded
  // means nothing scored: a player on a bye really does give you no points.
  function hasBeenPlayed(fixture, currentWeek) {
    return fixture.status === "complete" || fixture.week < currentWeek;
  }

  function weekBasis(fixture, currentWeek) {
    return hasBeenPlayed(fixture, currentWeek) ? "scored" : "projected";
  }

  function weekValue(fixture, currentWeek) {
    const value = hasBeenPlayed(fixture, currentWeek) ? fixture.points : fixture.projected;
    return value === null || value === undefined ? 0 : value;
  }

  // For each week, which of the players had the best number.  A week where
  // everybody is equal has no winner: there is nothing to point out.
  function weekWinners(players, currentWeek) {
    const winners = {};
    if (!players.length) return winners;
    for (const fixture of players[0].fixtures) {
      const values = players.map((player) => {
        const theirs = player.fixtures.find((f) => f.week === fixture.week);
        return theirs ? weekValue(theirs, currentWeek) : 0;
      });
      winners[fixture.week] = Stats.bestIndexes(values, true);
    }
    return winners;
  }

  // What each player is worth over a stretch of weeks, and how many of those
  // weeks they win.
  function periodTotals(players, fromWeek, toWeek, currentWeek) {
    const winners = weekWinners(players, currentWeek);
    return players.map((player, index) => {
      const weeks = player.fixtures.filter((f) => f.week >= fromWeek && f.week <= toWeek);
      const total = weeks.reduce((sum, fixture) => sum + weekValue(fixture, currentWeek), 0);
      const wins = weeks.filter((fixture) => (winners[fixture.week] || []).includes(index)).length;
      return {
        total,
        average: weeks.length ? total / weeks.length : 0,
        wins,
        weeks: weeks.length,
      };
    });
  }

  function bestTotals(totals) {
    return Stats.bestIndexes(totals.map((t) => t.total), true);
  }

  // One line per week: the fixture, the roof over it, what they were projected
  // and what they actually scored.
  function fixtureLine(fixture, currentWeek, isWinner, inPeriod) {
    const line = document.createElement("div");
    line.className = "fixture-line";
    if (fixture.bye) line.classList.add("is-bye");
    if (fixture.week === currentWeek) line.classList.add("is-this-week");
    if (isWinner) line.classList.add("is-week-winner");
    if (!inPeriod) line.classList.add("is-outside-period");

    const week = document.createElement("span");
    week.className = "fixture-week-number";
    week.textContent = `W${fixture.week}`;

    const opponent = document.createElement("span");
    opponent.className = "fixture-opponent";
    if (fixture.bye) {
      opponent.classList.add("fixture-bye");
      opponent.textContent = "BYE";
    } else {
      opponent.textContent = (fixture.home ? "vs " : "@ ") + fixture.opponent;
    }

    const roof = document.createElement("span");
    roof.className = "fixture-roof";
    if (fixture.roof && fixture.roof !== "outdoor") {
      roof.classList.add(`roof-${fixture.roof}`);
      roof.textContent = fixture.roof === "indoor" ? "DOME" : "ROOF";
      roof.title = ROOF_LABELS[fixture.roof];
    }

    const projected = document.createElement("span");
    projected.className = "fixture-projected numeric";
    projected.textContent = Format.score(fixture.projected);
    projected.title = "Projected";

    const scored = document.createElement("span");
    scored.className = "fixture-points numeric";
    scored.textContent = Format.score(fixture.points);
    scored.title = "Scored";

    // Mark the number the week was actually decided on.
    const deciding = weekBasis(fixture, currentWeek) === "scored" ? scored : projected;
    deciding.classList.add("is-deciding");

    line.append(week, opponent, roof, projected, scored);
    return line;
  }

  // The stretch of weeks the totals are worked out over.
  const PRESETS = [
    { label: "Next 3", weeks: 3 },
    { label: "Next 5", weeks: 5 },
    { label: "Rest of season", weeks: null },
    { label: "Whole season", weeks: null, fromStart: true },
  ];

  function seasonWeeks(players) {
    return players.length ? players[0].fixtures.map((f) => f.week) : [];
  }

  function periodControl(container, players, currentWeek) {
    const weeks = seasonWeeks(players);
    const lastWeek = weeks.length ? weeks[weeks.length - 1] : currentWeek;
    const period = App.state.compare;

    const bar = document.createElement("div");
    bar.className = "period-bar";

    const label = document.createElement("span");
    label.className = "period-label";
    label.textContent = "Judge over";

    function weekSelect(id, value, onChange) {
      const wrapper = document.createElement("span");
      const hidden = document.createElement("label");
      hidden.className = "visually-hidden";
      hidden.setAttribute("for", id);
      hidden.textContent = id === "period-from" ? "From week" : "To week";
      const select = document.createElement("select");
      select.id = id;
      for (const week of weeks) {
        const option = document.createElement("option");
        option.value = String(week);
        option.textContent = `Week ${week}`;
        option.selected = week === value;
        select.appendChild(option);
      }
      select.addEventListener("change", () => onChange(Number(select.value)));
      wrapper.append(hidden, select);
      return wrapper;
    }

    bar.append(
      label,
      weekSelect("period-from", period.fromWeek, (week) => {
        period.fromWeek = week;
        if (period.toWeek < week) period.toWeek = week;
        render(container);
      }),
      Object.assign(document.createElement("span"), { className: "period-to", textContent: "to" }),
      weekSelect("period-to", period.toWeek, (week) => {
        period.toWeek = week;
        if (period.fromWeek > week) period.fromWeek = week;
        render(container);
      })
    );

    for (const preset of PRESETS) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "chip-toggle";
      button.textContent = preset.label;
      const from = preset.fromStart ? weeks[0] : currentWeek;
      const to = preset.weeks ? Math.min(currentWeek + preset.weeks - 1, lastWeek) : lastWeek;
      button.setAttribute("aria-pressed", String(period.fromWeek === from && period.toWeek === to));
      button.addEventListener("click", () => {
        period.fromWeek = from;
        period.toWeek = to;
        render(container);
      });
      bar.appendChild(button);
    }

    return bar;
  }

  // One line per player: what they are worth over the chosen weeks.
  function totalsRow(table, players, currentWeek) {
    const period = App.state.compare;
    const totals = periodTotals(players, period.fromWeek, period.toWeek, currentWeek);
    const best = bestTotals(totals);

    const row = document.createElement("tr");
    row.className = "period-totals";
    const heading = document.createElement("th");
    heading.scope = "row";
    heading.textContent = `Weeks ${period.fromWeek}–${period.toWeek}`;
    row.appendChild(heading);

    totals.forEach((totalsForPlayer, index) => {
      const cell = document.createElement("td");
      const total = document.createElement("span");
      total.className = "period-total";
      if (best.includes(index)) total.classList.add("best");
      total.textContent = Format.score(totalsForPlayer.total);

      const detail = document.createElement("span");
      detail.className = "period-detail";
      detail.textContent = ` ${Format.score(totalsForPlayer.average)}/wk · wins ${totalsForPlayer.wins}/${totalsForPlayer.weeks}`;

      cell.append(total, detail);
      row.appendChild(cell);
    });
    table.appendChild(row);
  }

  function fixturesRow(table, players, currentWeek) {
    const winners = weekWinners(players, currentWeek);
    const period = App.state.compare;
    const row = document.createElement("tr");
    const heading = document.createElement("th");
    heading.scope = "row";
    heading.className = "fixture-heading";
    heading.textContent = "Week by week";
    row.appendChild(heading);

    for (const player of players) {
      const cell = document.createElement("td");
      const list = document.createElement("div");
      list.className = "fixture-season";

      const legend = document.createElement("div");
      legend.className = "fixture-line fixture-legend";
      for (const [text, className] of [["", "fixture-week-number"], ["Opponent", "fixture-opponent"],
                                       ["", "fixture-roof"], ["Proj", "fixture-projected numeric"],
                                       ["Scored", "fixture-points numeric"]]) {
        const part = document.createElement("span");
        part.className = className;
        part.textContent = text;
        legend.appendChild(part);
      }
      list.appendChild(legend);

      for (const fixture of player.fixtures) {
        const inPeriod = fixture.week >= period.fromWeek && fixture.week <= period.toWeek;
        const isWinner = (winners[fixture.week] || []).includes(players.indexOf(player));
        list.appendChild(fixtureLine(fixture, currentWeek, isWinner, inPeriod));
      }
      cell.appendChild(list);
      row.appendChild(cell);
    }
    table.appendChild(row);
  }

  function render(container) {
    const players = comparison.players;
    const columnCount = players.length + 1;

    container.innerHTML = "";

    const weeks = seasonWeeks(players);
    const period = App.state.compare;
    if (!weeks.includes(period.fromWeek)) period.fromWeek = App.state.league.currentWeek || weeks[0] || 1;
    if (!weeks.includes(period.toWeek)) period.toWeek = weeks[weeks.length - 1] || period.fromWeek;

    const bar = document.createElement("div");
    bar.className = "compare-bar";
    const back = document.createElement("button");
    back.type = "button";
    back.className = "button button-ghost";
    back.textContent = "← Back to players";
    back.addEventListener("click", () => App.stopComparing());
    const heading = document.createElement("h2");
    heading.textContent = `Comparing ${players.length} players`;
    bar.append(back, heading);
    container.appendChild(bar);
    container.appendChild(periodControl(container, players, App.state.league.currentWeek || 1));

    const card = document.createElement("section");
    card.className = "card";
    const scroller = document.createElement("div");
    scroller.className = "table-scroll";
    const table = document.createElement("table");
    table.className = "data-table compare-table sticky-first";

    const head = document.createElement("thead");
    const headRow = document.createElement("tr");
    const corner = document.createElement("th");
    corner.textContent = "";
    headRow.appendChild(corner);
    for (const player of players) {
      headRow.appendChild(headerCell(player, (id) => App.removeFromComparison(id)));
    }
    head.appendChild(headRow);
    table.appendChild(head);

    const body = document.createElement("tbody");

    sectionRow(body, "Fantasy", columnCount);
    for (const row of FANTASY_ROWS) {
      const values = players.map((player) => player[row.key]);
      const render = row.signed ? Format.signed : row.whole ? wholeNumber : Format.score;
      valueRow(body, row.label, values, render, true);
    }

    const currentWeek = App.state.league.currentWeek || 1;
    sectionRow(body, "Season week by week", columnCount);
    totalsRow(body, players, currentWeek);
    fixturesRow(body, players, currentWeek);

    // Every raw stat either player has, grouped so it can be read.
    const statNames = comparison.stats.map((row) => row.stat);
    for (const section of Stats.sections(statNames)) {
      sectionRow(body, section, columnCount);
      for (const row of comparison.stats) {
        if (Stats.group(row.stat) !== section) continue;
        valueRow(body, Stats.label(row.stat), row.amounts, statNumber, Stats.higherIsBetter(row.stat));
      }
    }

    table.appendChild(body);
    scroller.appendChild(table);
    card.appendChild(scroller);
    container.appendChild(card);
    Tables.fitScrollers();
  }

  async function load(container, playerIds) {
    App.renderLoading(container, "table");
    comparison = await Api.compare(playerIds);
    render(container);
  }

  return { load, weekValue, weekBasis, weekWinners, periodTotals, bestTotals };
})();

if (typeof window === "undefined") globalThis.CompareView = CompareView;
