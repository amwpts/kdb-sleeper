.t.suite "season stats transform";

t:.tf.playerStats["2026"; .t.fixtureJson "stats_season.json"];
byId:{[stats;id] first select from stats where playerId=id}[t;];

/ Sleeper sends an entry for every player it has anything at all for, but a
/ null entry carries nothing.
.t.eq["one row per player with something recorded"; count t; 8];
.t.eq["column names match the schema"; cols t; cols .schema.playerStats];
.t.eq["rows fit the stats schema";     .schema.playerStats upsert t; t];

.t.eq["the season is stamped on every row"; distinct t`season; enlist `2026];
.t.eq["playerId is a symbol";               (byId `4034)`playerId; `4034];
.t.eq["games played is an int";             (byId `4034)`games;    3i];

/ All three of Sleeper's scoring formats are kept, so the league's own format
/ can be chosen when the numbers are shown.
.t.eq["standard points are kept";  (byId `4034)`pointsStd;  41.2];
.t.eq["half ppr points are kept";  (byId `4034)`pointsHalf; 48.7];
.t.eq["full ppr points are kept";  (byId `4034)`pointsPpr;  56.2];

.t.eq["whole number points are floats"; (byId `1111)`pointsPpr; 18f];

/ A player who has not played yet still has a row, with nothing scored.
.t.eq["a player who has not played has no games";  (byId `2222)`games;     0i];
.t.eq["a player who has not played has no points"; (byId `2222)`pointsPpr; 0f];

/ Sleeper sometimes sends the points fields as null rather than leaving them out.
.t.eq["null points count as none";  (byId `1339)`pointsHalf; 0f];
.t.eq["the games still count";      (byId `1339)`games;      2i];

.t.eq["a null entry is skipped"; count select from t where playerId=`7777; 0];

/ Sleeper also publishes whole team offensive totals under TEAM_XX ids.  They
/ are not players - a team's 86.6 points is everybody's scoring added up - so
/ they have no place in a table of players.
.t.eq["whole team totals are not players"; count select from t where playerId=`TEAM_SF; 0];
.t.eq["a team defence is still a player";  (byId `DAL)`games; 3i];

/ Defences score too.
.t.eq["a defence has stats"; (byId `DAL)`pointsStd; 22f];

.t.eq["an empty stats response gives an empty table";
  count .tf.playerStats["2026"; .j.k "{}"]; 0];
.t.eq["an empty stats response keeps the schema";
  cols .tf.playerStats["2026"; .j.k "{}"]; cols .schema.playerStats];

.t.throws["a stats response that is not an object is rejected";
  {.tf.playerStats["2026"; .j.k "[]"]};
  "stats"];

.t.suite "stats on the player pool";

leagueId:`1124567890123456789;
users:.tf.users[leagueId; .t.fixtureJson "users.json"];
rosters:.tf.rosters[leagueId; .t.fixtureJson "rosters.json"];
rosterPlayers:.tf.rosterPlayers[leagueId; .t.fixtureJson "rosters.json"];
players:.tf.players .t.fixtureJson "players.json";
pool:.view.playerPool[players;rosterPlayers;rosters;users];

withStats:.view.withStats[pool;t;`half];
scored:{[pool;id] first select from pool where playerId=id}[withStats;];

.t.eq["every player keeps their row"; count withStats; count pool];
.t.eq["the stats columns are added";
  cols withStats;
  (cols pool),`points`games`pointsPerGame];

.t.eq["a half ppr league sees half ppr points"; (scored `4034)`points; 48.7];
.t.eq["games played come through";              (scored `4034)`games;  3i];
.t.eq["points per game is worked out";          (scored `4034)`pointsPerGame; 48.7%3];

/ A player who has not played has no scoring to show.  That is not the same as
/ having scored zero, and the difference matters when the column is sorted:
/ "nothing to say" belongs at the bottom either way round.
.t.eq["a player with no stats has no points"; (scored `6794)`points;        0n];
.t.eq["a player with no stats has played no games"; (scored `6794)`games;   0i];
.t.eq["a player with no stats has no average"; (scored `6794)`pointsPerGame; 0n];

/ Nobody is divided by zero.
.t.eq["a player who has not played has no average"; (scored `2222)`pointsPerGame; 0n];

/ Someone who played and scored nothing really did score nothing.
.t.eq["a scoreless game is a real zero, not a blank";
  (first select from .view.withStats[pool;t;`std] where playerId=`1339)`points;
  0f];
.t.eq["and it counts as a game";
  (scored `1339)`games;
  2i];

/ The league's format decides which column is shown.
.t.eq["a ppr league sees ppr points";
  (first select from .view.withStats[pool;t;`ppr] where playerId=`4034)`points;
  56.2];
.t.eq["a standard league sees standard points";
  (first select from .view.withStats[pool;t;`std] where playerId=`4034)`points;
  41.2];
.t.eq["an unknown format falls back to standard";
  (first select from .view.withStats[pool;t;`] where playerId=`4034)`points;
  41.2];

.t.eq["stats for players outside the pool are ignored";
  count select from withStats where playerId=`8888888;
  0];

.t.eq["a pool with no stats at all still has the columns";
  cols .view.withStats[pool;.schema.playerStats;`half];
  cols withStats];
.t.eq["a pool with no stats has nothing to show";
  distinct exec points from .view.withStats[pool;.schema.playerStats;`half];
  enlist 0n];
