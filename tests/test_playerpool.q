.t.suite "player pool";

leagueId:`1124567890123456789;
users:.tf.users[leagueId; .t.fixtureJson "users.json"];
rosters:.tf.rosters[leagueId; .t.fixtureJson "rosters.json"];
rosterPlayers:.tf.rosterPlayers[leagueId; .t.fixtureJson "rosters.json"];
players:.tf.players .t.fixtureJson "players.json";

pool:.view.playerPool[players;rosterPlayers;rosters;users];
inPool:{[pool;id] first select from pool where playerId=id}[pool;];

/ The pool is everybody on an NFL team in a position this league plays, plus
/ anybody actually on a roster here.
.t.eq["the pool has one row per interesting player"; count pool; 11];
.t.eq["nobody appears twice"; count distinct pool`playerId; 11];

/ Who is left out.
.t.eq["a player in a position nobody plays is left out";
  count select from pool where playerId=`3333; 0];
.t.eq["a player with no NFL team who nobody rosters is left out";
  count select from pool where playerId=`4444; 0];
.t.eq["a player with no position at all is left out";
  count select from pool where playerId=`$enlist "0"; 0];

/ Availability.
.t.false["a rostered player is not available"; (inPool `4034)`available];
.t.eq["a rostered player shows who has them"; (inPool `4034)`rosteredBy; "Gridiron Gurus"];
.t.true["a player nobody has rostered is available"; (inPool `1111)`available];
.t.eq["an available player has no owner"; (inPool `1111)`rosteredBy; ""];

.t.eq["available players are the ones nobody owns";
  asc exec playerId from pool where available;
  asc `1111`2222`6666`DAL];
.t.eq["the rest are owned";
  count select from pool where not available;
  7];

/ A player who has been dropped from the NFL but is still on a roster here has
/ to stay visible, otherwise their manager cannot see them.
.t.true["a rostered player with no NFL team is still listed";
  1=count select from pool where playerId=`6794];
.t.false["a rostered player with no NFL team is not available";
  (inPool `6794)`available];

/ Leagues that use defensive players roster positions the standard list does
/ not have, so those positions become interesting for the whole pool.
.t.eq["a rostered defensive player is listed"; (inPool `5555)`position; `LB];
.t.true["free agents in a position the league rosters are listed too";
  1=count select from pool where playerId=`6666];
.t.true["that free agent is available"; (inPool `6666)`available];

/ Reference details come along for the ride.
.t.eq["players keep their name";     (inPool `2222)`fullName;     "Andre Boone"];
.t.eq["players keep their NFL team"; (inPool `2222)`team;         `DAL];
.t.eq["players keep their position"; (inPool `2222)`position;     `RB];
.t.eq["players keep their injury";   (inPool `2222)`injuryStatus; `Questionable];
.t.eq["players keep their age";      (inPool `2222)`age;          26i];

.t.eq["the pool has the columns the browser needs";
  cols pool;
  `playerId`fullName`team`position`available`rosteredBy`status`injuryStatus`age];

/ Team defences are players too.
.t.eq["a defence is in the pool with its team name"; (inPool `DAL)`fullName; "Dallas Cowboys"];
.t.eq["a defence keeps the DEF position";            (inPool `DAL)`position; `DEF];

.t.suite "player pool - empty cases";

.t.eq["with no players at all the pool is empty";
  count .view.playerPool[.schema.players;rosterPlayers;rosters;users];
  0];
.t.eq["an empty pool still has its columns";
  cols .view.playerPool[.schema.players;rosterPlayers;rosters;users];
  cols pool];
.t.eq["with no rosters everybody on an NFL team is available";
  count select from .view.playerPool[players;.schema.rosterPlayers;.schema.rosters;users] where not available;
  0];
/ Without any rosters the pool is exactly the fixture players who are on an
/ NFL team in a standard fantasy position: 4034, 4046, SF, 1339, 5849, 1111,
/ 2222 and DAL.  The defensive players are not included, because no league
/ roster asks for them.
.t.eq["with no rosters the pool is the standard fantasy positions";
  count .view.playerPool[players;.schema.rosterPlayers;.schema.rosters;users];
  8];
.t.eq["and defensive players are not among them";
  count select from .view.playerPool[players;.schema.rosterPlayers;.schema.rosters;users] where position=`LB;
  0];
