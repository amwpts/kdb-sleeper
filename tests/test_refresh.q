.t.suite "league resolution";

leagueId:"1124567890123456789";
configured:`username`season`leagueId`port!("gridironGuru";"2026";leagueId;8080i);
unconfigured:`username`season`leagueId`port!("gridironGuru";"2026";"";8080i);

.t.stubSleeper[];

.t.eq["a configured league id is used as it is";
  (.refresh.resolveLeague[configured; .schema.league])`leagueId;
  leagueId];
.t.false["a configured league id needs no lookup"; .t.asked "*/user/*"];

/ With no league configured, the league is looked up from the username.
.t.stubTransport (
  ("*/leagues/nfl/*"; .t.fixture "user_leagues_one.json");
  ("*/user/*";        .t.fixture "user.json"));

single:.refresh.resolveLeague[unconfigured; .schema.league];
.t.eq["a single league is chosen automatically"; single`leagueId; leagueId];
.t.eq["a single league needs no choice from the user"; count single`choices; 0];

/ More than one league means the user has to pick.
.t.stubTransport (
  ("*/leagues/nfl/*"; .t.fixture "user_leagues.json");
  ("*/user/*";        .t.fixture "user.json"));

several:.refresh.resolveLeague[unconfigured; .schema.league];
.t.eq["several leagues are offered as a choice"; count several`choices;  2];
.t.eq["no league is chosen for the user";        several`leagueId;       ""];
.t.eq["the choices carry league names";          several[`choices][0;`name]; "Sunday Scaries"];

/ A league that has already been downloaded is remembered across restarts.
stored:.tf.league .t.fixtureJson "league.json";
.t.clearRequests[];
.t.eq["a previously downloaded league is reused";
  (.refresh.resolveLeague[unconfigured; stored])`leagueId;
  leagueId];
.t.false["a remembered league needs no lookup"; .t.asked "*/leagues/nfl/*"];

.t.stubTransport (
  ("*/leagues/nfl/*"; .t.fixture "user_leagues_none.json");
  ("*/user/*";        .t.fixture "user.json"));
.t.throws["a user with no leagues is told so";
  {.refresh.resolveLeague[unconfigured; .schema.league]};
  "no leagues"];

.t.suite "refresh";

dir:"tests/tmp/refresh";
.t.resetDir dir;
.store.init dir;
.t.stubSleeper[];

summary:.refresh.run[leagueId;dir];

.t.eq["the league is stored";            count .db.league;         1];
.t.eq["users are stored";                count .db.users;          4];
.t.eq["rosters are stored";              count .db.rosters;        4];
.t.eq["roster players are stored";       count .db.rosterPlayers;  11];
.t.eq["players are stored";              count .db.players;        14];
.t.eq["season stats are stored";         count .db.playerStats;    8];
.t.eq["the schedule is stored";          count .db.schedule;       12];
.t.true["raw stat lines are stored";     0<count .db.playerStatLines];
/ The stat lines come out of the season stats that were already downloaded,
/ so they cost nothing extra.
.t.eq["stat lines cover the same players as the season stats";
  asc distinct .db.playerStatLines`playerId;
  asc distinct .db.playerStats`playerId];
.t.eq["matchups are stored for every week so far"; count .db.matchups; 12];
.t.eq["matchups cover weeks one to the current week";
  asc distinct .db.matchups`week; 1 2 3i];

.t.eq["the summary reports the league";  summary`leagueId;         `1124567890123456789];
.t.eq["the summary reports the week";    summary`week;             3i];
.t.true["the refresh time is recorded";  not null .store.lastRefreshed `league];
.t.true["the player download time is recorded"; not null .store.lastRefreshed `players];

/ Stats change every week and the download is small, so unlike the player
/ reference data they come down on every refresh.
.t.true["stats are downloaded on every refresh"; .t.asked "*/stats/nfl/*"];

/ Everything reaches disk, so a restart keeps it.
.t.clearDatabase[];
.store.init dir;
.t.eq["the refreshed data survives a restart"; count .db.rosterPlayers; 11];

.t.suite "refresh - the player cache";

.t.stubSleeper[];
.refresh.run[leagueId;dir];
.t.false["players are not downloaded again while the cache is fresh";
  .t.asked "*/players/nfl*"];
.t.true["stats are downloaded again even when the player cache is fresh";
  .t.asked "*/stats/nfl/*"];
.t.eq["the stored players are still there"; count .db.players; 14];

.store.markRefreshed[`players; .z.p-2D00];
.t.stubSleeper[];
.refresh.run[leagueId;dir];
.t.true["players are downloaded again once the cache is a day old";
  .t.asked "*/players/nfl*"];

.t.suite "refresh - failure keeps existing data";

usersBefore:.db.users;
rostersBefore:.db.rosters;

.t.stubStatus[503i;""];
.t.throws["a failed refresh explains what went wrong";
  {.refresh.run[leagueId;dir]};
  "Sleeper is unavailable"];

.t.eq["users are left exactly as they were";   .db.users;   usersBefore];
.t.eq["rosters are left exactly as they were"; .db.rosters; rostersBefore];

.t.clearDatabase[];
.store.init dir;
.t.eq["the data on disk was not damaged either"; .db.users; usersBefore];

/ A refresh that fails part way through must not leave a half updated database.
.t.stubTransport (
  ("*/state/nfl";   .t.fixture "state_nfl.json");
  ("*/users";       .t.fixture "users.json");
  ("*/league/*";    "{\"this\": \"is not a league\"");
  ("*/players/nfl"; .t.fixture "players.json"));
.t.throws["a malformed response is reported";
  {.refresh.run[leagueId;dir]};
  "malformed"];
.t.eq["a part finished refresh changes nothing"; .db.users; usersBefore];

.t.restoreTransport[];
.t.resetDir dir;

.t.suite "refresh - weekly stats and projections";

dir2:"tests/tmp/weekly";
.t.resetDir dir2;
.store.init dir2;
.t.clearDatabase[];
.t.stubSleeper[];

/ The fixture state is week 3 of an 18 week season.
summary2:.refresh.run[leagueId;dir2];

.t.true["weekly stats are downloaded for the weeks played so far";
  all .t.asked each ("*/stats/nfl/regular/2026/1";"*/stats/nfl/regular/2026/2";"*/stats/nfl/regular/2026/3")];
.t.false["weeks that have not happened yet are not asked for";
  .t.asked "*/stats/nfl/regular/2026/4"];
.t.eq["a row per player per week is stored";
  asc distinct .db.playerWeekStats`week;
  1 2 3i];

.t.true["projections are downloaded for the whole season";
  all .t.asked each ("*/projections/nfl/regular/2026/1";"*/projections/nfl/regular/2026/18")];
.t.eq["projections are stored for every week";
  count distinct .db.playerWeekProjections`week;
  18];

/ Past weeks never change, so a second refresh must not ask for them again.
.t.stubSleeper[];
.refresh.run[leagueId;dir2];

.t.false["finished weeks are not downloaded again"; .t.asked "*/stats/nfl/regular/2026/1"];
.t.true["the week in progress is downloaded again";  .t.asked "*/stats/nfl/regular/2026/3"];
.t.false["projections for finished weeks are not downloaded again";
  .t.asked "*/projections/nfl/regular/2026/1"];
.t.true["projections from this week on are downloaded again";
  all .t.asked each ("*/projections/nfl/regular/2026/3";"*/projections/nfl/regular/2026/18")];

.t.eq["nothing is lost by refreshing again";
  asc distinct .db.playerWeekStats`week;
  1 2 3i];
.t.eq["and the projections are all still there";
  count distinct .db.playerWeekProjections`week;
  18];

/ A restart keeps the weekly history.
.t.clearDatabase[];
.store.init dir2;
.t.eq["weekly stats survive a restart";       count distinct .db.playerWeekStats`week; 3];
.t.eq["weekly projections survive a restart"; count distinct .db.playerWeekProjections`week; 18];

.t.resetDir dir2;
