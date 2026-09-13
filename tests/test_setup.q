.t.suite "api - url decoding";

/ The browser encodes what people type, so the query has to be decoded.
.t.eq["plain text is unchanged";        .api.urlDecode "gridironGuru";  "gridironGuru"];
.t.eq["percent escapes are decoded";    .api.urlDecode "a%20b";         "a b"];
.t.eq["a plus sign is a space";         .api.urlDecode "a+b";           "a b"];
.t.eq["an encoded percent survives";    .api.urlDecode "100%25";        "100%"];
.t.eq["lower case escapes are decoded"; .api.urlDecode "%2fx";          "/x"];
.t.eq["a stray percent is left alone";  .api.urlDecode "50% off";       "50% off"];
.t.eq["empty text stays empty";         .api.urlDecode "";              ""];

.t.eq["query values are decoded";
  (.api.queryParameters "username=my%20name&season=2026")`username;
  "my name"];

.t.suite "api - classifying failures";

.t.eq["an outage is a bad gateway";       .api.statusForError "Sleeper is unavailable (HTTP 503)"; 502i];
.t.eq["being offline is a bad gateway";   .api.statusForError "could not reach Sleeper - check your network"; 502i];
.t.eq["an unknown user is a not found";   .api.statusForError "there is no Sleeper user with that username"; 404i];
.t.eq["nothing found is a not found";     .api.statusForError "Sleeper could not find league 123"; 404i];
.t.eq["no leagues is a not found";        .api.statusForError "no leagues found for bob in the 2026 season"; 404i];
.t.eq["anything else is a server error";  .api.statusForError "something went wrong"; 500i];

.t.suite "api - setting up from the browser";

dir:"tests/tmp/setup";
.t.resetDir dir;
.store.init dir;
.t.clearDatabase[];
.cfg.defaultPath:dir,"/config.json";
.app.config:.cfg.empty[];

/ Before anything is set up the league endpoint says so, so the browser knows
/ to show the setup screen rather than a refresh button.
.t.eq["an unconfigured application asks to be set up";
  (.t.json .api.route["GET";"/api/league"])`status;
  "setup"];
.t.eq["an unconfigured application has no username to show";
  (.t.json .api.route["GET";"/api/league"])`username;
  ""];

/ A username that was tried but did not work is offered back to the setup form
/ so it does not have to be typed again.
.app.config[`username]:"halfFinished";
.t.eq["the configured username is reported back";
  (.t.json .api.route["GET";"/api/league"])`username;
  "halfFinished"];
.app.config:.cfg.empty[];

/ A username that belongs to exactly one league is set up in one step.
.t.stubTransport (
  ("*/leagues/nfl/*"; .t.fixture "user_leagues_one.json");
  ("*/user/*";        .t.fixture "user.json");
  ("*/state/nfl";     .t.fixture "state_nfl.json");
  ("*/players/nfl";   .t.fixture "players.json");
  ("*/schedule/nfl/*";                 .t.fixture "schedule.json");
  ("*/projections/nfl/regular/2026/*"; .t.fixture "projections_week.json");
  ("*/stats/nfl/regular/2026/*";       .t.fixture "stats_week.json");
  ("*/stats/nfl/*";   .t.fixture "stats_season.json");
  ("*/users";         .t.fixture "users.json");
  ("*/rosters";       .t.fixture "rosters.json");
  ("*/matchups/*";    .t.fixture "matchups_week1.json");
  ("*/league/*";      .t.fixture "league.json"));

answer:.api.route["POST";"/api/setup?username=gridironGuru"];
payload:.t.json answer;

.t.eq["setting up succeeds";                 answer`status;      200i];
.t.eq["setting up reports the league found"; payload`leagueId;   "1124567890123456789"];
.t.eq["setting up downloads the league";     count .db.rosters;  4];
.t.eq["the league endpoint is ready afterwards";
  (.t.json .api.route["GET";"/api/league"])`status;
  "ready"];

/ The username is written to the configuration file, so a restart remembers it.
stored:.cfg.loadFile .cfg.defaultPath;
.t.eq["the username is saved";  stored`username; "gridironGuru"];
.t.eq["the league is saved";    stored`leagueId; "1124567890123456789"];
.t.eq["the season is saved";    stored`season;   "2026"];
.t.eq["the configuration in memory is updated too"; .app.config`username; "gridironGuru"];

.t.suite "api - setting up with several leagues";

.t.resetDir dir;
.store.init dir;
.t.clearDatabase[];
.app.config:.cfg.empty[];

.t.stubTransport (
  ("*/leagues/nfl/*"; .t.fixture "user_leagues.json");
  ("*/user/*";        .t.fixture "user.json"));

several:.t.json .api.route["POST";"/api/setup?username=gridironGuru"];
.t.eq["several leagues are offered rather than guessed"; several`status;  "needsLeagueSelection"];
.t.eq["every league is offered";                         count several`choices; 2];
.t.eq["the leagues are named";                           several[`choices][0;`name]; "Sunday Scaries"];
.t.eq["nothing is downloaded yet";                       count .db.rosters; 0];
.t.eq["the username is remembered while choosing";
  (.cfg.loadFile .cfg.defaultPath)`username;
  "gridironGuru"];

/ Choosing one of them finishes the job and is remembered.
.t.stubSleeper[];
chosen:.api.route["POST";"/api/select-league?leagueId=1124567890123456789"];
.t.eq["choosing a league succeeds";      chosen`status;     200i];
.t.eq["choosing a league downloads it";  count .db.rosters; 4];
.t.eq["the chosen league is saved";
  (.cfg.loadFile .cfg.defaultPath)`leagueId;
  "1124567890123456789"];

.t.suite "api - setup problems";

.t.eq["setting up with no username at all is refused";
  (.api.route["POST";"/api/setup"])`status;
  400i];
.t.eq["setting up with an empty username is refused";
  (.api.route["POST";"/api/setup?username="])`status;
  400i];

/ Sleeper usernames are plain text; anything else is refused before it is ever
/ put into a url.
odd:.api.route["POST";"/api/setup?username=bob%3Brm%20-rf"];
.t.eq["an impossible username is refused";     odd`status; 400i];
.t.true["an impossible username is explained"; 0<count (.t.json odd)`error];

.t.stubTransport enlist (enlist "*"; "null");
unknown:.api.route["POST";"/api/setup?username=nobodyAtAll"];
.t.eq["an unknown username is a not found";  unknown`status; 404i];
.t.true["an unknown username is explained";
  ((.t.json unknown)`error) like "*no Sleeper user*"];

.t.stubTransport (
  ("*/leagues/nfl/*"; .t.fixture "user_leagues_none.json");
  ("*/user/*";        .t.fixture "user.json"));
noLeagues:.api.route["POST";"/api/setup?username=gridironGuru&season=1999"];
.t.eq["a season with no leagues is a not found"; noLeagues`status; 404i];
.t.true["a season with no leagues is explained";
  ((.t.json noLeagues)`error) like "*no leagues*"];

.t.stubStatus[503i;""];
down:.api.route["POST";"/api/setup?username=gridironGuru"];
.t.eq["Sleeper being down is a bad gateway"; down`status; 502i];

/ A failed setup must not leave a half written configuration behind.
.t.eq["a failed setup does not save a league";
  (.cfg.loadFile .cfg.defaultPath)`leagueId;
  "1124567890123456789"];

.t.restoreTransport[];
.cfg.defaultPath:"tests/tmp/test-config.json";
.t.resetDir dir;
