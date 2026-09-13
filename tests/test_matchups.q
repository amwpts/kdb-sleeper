.t.suite "matchups transform";

leagueId:`1124567890123456789;
t:.tf.matchups[leagueId; 1i; .t.fixtureJson "matchups_week1.json"];

.t.eq["one row per roster";            count t;                   4];
.t.eq["column names match the schema"; cols t;                    cols .schema.matchups];
.t.eq["rows fit the matchups schema";  .schema.matchups upsert t; t];

.t.eq["leagueId is stamped on every row"; distinct t`leagueId;    enlist leagueId];
.t.eq["week is stamped on every row";     distinct t`week;        enlist 1i];
.t.eq["rosterId is an int";               t[0;`rosterId];         1i];
.t.eq["matchupId is an int";              t[0;`matchupId];        1i];
.t.eq["points are floats";                t[0;`points];           118.46];
.t.eq["whole number points stay floats";  t[3;`points];           104f];

/ Commissioners can override a score, and the override is the real score.
.t.eq["custom points take priority over points"; t[2;`points];    110.5];

.t.suite "matchups for an unplayed week";

future:.tf.matchups[leagueId; 5i; .t.fixtureJson "matchups_week5.json"];

.t.eq["an unplayed week still returns a row per roster"; count future; 3];
.t.eq["zero points stay zero";        future[0;`points];    0f];
.t.eq["null points become zero";      future[1;`points];    0f];
.t.eq["a roster on bye has no matchup id"; future[2;`matchupId]; 0Ni];

.t.eq["an empty week gives an empty table"; count .tf.matchups[leagueId;9i;.j.k "[]"]; 0];
.t.eq["an empty week keeps the schema"; cols .tf.matchups[leagueId;9i;.j.k "[]"]; cols .schema.matchups];

.t.throws["a matchups response that is not a list is rejected";
  {.tf.matchups[leagueId; 1i; .j.k "\"nope\""]};
  "matchups"];

.t.suite "NFL state";

state:.tf.state .t.fixtureJson "state_nfl.json";

.t.eq["the current week is an int"; state`week;        3i];
.t.eq["the season is a string";     state`season;      "2026"];
.t.eq["the season type is kept";    state`seasonType;  "regular"];
.t.eq["the display week is an int"; state`displayWeek; 3i];

/ Before the season starts Sleeper reports week 0, which is not a playable week.
preseason:.tf.state .j.k "{\"week\":0,\"season\":\"2026\",\"season_type\":\"pre\",\"display_week\":1}";
.t.eq["a preseason week 0 is reported as week 1"; preseason`week; 1i];

/ If the state call fails we still need a usable week number.
.t.eq["a missing week falls back to week 1"; (.tf.state .j.k "{}")`week; 1i];
