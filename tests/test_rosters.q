.t.suite "rosters transform";

leagueId:`1124567890123456789;
t:.tf.rosters[leagueId; .t.fixtureJson "rosters.json"];

.t.eq["every roster is returned";      count t;                  4];
.t.eq["column names match the schema"; cols t;                   cols .schema.rosters];
.t.eq["rows fit the rosters schema";   .schema.rosters upsert t; t];

.t.eq["leagueId is stamped on every row"; distinct t`leagueId;   enlist leagueId];
.t.eq["rosterId is an int";               t[0;`rosterId];        1i];
.t.eq["ownerId is a symbol";              t[0;`ownerId];         `300000000000000001];
.t.eq["wins are read from settings";      t[0;`wins];            2i];
.t.eq["losses are read from settings";    t[0;`losses];          1i];
.t.eq["ties are read from settings";      t[0;`ties];            0i];

/ Sleeper splits points into a whole part and a hundredths part.
.t.eq["pointsFor combines fpts and fpts_decimal";         t[0;`pointsFor];     342.56];
.t.eq["pointsAgainst combines fpts and fpts_decimal";     t[0;`pointsAgainst]; 318.04];

/ A roster with no owner, no ties recorded and no decimal part.
.t.eq["a null owner becomes the null symbol"; t[1;`ownerId];      `];
.t.eq["missing ties count as zero";           t[1;`ties];         0i];
.t.eq["a missing decimal part is treated as zero"; t[1;`pointsFor]; 210f];
.t.eq["decimals below ten are hundredths";    t[1;`pointsAgainst]; 401.9];

/ A brand new roster with an empty settings object.
.t.eq["an empty settings object gives a 0-0-0 record"; t[2;`wins`losses`ties]; 0 0 0i];
.t.eq["an empty settings object gives zero points";    t[2;`pointsFor];        0f];

.t.eq["single digit decimals are hundredths"; t[3;`pointsFor]; 289.05];

.t.eq["an empty roster list still has the schema"; cols .tf.rosters[leagueId; .j.k "[]"]; cols .schema.rosters];

.t.suite "roster/player normalisation";

rp:.tf.rosterPlayers[leagueId; .t.fixtureJson "rosters.json"];

.t.eq["column names match the schema"; cols rp; cols .schema.rosterPlayers];
.t.eq["rows fit the rosterPlayers schema"; .schema.rosterPlayers upsert rp; rp];
.t.eq["leagueId is stamped on every row"; distinct rp`leagueId; enlist leagueId];

one:select from rp where rosterId=1i;
.t.eq["one row per player on the roster"; count one; 7];
.t.eq["players are symbols";              one[0;`playerId]; `4046];

starters:select from one where starter;
.t.eq["empty starting slots are not players"; count starters; 5];
.t.eq["starters are recorded in line-up order"; starters`playerId; `4046`4034`6794`2133`SF];
.t.eq["the slot records the line-up position";  starters`slot;     0 1 2 3 5i];

bench:select from one where not starter, not reserve;
.t.eq["bench players are neither starters nor reserve"; bench`playerId; enlist `5849];
.t.eq["bench players have no slot"; bench[0;`slot]; 0Ni];

reserves:select from one where reserve;
.t.eq["reserve players are flagged"; reserves`playerId; enlist `1339];
.t.eq["reserve players are not starters"; reserves[0;`starter]; 0b];

/ A roster with no players at all.
.t.eq["a roster with null players contributes no rows"; count select from rp where rosterId=3i; 0];

/ A starter that is missing from the players list must still be included.
four:select from rp where rosterId=4i;
.t.eq["starters missing from the players list are still normalised"; count four; 2];
.t.eq["the extra starter is present"; asc four`playerId; `7777`9999];
.t.eq["a player can be both a starter and on reserve";
  exec (starter;reserve) from four where playerId=`7777;
  (enlist 1b;enlist 1b)];

.t.eq["an empty roster list gives an empty relationship table";
  count .tf.rosterPlayers[leagueId; .j.k "[]"];
  0];
