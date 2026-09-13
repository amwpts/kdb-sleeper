.t.suite "weekly stats transform";

weekStats:.tf.weekStats["2026"; 3i; .t.fixtureJson "stats_week.json"];
statFor:{[t;id] first select from t where playerId=id}[weekStats;];

.t.eq["one row per player with something recorded"; count weekStats; 5];
.t.eq["column names match the schema"; cols weekStats; cols .schema.playerWeekStats];
.t.eq["rows fit the schema"; .schema.playerWeekStats upsert weekStats; weekStats];

.t.eq["the season is stamped on every row"; distinct weekStats`season; enlist `2026];
.t.eq["the week is stamped on every row";   distinct weekStats`week;   enlist 3i];
.t.eq["points are read";                    (statFor `4034)`pointsHalf; 15.9];
.t.eq["games played are read";              (statFor `4034)`games;      1i];
.t.eq["a scoreless appearance still counts as a game"; (statFor `5849)`games; 1i];
.t.eq["a scoreless appearance scores nothing";         (statFor `5849)`pointsHalf; 0f];
.t.eq["a player who did not play has no game";         (statFor `1339)`games; 0i];
.t.eq["a recorded appearance is kept even with no points scored";
  count select from weekStats where playerId=`1339; 1];
.t.eq["whole team totals are left out";     count select from weekStats where playerId=`TEAM_SF; 0];
.t.eq["a null entry is skipped";            count select from weekStats where playerId=`7777; 0];

.t.suite "weekly projections transform";

projections:.tf.weekProjections["2026"; 3i; .t.fixtureJson "projections_week.json"];
projectionFor:{[t;id] first select from t where playerId=id}[projections;];

/ Sleeper sends an entry for thousands of players it does not project at all,
/ and a player's bye week comes through the same way: an entry with no points.
/ Neither is a projection, so neither is stored - a missing week means "not
/ projected", which is not the same as a projected zero.
.t.eq["only players that are actually projected are stored"; count projections; 4];
.t.eq["column names match the schema"; cols projections; cols .schema.playerWeekProjections];
.t.eq["rows fit the schema"; .schema.playerWeekProjections upsert projections; projections];
.t.eq["the week is stamped on every row"; distinct projections`week; enlist 3i];
.t.eq["projected points are read"; (projectionFor `4034)`pointsHalf; 14.2];
.t.eq["a player with no projection is left out entirely";
  count select from projections where playerId=`2222; 0];
.t.eq["whole team totals are left out";
  count select from projections where playerId=`TEAM_SF; 0];

.t.eq["an empty week gives an empty table";
  count .tf.weekStats["2026";1i;.j.k "{}"]; 0];
.t.eq["an empty projection week gives an empty table";
  count .tf.weekProjections["2026";1i;.j.k "{}"]; 0];

.t.throws["a weekly response that is not an object is rejected";
  {.tf.weekStats["2026";1i;.j.k "[]"]};
  "stats"];
