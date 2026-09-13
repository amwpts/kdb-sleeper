.t.suite "comparing players";

dir:"tests/tmp/compare";
.t.resetDir dir;
.store.init dir;
.t.clearDatabase[];
.cfg.defaultPath:dir,"/config.json";
.t.stubSleeper[];
.refresh.run["1124567890123456789";dir];
.app.config:`username`season`leagueId`port!("gridironGuru";"2026";"1124567890123456789";8080i);

answer:.api.route["GET";"/api/compare?players=4034,4046"];
payload:.t.json answer;

.t.eq["comparing two players succeeds"; answer`status; 200i];
.t.eq["both players come back";         count payload`players; 2];
.t.eq["in the order they were asked for";
  payload[`players][;`playerId];
  ("4034";"4046")];

first_:payload[`players][0];
.t.eq["each player is named";        first_`fullName; "Christian McCaffrey"];
.t.eq["with their position";         first_`position; "RB"];
.t.eq["and their NFL team";          first_`team;     "SF"];
.t.eq["and who has them";            first_`rosteredBy; "Gridiron Gurus"];

/ Everything the players page shows comes along.
.t.true["season points come along";     `points in key first_];
.t.true["so does form";                 `lastThree in key first_];
.t.true["and the projections";          `restOfSeasonProjected in key first_];
.t.true["and how they do against them"; `overUnderProjected in key first_];

/ One list per player: every week of the season, with who they play, what they
/ scored and what they were projected, all on the same line.
.t.eq["a line for every week of the season"; count first_`fixtures; 18];
.t.eq["in week order";
  first_[`fixtures][;`week];
  asc first_[`fixtures][;`week]];
.t.true["fixtures say who they play"; `opponent in cols first_`fixtures];
.t.true["and whether they are home";  `home in cols first_`fixtures];
.t.true["and which weeks are byes";   `bye in cols first_`fixtures];
.t.true["and whether the game has been played"; `status in cols first_`fixtures];
.t.true["and what they scored that week";  `points in cols first_`fixtures];
.t.true["and what they were projected";    `projected in cols first_`fixtures];
.t.true["and whether it is played indoors"; `roof in cols first_`fixtures];
.t.false["the game log is no longer separate"; `gameLog in key first_];

/ Every raw stat either player has, lined up side by side.
.t.true["the raw stats are lined up"; 0<count payload`stats];
.t.eq["each stat row has a value for each player";
  count first payload[`stats][;`amounts];
  2];
.t.true["a stat one of them has is included";
  `pass_yd in `$payload[`stats][;`stat]];

.t.suite "comparing - awkward requests";

.t.eq["asking for nobody is refused";
  (.api.route["GET";"/api/compare"])`status;
  400i];
.t.eq["asking for an empty list is refused";
  (.api.route["GET";"/api/compare?players="])`status;
  400i];

unknown:.t.json .api.route["GET";"/api/compare?players=4034,9999999"];
.t.eq["an unknown player still comes back"; count unknown`players; 2];
.t.eq["named by their id";                  unknown[`players][1;`fullName]; "9999999"];
.t.eq["with nothing to show";               unknown[`players][1;`points]; 0n];

.t.eq["asking for more than can be compared is refused";
  (.api.route["GET";"/api/compare?players=1,2,3,4,5,6,7"])`status;
  400i];

.t.restoreTransport[];
.cfg.defaultPath:"tests/tmp/test-config.json";
.t.resetDir dir;
