.t.suite "api - helpers";

.t.eq["timestamps are sent as ISO 8601";
  .api.isoTime 2026.09.10D22:30:00.000000000;
  "2026-09-10T22:30:00Z"];
.t.eq["a missing timestamp is sent as empty text";
  .api.isoTime 0Np;
  ""];

.t.eq["query strings are split into a dictionary";
  .api.queryParameters "week=3&team=1";
  `week`team!(enlist "3";enlist "1")];
.t.eq["an empty query string gives no parameters";
  count .api.queryParameters "";
  0];

/ ---------------------------------------------------------------------------

.t.suite "api - endpoints";

dir:"tests/tmp/api";
.t.resetDir dir;
.store.init dir;
.t.stubSleeper[];
.refresh.run["1124567890123456789";dir];
.app.config:`username`season`leagueId`port!("gridironGuru";"2026";"1124567890123456789";8080i);
.cfg.defaultPath:dir,"/config.json";

league:.t.json .api.route["GET";"/api/league"];

.t.eq["the league endpoint returns the league name"; league`name;   "Sunday Scaries"];
.t.eq["the league endpoint returns the season";      league`season; "2026"];
.t.eq["the league endpoint returns the current week"; league`currentWeek; 3f];
.t.eq["the league endpoint returns the team count";   league`totalRosters; 4f];
.t.eq["the league endpoint reports when it was refreshed";
  10#league`lastRefreshed; @[10#string .z.D;4 7;:;"-"]];
.t.eq["the league endpoint identifies the configured user";
  league`userId; "300000000000000001"];
.t.eq["the league endpoint reports that it is ready"; league`status; "ready"];

standings:.t.json .api.route["GET";"/api/standings"];
.t.eq["standings are returned in order";        standings[;`rank];     1 2 3 4f];
.t.eq["standings name each team";               standings[0;`teamName]; "Gridiron Gurus"];
.t.eq["standings include points for";           standings[0;`pointsFor]; 342.56];

teams:.t.json .api.route["GET";"/api/rosters"];
.t.eq["every team is listed for the roster picker"; count teams; 4];
.t.eq["teams are listed with their roster id";      teams[0;`rosterId]; 1f];

roster:.t.json .api.route["GET";"/api/roster/1"];
.t.eq["a roster names its team";   roster[`team]`teamName; "Gridiron Gurus"];
.t.eq["a roster lists its players"; count roster`players;  7];
.t.eq["roster players are named";  roster[`players][0;`fullName]; "Patrick Mahomes"];
.t.eq["roster players say whether they start"; roster[`players][0;`starter]; 1b];

matchups:.t.json .api.route["GET";"/api/matchups?week=1"];
.t.eq["matchups are returned for the requested week"; matchups`week;    1f];
.t.eq["matchups are grouped into pairs";              count matchups`matchups; 2];
.t.eq["a matchup card knows who is ahead";
  matchups[`matchups][0;`winnerRosterId]; 1f];
.t.eq["the weeks available are listed for the selector";
  matchups`weeks; 1 2 3f];

.t.eq["asking for no week gives the current week";
  (.t.json .api.route["GET";"/api/matchups"])`week;
  3f];

/ The full Sleeper player list is far too large to send to a browser, so this
/ endpoint returns the players worth showing for this league: everyone on an
/ NFL team in a position the league plays, plus anybody on a roster here.
players:.t.json .api.route["GET";"/api/players"];
.t.eq["the players endpoint returns the league's player pool"; count players; 11];
.t.eq["players say whether they are available";
  count select from players where available;
  4];
.t.eq["rostered players name the team that has them";
  first exec rosteredBy from players where playerId~\:"4034";
  "Gridiron Gurus"];
.t.eq["available players have no owner";
  first exec rosteredBy from players where playerId~\:"1111";
  ""];
.t.eq["the pool is sorted by name so the first draw looks tidy";
  players`fullName;
  asc players`fullName];

/ Season scoring comes with the pool, in the league's own scoring format.
.t.true["players carry their season points"; `points in cols players];
.t.true["players carry games played";        `games in cols players];
.t.true["players carry points per game";     `pointsPerGame in cols players];
.t.eq["the league's half ppr scoring is used";
  first exec points from players where playerId~\:"4034";
  48.7];
.t.eq["games played come through";
  first exec games from players where playerId~\:"4034";
  3f];
.t.eq["a player with no stats has nothing to show";
  first exec points from players where playerId~\:"6794";
  0n];

/ Form and outlook come with the pool too.
.t.true["players carry their last three game average"; `lastThree in cols players];
.t.true["players carry this week's points";            `currentWeekPoints in cols players];
.t.true["players carry this week's projection";        `currentWeekProjected in cols players];
.t.true["players carry next week's projection";        `nextWeekProjected in cols players];
.t.true["players carry the next three week average";   `nextThreeProjected in cols players];
.t.true["players carry the season projection";         `seasonProjected in cols players];
.t.true["players carry the rest of season projection"; `restOfSeasonProjected in cols players];
.t.true["players carry how they do against projection"; `overUnderProjected in cols players];

/ The fixtures give every week the same numbers, so the sums are predictable.
.t.eq["the season projection adds up the weekly projections";
  first exec seasonProjected from players where playerId~\:"4034";
  18*14.2];
.t.eq["the current week projection is this week's";
  first exec currentWeekProjected from players where playerId~\:"4034";
  14.2];

.t.suite "api - errors";

missing:.api.route["GET";"/api/nothing-here"];
.t.eq["an unknown endpoint is a 404"; missing`status; 404i];
.t.eq["an unknown endpoint explains itself";
  (.t.json missing)`error;
  "unknown endpoint /api/nothing-here"];

badRoster:.api.route["GET";"/api/roster/99"];
.t.eq["an unknown roster is a 404";    badRoster`status; 404i];
.t.eq["an unknown roster explains itself"; ((.t.json badRoster)`error) like "*roster 99*"; 1b];

badWeek:.api.route["GET";"/api/matchups?week=banana"];
.t.eq["a week that is not a number is a 400"; badWeek`status; 400i];

.t.true["an error response carries a readable message";
  0<count (.t.json badWeek)`error];

.t.suite "api - refresh";

refreshed:.api.route["POST";"/api/refresh"];
.t.eq["a successful refresh is a 200"; refreshed`status; 200i];
.t.eq["a successful refresh reports the week"; (.t.json refreshed)`week; 3f];

/ A refresh that fails must say so, and must leave the existing data in place.
usersBefore:.db.users;
.t.stubStatus[503i;""];
failed:.api.route["POST";"/api/refresh"];
.t.eq["a failed refresh is a 502"; failed`status; 502i];
.t.eq["a failed refresh explains what happened";
  ((.t.json failed)`error) like "*Sleeper is unavailable*"; 1b];
.t.eq["a failed refresh keeps the existing data"; .db.users; usersBefore];
.t.eq["the standings are still served after a failed refresh";
  count .t.json .api.route["GET";"/api/standings"];
  4];

.t.suite "api - choosing a league";

.t.stubSleeper[];
chosen:.api.route["POST";"/api/select-league?leagueId=1124567890123456789"];
.t.eq["choosing a league is a 200";       chosen`status; 200i];
.t.eq["choosing a league downloads it";   (.t.json chosen)`leagueId; "1124567890123456789"];

.t.eq["choosing no league at all is a 400";
  (.api.route["POST";"/api/select-league"])`status;
  400i];

.t.suite "api - before any data is downloaded";

.t.resetDir dir;
.t.clearDatabase[];
.store.init dir;

emptyLeague:.t.json .api.route["GET";"/api/league"];
.t.eq["an empty database reports that it has no data"; emptyLeague`status; "empty"];
.t.eq["an empty database still reports the season";    emptyLeague`season; "2026"];
.t.eq["an empty database has empty standings";
  count .t.json .api.route["GET";"/api/standings"];
  0];

.t.restoreTransport[];
.cfg.defaultPath:"tests/tmp/test-config.json";
.t.resetDir dir;
