.t.suite "schedule transform";

t:.tf.schedule["2026"; .t.fixtureJson "schedule.json"];
forTeam:{[t;team] `week xasc select from t where team=team}[t;];

/ Every game gives both teams a row, so a team's season reads straight off.
.t.eq["both teams get a row for each game"; count t; 12];
.t.eq["column names match the schema"; cols t; cols .schema.schedule];
.t.eq["rows fit the schema"; .schema.schedule upsert t; t];
.t.eq["the season is stamped on every row"; distinct t`season; enlist `2026];

kc:first select from t where team=`KC, week=1i;
.t.eq["the home team is recorded";      kc`team;     `KC];
.t.eq["so is who they played";          kc`opponent; `SF];
.t.true["and that they were at home";   kc`home];
.t.eq["the date comes through";         kc`gameDate; 2026.09.10];
.t.eq["and whether the game has been played"; kc`status; `complete];
.t.eq["a game still to come says so";
  (first select from t where team=`SF, week=2i)`status;
  `pre_game];

sf:first select from t where team=`SF, week=1i;
.t.eq["the away team gets the mirror row"; sf`opponent; `KC];
.t.false["and is marked as away";          sf`home];

.t.eq["a team's weeks are all there";
  exec week from `week xasc select from t where team=`BUF;
  1 2 3i];
.t.eq["and who they play each week";
  exec opponent from `week xasc select from t where team=`BUF;
  `NO`SF`SF];

/ A game with a team still to be decided is no use to anybody.
.t.eq["a game with no home team is skipped"; count select from t where week=4i; 0];

.t.eq["an empty schedule gives an empty table"; count .tf.schedule["2026"; .j.k "[]"]; 0];
.t.eq["an empty schedule keeps the schema";     cols .tf.schedule["2026"; .j.k "[]"]; cols .schema.schedule];

.t.throws["a schedule that is not a list is rejected";
  {.tf.schedule["2026"; .j.k "\"nope\""]};
  "schedule"];

.t.suite "a team's fixtures";

/ What the comparison screen needs: the weeks ahead, and the byes.
.t.eq["the fixtures for a team are listed in week order";
  exec opponent from .view.fixturesFor[t;`SF;1i;3i];
  `KC`BUF`BUF];
/ SF are away at KC in week 1, at home to BUF in week 2, and away at BUF in
/ week 3.
.t.eq["home and away come through";
  exec home from .view.fixturesFor[t;`SF;1i;3i];
  010b];

/ DAL only plays in weeks 2 and 3, so week 1 is a bye.
byes:.view.fixturesFor[t;`DAL;1i;3i];
.t.eq["a week with no game is still listed"; count byes; 3];
.t.eq["a bye has no opponent";               first exec opponent from byes; `];
.t.true["a bye is marked as such";           first exec bye from byes];
.t.false["a week with a game is not a bye";  last exec bye from byes];

.t.eq["a team nobody has a fixture for is all byes";
  exec bye from .view.fixturesFor[t;`MIA;1i;3i];
  111b];

.t.suite "where the game is played";

/ Sleeper has no stadium or weather data at all, so the roof over each team's
/ home ground is kept as a small reference table of its own.
.t.eq["a dome is indoors";          .venues.roofFor `DET; `indoor];
.t.eq["a retractable roof says so"; .venues.roofFor `DAL; `retractable];
.t.eq["everywhere else is outdoors"; .venues.roofFor `GB;  `outdoor];
.t.eq["a team nobody knows about has no roof"; .venues.roofFor `XXX; `];
.t.eq["every NFL team has a ground"; count .venues.grounds; 32];

.t.suite "a player's season, week by week";

/ One line per week: who they play, where, what they scored and what they were
/ projected.  This is what the comparison screen shows.
gameLog:([] week:1 2 3i; points:11.5 0n 0n; played:1 0N 0Ni; projected:9.0 12.5 0n);
season:.view.seasonFixtures[t;`SF;gameLog;3i];

.t.eq["a line for every week";      count season; 3];
.t.eq["with the opponent";          season`opponent; `KC`BUF`BUF];
.t.eq["and whether they are home";  season`home;     010b];
.t.eq["and what they scored";       season`points;   11.5 0n 0n];
.t.eq["and what they were projected"; season`projected; 9.0 12.5 0n];

/ The roof belongs to whoever is at home.
.t.eq["an away game takes the home team's roof";
  first season`roof;
  .venues.roofFor `KC];
.t.eq["a home game takes their own roof";
  season[1;`roof];
  .venues.roofFor `SF];

/ A bye has no opponent and no roof.
byeSeason:.view.seasonFixtures[t;`DAL;([] week:1 2 3i; points:3#0n; played:3#0Ni; projected:3#0n);3i];
.t.true["a bye is still a line";  first byeSeason`bye];
.t.eq["a bye has no roof";        first byeSeason`roof; `];

