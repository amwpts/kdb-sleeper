// Tests for the pure browser side logic: sorting, filtering and formatting.
(function (global) {
  const { suite, eq, isTrue, isFalse } = global.TestHarness;
  const { compareValues, sortRows, nextSortDirection, filterRows } = global.Tables;
  const Format = global.Format;

  suite("comparing values");
  eq("numbers compare numerically", compareValues(9, 10), -1);
  eq("numbers do not compare as text", compareValues(100, 20), 1);
  eq("equal numbers compare equal", compareValues(5, 5), 0);
  eq("text compares alphabetically", compareValues("apple", "banana"), -1);
  eq("text comparison ignores case", compareValues("Zebra", "apple"), 1);
  eq("booleans compare like numbers, false first", compareValues(true, false), 1);
  eq("null sorts after a value", compareValues(null, 3), 1);
  eq("a value sorts before null", compareValues(3, null), -1);
  eq("two nulls are equal", compareValues(null, null), 0);
  eq("empty text sorts after text", compareValues("", "abc"), 1);

  suite("sorting rows");
  const teams = [
    { team: "Bravo", wins: 2, points: 101.5 },
    { team: "alpha", wins: 5, points: 98.25 },
    { team: "Charlie", wins: 2, points: 140.0 },
  ];

  eq("ascending sort by text",
    sortRows(teams, "team", "asc").map((row) => row.team),
    ["alpha", "Bravo", "Charlie"]);
  eq("descending sort by text",
    sortRows(teams, "team", "desc").map((row) => row.team),
    ["Charlie", "Bravo", "alpha"]);
  eq("descending sort by number",
    sortRows(teams, "points", "desc").map((row) => row.points),
    [140.0, 101.5, 98.25]);
  eq("sorting does not change the original rows",
    teams.map((row) => row.team),
    ["Bravo", "alpha", "Charlie"]);
  eq("ties keep their original order",
    sortRows(teams, "wins", "asc").map((row) => row.team),
    ["Bravo", "Charlie", "alpha"]);

  // Whichever way a column is sorted, rows with nothing in it belong at the
  // bottom.  Sorting "above or below projection" biggest first should show who
  // is beating it, not a column of dashes.
  const partial = [
    { name: "nothing", value: null },
    { name: "behind", value: -4.5 },
    { name: "ahead", value: 6.25 },
    { name: "blank", value: undefined },
    { name: "level", value: 0 },
  ];
  eq("biggest first puts the best at the top and the missing at the bottom",
    sortRows(partial, "value", "desc").map((row) => row.name),
    ["ahead", "level", "behind", "nothing", "blank"]);
  eq("smallest first puts the worst at the top and the missing still at the bottom",
    sortRows(partial, "value", "asc").map((row) => row.name),
    ["behind", "level", "ahead", "nothing", "blank"]);
  eq("rows with nothing in them keep their original order",
    sortRows(partial, "value", "desc").slice(3).map((row) => row.name),
    ["nothing", "blank"]);
  eq("empty text counts as missing too",
    sortRows([{ n: "b", v: "" }, { n: "a", v: "zebra" }], "v", "desc").map((row) => row.n),
    ["a", "b"]);

  suite("sort direction");
  eq("a new column starts ascending", nextSortDirection("wins", "asc", "team"), "asc");
  eq("clicking the same column reverses it", nextSortDirection("team", "asc", "team"), "desc");
  eq("clicking again puts it back", nextSortDirection("team", "desc", "team"), "asc");

  // Numbers are more useful biggest first: clicking "points" should show the
  // best, and clicking "above or below projection" should show who is beating
  // it, not who is furthest behind.
  eq("a new number column starts with the biggest first",
    nextSortDirection("fullName", "asc", "points", "desc"), "desc");
  eq("a new text column still starts A to Z",
    nextSortDirection("points", "desc", "fullName", "asc"), "asc");
  eq("the same column still reverses, whatever it prefers",
    nextSortDirection("points", "desc", "points", "desc"), "asc");
  eq("and reverses back again",
    nextSortDirection("points", "asc", "points", "desc"), "desc");

  suite("filtering rows");
  const players = [
    { fullName: "Patrick Mahomes", team: "KC", position: "QB" },
    { fullName: "Christian McCaffrey", team: "SF", position: "RB" },
    { fullName: "Taysom Hill", team: "NO", position: "TE" },
  ];
  const fields = ["fullName", "team", "position"];

  eq("an empty filter keeps every row", filterRows(players, "", fields).length, 3);
  eq("filtering by name", filterRows(players, "mahomes", fields).map((p) => p.team), ["KC"]);
  eq("filtering ignores case", filterRows(players, "MCCAFFREY", fields).map((p) => p.team), ["SF"]);
  eq("filtering matches part of a word", filterRows(players, "hill", fields).length, 1);
  eq("filtering matches other fields too", filterRows(players, "qb", fields).length, 1);
  eq("a filter that matches nothing gives no rows", filterRows(players, "zzz", fields).length, 0);
  eq("filtering leaves the original rows alone", players.length, 3);
  eq("surrounding spaces are ignored", filterRows(players, "  kc  ", fields).length, 1);
  eq("a missing field does not break filtering",
    filterRows([{ fullName: null, team: "KC" }], "kc", fields).length, 1);

  suite("formatting");
  eq("points always show two decimals", Format.points(342.5), "342.50");
  eq("zero points are shown as zero", Format.points(0), "0.00");
  eq("missing points are shown as zero", Format.points(null), "0.00");
  eq("a record without ties", Format.record(2, 1, 0), "2-1");
  eq("a record with ties", Format.record(2, 1, 1), "2-1-1");
  eq("a missing record reads as zeros", Format.record(null, null, null), "0-0");

  eq("a position becomes a badge class", Format.positionClass("QB"), "badge badge-qb");
  eq("an unknown position still gets a badge", Format.positionClass(""), "badge badge-none");
  eq("defences get their own badge", Format.positionClass("DEF"), "badge badge-def");

  eq("a healthy player has no injury badge", Format.injuryClass(""), "");
  eq("questionable players are flagged", Format.injuryClass("Questionable"), "badge badge-injury badge-questionable");
  eq("players who are out are flagged", Format.injuryClass("Out"), "badge badge-injury badge-out");
  eq("injured reserve is flagged", Format.injuryClass("IR"), "badge badge-injury badge-out");

  suite("fantasy scores");
  eq("a score is shown to one decimal place", Format.score(48.74, 3), "48.7");
  eq("a whole score still shows a decimal", Format.score(18, 2), "18.0");
  eq("a scoreless player who has played shows zero", Format.score(0, 1), "0.0");
  eq("a player who has not played shows a dash", Format.score(0, 0), "—");
  eq("a score we do not have shows a dash", Format.score(null, 1), "—");
  eq("a score with no games recorded shows a dash", Format.score(12.3), "12.3");

  eq("a positive difference carries a plus", Format.signed(2.34), "+2.3");
  eq("a negative difference carries a minus", Format.signed(-1.75), "-1.8");
  eq("no difference at all is zero", Format.signed(0), "0.0");
  eq("a difference we do not have shows a dash", Format.signed(null), "—");

  suite("relative times");
  const now = new Date("2026-09-10T22:30:00Z");
  eq("a few seconds ago", Format.relativeTime("2026-09-10T22:29:50Z", now), "just now");
  eq("minutes ago", Format.relativeTime("2026-09-10T22:25:00Z", now), "5 minutes ago");
  eq("one minute ago", Format.relativeTime("2026-09-10T22:29:00Z", now), "1 minute ago");
  eq("hours ago", Format.relativeTime("2026-09-10T20:30:00Z", now), "2 hours ago");
  eq("days ago", Format.relativeTime("2026-09-08T22:30:00Z", now), "2 days ago");
  eq("never refreshed", Format.relativeTime("", now), "never");

  suite("roster ordering");
  const roster = [
    { fullName: "Bench Bob", starter: false, slot: null, position: "WR" },
    { fullName: "Starter Sam", starter: true, slot: 1, position: "RB" },
    { fullName: "Starter Ann", starter: true, slot: 0, position: "QB" },
  ];
  eq("starters come before the bench in line-up order",
    sortRows(roster, "starter", "desc").filter((p) => p.starter).length, 2);
  eq("sorting by starter keeps the line-up order within the starters",
    sortRows(roster, "starter", "desc").map((p) => p.fullName),
    ["Starter Sam", "Starter Ann", "Bench Bob"]);

  suite("player availability");
  const pool = [
    { fullName: "Eli Rockwell", available: true, rosteredBy: "" },
    { fullName: "Patrick Mahomes", available: false, rosteredBy: "Gridiron Gurus" },
    { fullName: "Andre Boone", available: true, rosteredBy: "" },
  ];
  const { byAvailability } = global.PlayersView;

  eq("everybody is shown by default", byAvailability(pool, "all").length, 3);
  eq("only free agents when showing available",
    byAvailability(pool, "available").map((p) => p.fullName), ["Eli Rockwell", "Andre Boone"]);
  eq("only owned players when showing rostered",
    byAvailability(pool, "rostered").map((p) => p.fullName), ["Patrick Mahomes"]);
  eq("filtering does not change the original list", pool.length, 3);
  eq("an unknown choice shows everybody", byAvailability(pool, "nonsense").length, 3);

  eq("sorting by availability groups the owned players first",
    sortRows(pool, "available", "asc").map((p) => p.available), [false, true, true]);
  eq("sorting the other way groups the free agents first",
    sortRows(pool, "available", "desc").map((p) => p.available), [true, true, false]);
  eq("players can be found by the manager who has them",
    filterRows(pool, "gridiron", ["fullName", "rosteredBy"]).map((p) => p.fullName),
    ["Patrick Mahomes"]);

  suite("filtering by position");
  const byPositions = global.PlayersView.byPositions;
  const squad = [
    { fullName: "A", position: "QB" },
    { fullName: "B", position: "RB" },
    { fullName: "C", position: "WR" },
    { fullName: "D", position: "RB" },
  ];
  eq("no chosen position shows everybody", byPositions(squad, []).length, 4);
  eq("one position narrows the list", byPositions(squad, ["RB"]).map((p) => p.fullName), ["B", "D"]);
  eq("several positions can be chosen at once",
    byPositions(squad, ["QB", "WR"]).map((p) => p.fullName), ["A", "C"]);
  eq("a position nobody plays shows nobody", byPositions(squad, ["K"]).length, 0);
  eq("filtering by position leaves the original list alone", squad.length, 4);

  suite("naming and grouping stats");
  const Stats = global.Stats;

  eq("a known stat gets a proper name", Stats.label("pass_yd"), "Passing yards");
  eq("and another", Stats.label("rec_tgt"), "Targets");
  eq("an unknown stat is tidied up rather than hidden", Stats.label("some_odd_stat"), "Some odd stat");
  eq("games played reads properly", Stats.label("gp"), "Games played");

  eq("passing stats group together", Stats.group("pass_td"), "Passing");
  eq("rushing stats too", Stats.group("rush_yd"), "Rushing");
  eq("receiving stats too", Stats.group("rec_yd"), "Receiving");
  eq("kicking stats too", Stats.group("fgm_40_49"), "Kicking");
  eq("defensive stats too", Stats.group("sack"), "Defence");
  eq("snap counts are usage", Stats.group("off_snp"), "Usage");
  eq("ranks have their own section", Stats.group("pos_rank_ppr"), "Rankings");
  eq("anything else lands in Other", Stats.group("some_odd_stat"), "Other");

  eq("sections come out in a sensible order",
    Stats.sections(["sack", "pass_yd", "off_snp", "rec_yd"]),
    ["Usage", "Passing", "Receiving", "Defence"]);

  suite("which number is better");
  isTrue("more yards is better", Stats.higherIsBetter("rush_yd"));
  isFalse("throwing interceptions is not", Stats.higherIsBetter("pass_int"));
  isFalse("losing fumbles is not", Stats.higherIsBetter("fum_lost"));
  isFalse("a lower rank is better", Stats.higherIsBetter("rank_ppr"));
  isFalse("missing kicks is not better", Stats.higherIsBetter("fgmiss"));
  isTrue("a defence making interceptions is", Stats.higherIsBetter("int"));

  eq("the best of several is marked", Stats.bestIndexes([10, 25, 18], true), [1]);
  eq("or the lowest when lower is better", Stats.bestIndexes([10, 25, 18], false), [0]);
  eq("a tie marks both", Stats.bestIndexes([25, 25, 18], true), [0, 1]);
  eq("missing values cannot win", Stats.bestIndexes([null, 4, 9], true), [2]);
  eq("a value with nothing to compare against is not marked",
    Stats.bestIndexes([null, 4], true), []);
  eq("nothing is marked when only one player has the stat",
    Stats.bestIndexes([null, 4, null], true), []);
  eq("nothing is marked when nobody has it", Stats.bestIndexes([null, null], true), []);
  eq("nothing is marked when everybody is equal", Stats.bestIndexes([7, 7], true), []);

  suite("who wins a week");
  const Compare = global.CompareView;

  // A week that has been played is judged on what was actually scored; a week
  // still to come is judged on the projection.
  eq("a finished game counts what was scored",
    Compare.weekValue({ week: 1, status: "complete", points: 22.1, projected: 18.4 }, 3), 22.1);
  eq("a week before this one counts what was scored even without a status",
    Compare.weekValue({ week: 1, status: "", points: 9.5, projected: 14 }, 3), 9.5);
  eq("a week still to come counts the projection",
    Compare.weekValue({ week: 5, status: "pre_game", points: null, projected: 17.3 }, 3), 17.3);
  eq("nothing scored in a week that has been played is nothing",
    Compare.weekValue({ week: 1, status: "complete", points: null, projected: 14 }, 3), 0);
  eq("a bye still to come is nothing",
    Compare.weekValue({ week: 5, status: "", points: null, projected: null }, 3), 0);

  eq("the basis is what was scored once the game is done",
    Compare.weekBasis({ week: 1, status: "complete" }, 3), "scored");
  eq("and the projection until then",
    Compare.weekBasis({ week: 5, status: "pre_game" }, 3), "projected");

  const alice = { fullName: "Alice", fixtures: [
    { week: 1, status: "complete", points: 20, projected: 15 },
    { week: 2, status: "pre_game", points: null, projected: 18 },
    { week: 3, status: "pre_game", points: null, projected: null },
  ]};
  const bob = { fullName: "Bob", fixtures: [
    { week: 1, status: "complete", points: 12, projected: 19 },
    { week: 2, status: "pre_game", points: null, projected: 21 },
    { week: 3, status: "pre_game", points: null, projected: 9 },
  ]};

  eq("each week has a winner",
    Compare.weekWinners([alice, bob], 1), { 1: [0], 2: [1], 3: [1] });
  // Two players level at the top are both winners; everybody being level means
  // there is no winner to point out.
  const clone = { fullName: "Clone", fixtures: alice.fixtures };
  eq("players level at the top are both marked",
    Compare.weekWinners([alice, bob, clone], 1)[1], [0, 2]);
  eq("nobody is marked when everybody is level",
    Compare.weekWinners([alice, clone], 1), { 1: [], 2: [], 3: [] });

  suite("totals over a period");
  eq("the whole season adds up",
    Compare.periodTotals([alice, bob], 1, 3, 1).map((t) => t.total), [38, 42]);
  eq("a shorter period only counts those weeks",
    Compare.periodTotals([alice, bob], 2, 3, 1).map((t) => t.total), [18, 30]);
  eq("the average is over the weeks in the period",
    Compare.periodTotals([alice, bob], 2, 3, 1).map((t) => t.average), [9, 15]);
  eq("weeks won are counted too",
    Compare.periodTotals([alice, bob], 1, 3, 1).map((t) => t.wins), [1, 2]);
  eq("a period of one week is fine",
    Compare.periodTotals([alice, bob], 1, 1, 1).map((t) => t.total), [20, 12]);
  eq("the best total is pointed out",
    Compare.bestTotals(Compare.periodTotals([alice, bob], 1, 3, 1)), [1]);

  suite("week navigation");
  eq("the previous week is one lower", Tables.clampWeek(3, [1, 2, 3]) , 3);
  eq("a week below the range is pulled up", Tables.clampWeek(0, [1, 2, 3]), 1);
  eq("a week above the range is pulled down", Tables.clampWeek(9, [1, 2, 3]), 3);
  eq("with no weeks at all the week is one", Tables.clampWeek(4, []), 1);
})(typeof window === "undefined" ? globalThis : window);
