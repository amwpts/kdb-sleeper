/ The JSON API.  Routing is a plain function from (method;path) to a response,
/ so every endpoint can be tested without opening a socket.

/ The configuration the application is running with, replaced by main.q on
/ start-up.  The data directory it writes to is .store.dataDirectory, which
/ .store.init sets.
\d .app
config:`username`season`leagueId`port!("";.cfg.defaultSeason[];"";8080i);
\d .

\d .api

/ ---------------------------------------------------------------------------
/ Small helpers
/ ---------------------------------------------------------------------------

/ 2026.09.10D22:30:00.000000000 -> "2026-09-10T22:30:00Z", which is what the
/ browser can turn into a local time.
isoTime:{[stamp]
  if[null stamp; :""];
  text:string stamp;
  (@[10#text;4 7;:;"-"]),"T",(8#11_text),"Z"
  }

/ "%20" and "+" come back as spaces.  A stray % that is not a valid escape is
/ left alone rather than swallowed.
urlDecode:{[text]
  plain:ssr[text;"+";" "];
  escapes:where "%"=plain;
  escapes:escapes where (escapes+2)<count plain;
  escapes:escapes where all each (plain 1 2+/:escapes) in .Q.n,"abcdefABCDEF";
  if[0=count escapes; :plain];
  decoded:"c"$"X"$plain 1 2+/:escapes;
  / drop the two characters after each % and put the decoded character in place
  removed:raze escapes+/:1 2;
  @[plain;escapes;:;decoded] (til count plain) except removed
  }

/ Which HTTP status best describes a failure that came back as an error string.
statusForError:{[message]
  $[any message like/: ("*unavailable*";"*could not reach*");            502i;
    any message like/: ("*could not find*";"*no Sleeper user*";"*no leagues*"); 404i;
    500i]
  }

queryParameters:{[queryString]
  pairs:"&" vs queryString;
  pairs:pairs where 0<count each pairs;
  if[0=count pairs; :()!()];
  split:{[pair] separator:pair?"="; (`$separator#pair; urlDecode (separator+1)_pair)} each pairs;
  (split[;0])!split[;1]
  }

respond:{[status;payload]
  `status`body!(status;.j.j payload)
  }

ok:respond[200i;]

failure:{[status;message]
  respond[status; (enlist `error)!enlist message]
  }

/ Only whole numbers are accepted where the UI sends a number.
asWeek:{[text]
  parsed:"I"$text;
  if[null parsed; '"\"",text,"\" is not a week number"];
  parsed
  }

/ ---------------------------------------------------------------------------
/ Endpoints
/ ---------------------------------------------------------------------------

/ "ready"  - there is data to show
/ "empty"  - a league is configured but nothing has been downloaded yet
/ "setup"  - nobody has said which Sleeper account to look at
leagueStatus:{[]
  $[0<count .db.league;             "ready";
    .cfg.isConfigured .app.config;  "empty";
    "setup"]
  }

leagueResponse:{[]
  stored:.db.league;
  hasData:0<count stored;
  ok `status`leagueId`name`season`currentWeek`totalRosters`avatar`lastRefreshed`userId`username!(
    leagueStatus[];
    $[hasData; string first stored`leagueId; .app.config`leagueId];
    $[hasData; first stored`name; ""];
    $[hasData; string first stored`season; .app.config`season];
    .view.currentWeek .db.matchups;
    $[hasData; first stored`totalRosters; 0Ni];
    $[hasData; first stored`avatar; ""];
    isoTime .store.lastRefreshed `league;
    string .view.configuredUserId[.db.users; .app.config`username];
    .app.config`username)
  }

standingsResponse:{[]
  ok .view.standings[.db.rosters;.db.users]
  }

teamsResponse:{[]
  ok .view.teams[.db.rosters;.db.users]
  }

rosterResponse:{[path]
  requested:"I"$last "/" vs path;
  if[null requested; :failure[400i;"a roster id is required"]];
  detail:@[{[id] .view.rosterDetail[id;.db.rosters;.db.users;.db.rosterPlayers;.db.players]};
    requested; {[err] (enlist `error)!enlist err}];
  $[`error in key detail; failure[404i;detail`error]; ok detail]
  }

matchupsResponse:{[query]
  weeks:asc distinct .db.matchups`week;
  requested:@[{[query] $[`week in key query; asWeek query`week; .view.currentWeek .db.matchups]};
    query; {[err] (enlist `error)!enlist err}];
  if[99h=type requested; :failure[400i;requested`error]];
  ok `week`weeks`matchups!(
    requested;
    weeks;
    .view.matchupPairs[select from .db.matchups where week=requested; .db.rosters; .db.users])
  }

/ The full Sleeper player list is far too large to send to a browser, so this
/ returns the pool that matters for this league: everyone on an NFL team in a
/ position the league plays, plus anybody already on a roster here.  Sorted by
/ name so the first draw is tidy before anybody clicks a column.
playersResponse:{[]
  scoringFormat:leagueScoringFormat[];
  week:.view.currentWeek .db.matchups;
  pool:.view.playerPool[.db.players;.db.rosterPlayers;.db.rosters;.db.users];
  scored:.view.withStats[pool;.db.playerStats;scoringFormat];
  outlook:.view.withWeekly[scored;.db.playerWeekStats;.db.playerWeekProjections;scoringFormat;week];
  ok `fullName xasc outlook
  }

/ Standard scoring until a league has been downloaded and says otherwise.
leagueScoringFormat:{[]
  $[count .db.league; first .db.league`scoringFormat; `std]
  }

/ More than a handful of players side by side stops being a comparison.
maxComparison:6;

compareResponse:{[query]
  if[not `players in key query; :failure[400i;"name the players to compare"]];
  requested:`$("," vs query`players) except enlist "";
  if[0=count requested; :failure[400i;"name the players to compare"]];
  if[maxComparison<count requested;
    :failure[400i;"only ",string[maxComparison]," players can be compared at once"]];
  scoringFormat:leagueScoringFormat[];
  week:.view.currentWeek .db.matchups;
  stored:.store.fetchMany `players`rosterPlayers`rosters`users`playerStats`playerWeekStats`playerWeekProjections`schedule;
  ok `players`stats!(
    .view.comparison[requested;stored;scoringFormat;week];
    .view.statsSideBySide[.db.playerStatLines;requested])
  }

/ ---------------------------------------------------------------------------
/ Refreshing
/ ---------------------------------------------------------------------------

runRefresh:{[leagueId]
  summary:.refresh.run[leagueId;.store.dataDirectory];
  `status`leagueId`week`refreshed!(
    "ok"; string summary`leagueId; summary`week; isoTime summary`refreshed)
  }

refreshResponse:{[]
  result:@[{[ignored]
      resolved:.refresh.resolveLeague[.app.config;.db.league];
      $[0=count resolved`leagueId;
        `status`choices!("needsLeagueSelection"; resolved`choices);
        runRefresh resolved`leagueId]
      };
    ::;
    {[err] (enlist `error)!enlist err}];
  $[`error in key result; failure[502i;result`error]; ok result]
  }

selectLeagueResponse:{[query]
  if[not `leagueId in key query; :failure[400i;"a leagueId is required"]];
  leagueId:query`leagueId;
  result:@[{[leagueId]
      rememberConfig[.app.config;`leagueId;leagueId];
      runRefresh leagueId
      };
    leagueId; {[err] (enlist `error)!enlist err}];
  $[`error in key result; failure[statusForError result`error;result`error]; ok result]
  }

/ ---------------------------------------------------------------------------
/ Setting up from the browser
/ ---------------------------------------------------------------------------

/ Sleeper usernames are plain text.  Checking here means a typo is explained
/ properly instead of being refused later as an unsafe url.
usernameCharacters:.Q.a,.Q.A,.Q.n,"_-.";

/ Update the running configuration and write it to the configuration file, so
/ that what the browser set up survives a restart.
rememberConfig:{[cfg;name;newValue]
  updated:@[cfg;name;:;newValue];
  .app.config:updated;
  .cfg.writeFile[.cfg.defaultPath;updated];
  updated
  }

setUp:{[query]
  username:$[`username in key query; query`username; ""];
  if[0=count username; '"enter your Sleeper username"];
  if[not all username in usernameCharacters;
    '"\"",username,"\" does not look like a Sleeper username - they contain only letters, numbers, underscores, hyphens and full stops"];

  season:$[`season in key query; query`season; .app.config`season];
  if[0=count season; season:.cfg.defaultSeason[]];

  cfg:.app.config;
  cfg[`username]:username;
  cfg[`season]:season;
  cfg[`leagueId]:"";
  .app.config:cfg;

  profile:.sleeper.user username;
  available:.sleeper.leagues[string profile`userId; season];
  if[0=count available;
    '"no leagues found for ",username," in the ",season," season"];

  / Remember who we are even when the league still has to be chosen.
  .cfg.writeFile[.cfg.defaultPath;cfg];

  if[1<count available;
    :`status`username`choices!("needsLeagueSelection"; username; available)];

  leagueId:string first available`leagueId;
  rememberConfig[cfg;`leagueId;leagueId];
  runRefresh leagueId
  }

setupResponse:{[query]
  result:@[setUp; query; {[err] (enlist `error)!enlist err}];
  if[not `error in key result; :ok result];
  status:statusForError result`error;
  / anything setUp rejected itself is something the person can correct
  failure[$[status=500i; 400i; status]; result`error]
  }

/ ---------------------------------------------------------------------------
/ Routing
/ ---------------------------------------------------------------------------

handle:{[method;path;query]
  $[method~"GET";
    $[path~"/api/league";           leagueResponse[];
      path~"/api/standings";        standingsResponse[];
      path~"/api/rosters";          teamsResponse[];
      path like "/api/roster/*";    rosterResponse path;
      path~"/api/matchups";         matchupsResponse query;
      path~"/api/players";          playersResponse[];
      path~"/api/compare";          compareResponse query;
      failure[404i;"unknown endpoint ",path]];
    method~"POST";
    $[path~"/api/refresh";          refreshResponse[];
      path~"/api/setup";            setupResponse query;
      path~"/api/select-league";    selectLeagueResponse query;
      failure[404i;"unknown endpoint ",path]];
    failure[405i;method," is not supported"]]
  }

route:{[method;path]
  parts:"?" vs path;
  @[{[args] handle . args};
    (method; first parts; queryParameters $[1<count parts; last parts; ""]);
    {[err] failure[500i;err]}]
  }

\d .
