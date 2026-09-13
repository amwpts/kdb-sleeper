.t.suite "http - request safety";

.t.eq["a normal Sleeper url is accepted";
  .http.safeUrl "https://api.sleeper.app/v1/league/1124567890123456789/rosters";
  "https://api.sleeper.app/v1/league/1124567890123456789/rosters"];

/ Usernames come from a config file and end up in a shell command, so anything
/ that is not plain url text has to be refused.
.t.throws["a url containing a quote is refused";
  {.http.safeUrl "https://api.sleeper.app/v1/user/bob'"};
  "unsafe"];
.t.throws["a url containing a semicolon is refused";
  {.http.safeUrl "https://api.sleeper.app/v1/user/bob;rm -rf /"};
  "unsafe"];
.t.throws["a url containing a backtick is refused";
  {.http.safeUrl "https://api.sleeper.app/v1/user/`whoami`"};
  "unsafe"];

.t.suite "http - response handling";

ok:`status`body!(200i;"{\"week\":3}");

.t.eq["a successful response is parsed as JSON"; (.http.json[ok;"state"])`week; 3f];

.t.throws["a 404 says what could not be found";
  {.http.json[`status`body!(404i;"");"user \"nobody\""]};
  "could not find user \"nobody\""];

.t.throws["a server error is reported as unavailable";
  {.http.json[`status`body!(503i;"");"league"]};
  "Sleeper is unavailable"];

.t.throws["an unreachable host is reported clearly";
  {.http.json[`status`body!(0i;"");"league"]};
  "could not reach Sleeper"];

.t.throws["any other status is reported with its code";
  {.http.json[`status`body!(429i;"");"players"]};
  "429"];

.t.throws["a response that is not JSON is reported clearly";
  {.http.json[`status`body!(200i;"<html>down for maintenance</html>");"league"]};
  "malformed"];

.t.suite "sleeper - endpoint urls";

.t.eq["user lookup url";     .sleeper.userUrl "gridironGuru";
  "https://api.sleeper.app/v1/user/gridironGuru"];
.t.eq["user leagues url";    .sleeper.leaguesUrl["300000000000000001";"2026"];
  "https://api.sleeper.app/v1/user/300000000000000001/leagues/nfl/2026"];
.t.eq["league url";          .sleeper.leagueUrl "1124567890123456789";
  "https://api.sleeper.app/v1/league/1124567890123456789"];
.t.eq["league users url";    .sleeper.leagueUsersUrl "1124567890123456789";
  "https://api.sleeper.app/v1/league/1124567890123456789/users"];
.t.eq["league rosters url";  .sleeper.leagueRostersUrl "1124567890123456789";
  "https://api.sleeper.app/v1/league/1124567890123456789/rosters"];
.t.eq["matchups url";        .sleeper.matchupsUrl["1124567890123456789";3i];
  "https://api.sleeper.app/v1/league/1124567890123456789/matchups/3"];
.t.eq["players url";         .sleeper.playersUrl[];
  "https://api.sleeper.app/v1/players/nfl"];
.t.eq["state url";           .sleeper.stateUrl[];
  "https://api.sleeper.app/v1/state/nfl"];
.t.eq["season stats url";    .sleeper.seasonStatsUrl "2026";
  "https://api.sleeper.app/v1/stats/nfl/regular/2026"];
.t.eq["weekly stats url";    .sleeper.weekStatsUrl["2026";3i];
  "https://api.sleeper.app/v1/stats/nfl/regular/2026/3"];
.t.eq["weekly projections url"; .sleeper.weekProjectionsUrl["2026";3i];
  "https://api.sleeper.app/v1/projections/nfl/regular/2026/3"];
/ The schedule is the one endpoint that does not live under /v1.
.t.eq["schedule url";        .sleeper.scheduleUrl "2026";
  "https://api.sleeper.app/schedule/nfl/regular/2026"];

.t.suite "sleeper - fetching with a stubbed transport";

/ .sleeper.transport is the only part of ingestion that touches the network.
/ Replacing it here exercises the whole fetch path without any HTTP.
.t.stubTransport enlist (enlist "*"; .t.fixture "users.json");

fetched:.sleeper.leagueUsers "1124567890123456789";
.t.eq["fetched users are transformed into the users table"; count fetched; 4];
.t.eq["the league id is stamped on fetched users";
  distinct fetched`leagueId; enlist `1124567890123456789];

.t.stubTransport enlist (enlist "*"; .t.fixture "user.json");
profile:.sleeper.user "gridironGuru";
.t.eq["a user profile carries the user id";      profile`userId;      `300000000000000001];
.t.eq["a user profile carries the display name"; profile`displayName; "GridironGuru"];

.t.stubStatus[404i;""];
.t.throws["an unknown username is reported clearly";
  {.sleeper.user "nobodyAtAll"};
  "could not find user \"nobodyAtAll\""];

.t.stubStatus[500i;""];
.t.throws["a Sleeper outage is reported clearly";
  {.sleeper.leagueRosters "1124567890123456789"};
  "Sleeper is unavailable"];

.t.restoreTransport[];

.t.suite "http - platform commands";
.t.eq["Windows uses curl.exe, double quotes and NUL";
  .http.commandFor["https://api.sleeper.app/v1/state/nfl";1b];
  "curl.exe -sS -m 30 -w \"\\n%{http_code}\" \"https://api.sleeper.app/v1/state/nfl\" 2>NUL"];
.t.eq["Unix uses curl and /dev/null";
  .http.commandFor["https://api.sleeper.app/v1/state/nfl";0b];
  "curl -sS -m 30 -w \"\\n%{http_code}\" \"https://api.sleeper.app/v1/state/nfl\" 2>/dev/null"];
.t.throws["Windows refuses cmd environment expansion in URLs";
  {.http.commandFor["https://api.sleeper.app/%PATH%";1b]};
  "percent escapes"];
.t.throws["Windows command refuses embedded double quotes";
  {.http.commandFor["https://api.sleeper.app/\"bad";1b]};
  "unsafe"];
