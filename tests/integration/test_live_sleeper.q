/ Live tests against the real Sleeper API.  These are NOT part of the normal
/ unit suite because they need a working internet connection.
/ Run them with:  q tests/integration/test_live_sleeper.q -q
/ An optional league id can be supplied:
/   q tests/integration/test_live_sleeper.q -q -leagueId 1124567890123456789

repoRoot:{[]
  parts:"/" vs $[count .z.f; string .z.f; "tests/integration/test_live_sleeper.q"];
  directory:"/" sv -3_parts;
  $[0=count directory; "."; directory]
  }[];
system "cd ",repoRoot;

system "l tests/harness.q";
.t.fixtureDir:"tests/fixtures/";
{system "l q/",x} each
  ("util.q";"config.q";"schema.q";"venues.q";"transform.q";"views.q";"storage.q";
   "http.q";"sleeper.q";"refresh.q";"api.q";"web.q");

.t.suite "live - the current NFL week";

state:.sleeper.state[];
.t.true["Sleeper reports a week between 1 and 22"; state[`week] within 1i,22i];
.t.eq["Sleeper reports a four digit season"; count state`season; 4];

.t.suite "live - the NFL player list";

players:.sleeper.players[];
.t.true["thousands of players are returned";     1000<count players];
.t.true["every player has an id";                not any null players`playerId];
.t.true["quarterbacks are among them";           0<count select from players where position=`QB];
.t.true["team defences are among them";          0<count select from players where position=`DEF];
.t.true["most players have a full name";         0.9<avg 0<count each players`fullName];

arguments:.Q.opt .z.X;
if[`leagueId in key arguments;
  leagueId:first arguments`leagueId;
  .t.suite "live - a real league";
  league:.sleeper.league leagueId;
  .t.eq["the league is found";              count league; 1];
  users:.sleeper.leagueUsers leagueId;
  .t.true["the league has users";           0<count users];
  rosters:.sleeper.leagueRosters leagueId;
  .t.true["the league has rosters";         0<count rosters];
  .t.eq["every roster count matches the league";
    count rosters; first league`totalRosters];
  standings:.view.standings[rosters;users];
  .t.eq["every roster appears in the standings"; count standings; count rosters];
  ];

exit .t.report[];
