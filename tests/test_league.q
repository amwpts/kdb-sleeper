.t.suite "league transform";

t:.tf.league .t.fixtureJson "league.json";

.t.eq["one league row is produced";      count t;              1];
.t.eq["leagueId is a symbol";            t[0;`leagueId];       `1124567890123456789];
.t.eq["name is kept as text";            t[0;`name];           "Sunday Scaries"];
.t.eq["season is a symbol";              t[0;`season];         `2026];
.t.eq["status is a symbol";              t[0;`status];         `in_season];
.t.eq["totalRosters is an int";          t[0;`totalRosters];   4i];
.t.eq["avatar is kept as text";          t[0;`avatar];         "a1b2c3d4e5f6"];
.t.eq["previousLeagueId is a symbol";    t[0;`previousLeagueId]; `998877665544332211];

/ Which set of Sleeper's precomputed fantasy points applies to this league.
.t.eq["half a point per reception is half ppr"; t[0;`scoringFormat]; `half];

.t.eq["the transform matches the league schema";
  cols .schema.league;
  cols t];

/ Upserting into the empty schema table must leave the row untouched, which
/ only happens when every column already has the schema's type.
.t.eq["the row fits the league schema unchanged";
  .schema.league upsert t;
  t];

/ A league object where Sleeper sends nulls for the optional fields.
sparse:.tf.league .t.fixtureJson "league_sparse.json";

.t.eq["null status becomes the null symbol";     sparse[0;`status];           `];
.t.eq["null totalRosters becomes a null int";    sparse[0;`totalRosters];     0Ni];
.t.eq["null avatar becomes empty text";          sparse[0;`avatar];           ""];
.t.eq["null previousLeagueId is the null symbol"; sparse[0;`previousLeagueId]; `];

/ No scoring settings at all means nothing is scored per reception, which is
/ exactly what standard scoring is.
.t.eq["a league with no scoring settings is standard"; sparse[0;`scoringFormat]; `std];

.t.suite "scoring format";

.t.eq["a point per reception is ppr";
  .tf.scoringFormat .j.k "{\"rec\":1.0}"; `ppr];
.t.eq["half a point per reception is half ppr";
  .tf.scoringFormat .j.k "{\"rec\":0.5}"; `half];
.t.eq["no points per reception is standard";
  .tf.scoringFormat .j.k "{\"rec\":0}"; `std];
.t.eq["no reception setting at all is standard";
  .tf.scoringFormat .j.k "{\"pass_td\":4}"; `std];
.t.eq["missing scoring settings are standard";
  .tf.scoringFormat (::); `std];
.t.eq["an unusual reception value counts as ppr when it is closer to one";
  .tf.scoringFormat .j.k "{\"rec\":0.75}"; `ppr];
.t.eq["an unusual reception value counts as half when it is closer to half";
  .tf.scoringFormat .j.k "{\"rec\":0.4}"; `half];
.t.eq["sparse league still fits the schema";
  .schema.league upsert sparse;
  sparse];

.t.throws["a league response that is not an object is rejected";
  {.tf.league .j.k "[]"};
  "league"];

.t.suite "league selection list";

leagues:.tf.leagueList .t.fixtureJson "user_leagues.json";

.t.eq["every league in the list is returned"; count leagues; 2];
.t.eq["league ids are symbols";  leagues`leagueId; `1124567890123456789`3300000000000000009];
.t.eq["league names are text";   leagues[0;`name]; "Sunday Scaries"];
.t.eq["league list carries the season"; leagues[1;`season]; `2026];
.t.eq["league list carries the roster count"; leagues[1;`totalRosters]; 10i];
