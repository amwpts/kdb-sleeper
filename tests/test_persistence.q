.t.suite "persistence";

dir:"tests/tmp/db";
.t.resetDir dir;

/ A fresh directory gives us empty tables that match the schema.
.store.init dir;
.t.eq["a fresh database has an empty league table";  count .db.league;     0];
.t.eq["a fresh database has an empty players table"; count .db.players;    0];
.t.eq["a fresh league table matches the schema";     cols .db.league;      cols .schema.league];
.t.eq["a fresh rosterPlayers table matches the schema"; cols .db.rosterPlayers; cols .schema.rosterPlayers];

/ Saving and reloading must give back exactly what was stored.
leagueId:`1124567890123456789;
league:.tf.league .t.fixtureJson "league.json";
users:.tf.users[leagueId; .t.fixtureJson "users.json"];
rosters:.tf.rosters[leagueId; .t.fixtureJson "rosters.json"];
players:.tf.players .t.fixtureJson "players.json";

.store.commit[dir; `league`users`rosters`players!(league;users;rosters;players)];

.t.eq["a commit updates the in-memory tables"; .db.users; users];

/ Simulate a restart: throw the in-memory tables away and load from disk.
.t.clearDatabase[];
.t.eq["the database really was cleared"; count .db.users; 0];

.store.init dir;
.t.eq["league survives a restart";        .db.league;   league];
.t.eq["users survive a restart";          .db.users;    users];
.t.eq["rosters survive a restart";        .db.rosters;  rosters];
.t.eq["players survive a restart";        .db.players;  players];

/ A second commit replaces the previous data rather than appending to it.
.store.commit[dir; (enlist `users)!enlist 2#users];
.t.clearDatabase[];
.store.init dir;
.t.eq["a commit replaces the previous rows"; count .db.users; 2];

.t.suite "persistence - damaged files";

.t.corruptFile dir,"/users";
.t.clearDatabase[];
.store.init dir;
.t.eq["an unreadable table falls back to an empty table"; count .db.users; 0];
.t.eq["an unreadable table keeps its schema";             cols .db.users;  cols .schema.users];
.t.eq["other tables are unaffected by one bad file";      .db.rosters;     rosters];

.t.suite "refresh log";

.t.resetDir dir;
.store.init dir;

.t.true["a dataset that has never been downloaded is stale";
  .store.isStale[`players; 1D00]];
.t.eq["a dataset that has never been downloaded has no timestamp";
  .store.lastRefreshed `players; 0Np];

.store.markRefreshed[`players; 2026.09.10D12:00:00.000000000];
.t.eq["the refresh time is recorded";
  .store.lastRefreshed `players;
  2026.09.10D12:00:00.000000000];

.t.false["a dataset downloaded within the window is fresh";
  .store.isStaleAt[`players; 1D00; 2026.09.10D18:00:00.000000000]];
.t.true["a dataset older than the window is stale";
  .store.isStaleAt[`players; 1D00; 2026.09.12D12:00:00.000000000]];

/ The refresh log is persisted too, so a restart does not re-download players.
.store.commit[dir; ()!()];
.t.clearDatabase[];
.store.init dir;
.t.eq["the refresh log survives a restart";
  .store.lastRefreshed `players;
  2026.09.10D12:00:00.000000000];

.t.resetDir dir;
