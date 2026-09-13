.t.suite "raw stat lines";

t:.tf.statLines["2026"; .t.fixtureJson "stats_season.json"];
statsFor:{[t;id] exec stat!amount from t where playerId=id}[t;];

/ Sleeper publishes 260 different stats and only a few dozen apply to any one
/ player, so they are stored one row per stat rather than as a wide table.
.t.eq["column names match the schema"; cols t; cols .schema.playerStatLines];
.t.eq["rows fit the schema"; .schema.playerStatLines upsert t; t];
.t.eq["the season is stamped on every row"; distinct t`season; enlist `2026];

mccaffrey:statsFor `4034;
.t.eq["rushing yards are kept";   mccaffrey`rush_yd; 289f];
.t.eq["rushing touchdowns too";   mccaffrey`rush_td; 3f];
.t.eq["and receptions";           mccaffrey`rec;     15f];
.t.eq["and receiving yards";      mccaffrey`rec_yd;  132f];
.t.eq["games played is a stat like any other"; mccaffrey`gp; 3f];

mahomes:statsFor `4046;
.t.eq["passing yards are kept";        mahomes`pass_yd;  812f];
.t.eq["interceptions are kept";        mahomes`pass_int; 2f];
.t.eq["a player only has their own stats"; `rush_yd in key mahomes; 0b];

/ Fantasy points are already stored in their own table, so they are not
/ repeated here.
.t.false["points are not repeated as stat lines"; any `pts_std`pts_half_ppr`pts_ppr in key mccaffrey];

.t.eq["a player with nothing recorded has no lines";
  count select from t where playerId=`7777; 0];
.t.eq["whole team totals are left out";
  count select from t where playerId=`TEAM_SF; 0];

/ A stat that came back as null is not a stat.
.t.eq["null stats are left out"; count select from t where playerId=`1339; 1];

.t.eq["an empty stats response gives no lines"; count .tf.statLines["2026"; .j.k "{}"]; 0];
.t.eq["an empty response keeps the schema";
  cols .tf.statLines["2026"; .j.k "{}"]; cols .schema.playerStatLines];

.t.throws["a stats response that is not an object is rejected";
  {.tf.statLines["2026"; .j.k "[]"]};
  "stats"];

.t.suite "stat lines for a comparison";

/ Only the stats that at least one of the players has, so a comparison does not
/ show forty empty rows.
side:.view.statsSideBySide[t;`4034`4046];

.t.eq["one row per stat either player has"; count side; count distinct exec stat from t where playerId in `4034`4046];
.t.eq["the values line up with the players asked for";
  first exec amounts from side where stat=`rush_yd;
  289 0n];
.t.eq["a stat only one player has is still shown";
  first exec amounts from side where stat=`pass_yd;
  0n 812f];
.t.eq["stats are in a predictable order"; side`stat; asc side`stat];

.t.eq["asking about nobody gives nothing"; count .view.statsSideBySide[t;0#`]; 0];
.t.eq["asking about a player with no stats gives nothing";
  count .view.statsSideBySide[t;enlist `9999];
  0];
