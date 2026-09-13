.t.suite "weekly view - a player's form and outlook";

/ Four weeks played, current week is 4, season runs to week 6 in this example.
/ Player A played every week; B missed week 2; C has never played.
actuals:.schema.playerWeekStats upsert
  ([] playerId:`A`A`A`A`B`B`B;
      season:7#`2026;
      week:   1  2  3  4  1  3  4i;
      games:  1  1  1  1  1  1  1i;
      pointsStd:  7#0f;
      pointsHalf: 10 20 30 40 5 15 25f;
      pointsPpr:  7#0f);

projections:.schema.playerWeekProjections upsert
  ([] playerId:`A`A`A`A`A`A`B`B`B`B`B`B`C;
      season:13#`2026;
      week:   1  2  3  4  5  6  1  2  3  4  5  6  4i;
      pointsStd:  13#0f;
      pointsHalf: 12 18 26 35 33 31 6 7 12 20 22 24 9f;
      pointsPpr:  13#0f);

pool:([] playerId:`A`B`C; fullName:("Player A";"Player B";"Player C"));
scored:.view.withWeekly[pool;actuals;projections;`half;4i];
row:{[t;id] first select from t where playerId=id}[scored;];

.t.eq["every player keeps their row"; count scored; 3];
.t.eq["the weekly columns are added";
  cols scored;
  (cols pool),`lastThree`currentWeekPoints`currentWeekProjected`nextWeekProjected`nextThreeProjected`seasonProjected`restOfSeasonProjected`overUnderProjected];

/ Form: the last three games the player actually played.
.t.eq["the last three games are averaged"; (row `A)`lastThree; avg 20 30 40f];
.t.eq["weeks the player missed are skipped"; (row `B)`lastThree; avg 5 15 25f];
.t.eq["a player who has never played has no average"; (row `C)`lastThree; 0n];

/ This week.
.t.eq["current week points are this week's actual score"; (row `A)`currentWeekPoints; 40f];
.t.eq["a player with no line this week has none";         (row `C)`currentWeekPoints; 0n];

/ Projections.
.t.eq["the current week projection is shown"; (row `A)`currentWeekProjected; 35f];
.t.eq["next week's projection is shown";      (row `A)`nextWeekProjected;    33f];
.t.eq["a player with no projection next week has none"; (row `C)`nextWeekProjected; 0n];

/ Next three weeks means this week and the two after it.  A week with no
/ projection is a bye: the player really does score nothing, so it counts as a
/ zero rather than being left out of the average.
.t.eq["the next three weeks are averaged"; (row `A)`nextThreeProjected; avg 35 33 31f];
.t.eq["a bye in the window counts as nothing scored";
  (row `C)`nextThreeProjected; (9+0+0)%3];

/ Season and rest of season come from the same weekly numbers, so they agree.
.t.eq["the season projection adds up every week";
  (row `A)`seasonProjected; sum 12 18 26 35 33 31f];
.t.eq["the rest of season projection adds up from this week on";
  (row `A)`restOfSeasonProjected; sum 35 33 31f];
.t.eq["rest of season is never more than the season"; 
  ((row `A)`restOfSeasonProjected) <= (row `A)`seasonProjected; 1b];

/ Over and under, across the weeks actually played.
.t.eq["over and under is averaged over the games played";
  (row `A)`overUnderProjected;
  avg (10-12; 20-18; 30-26; 40-35f)];
.t.eq["weeks the player missed are not counted";
  (row `B)`overUnderProjected;
  avg (5-6; 15-12; 25-20f)];
.t.eq["a player who has never played has no over or under";
  (row `C)`overUnderProjected; 0n];

.t.suite "weekly view - scoring formats and empty cases";

ppr:.view.withWeekly[pool;actuals;projections;`ppr;4i];
.t.eq["a ppr league reads the ppr columns";
  (first select from ppr where playerId=`A)`currentWeekPoints;
  0f];

.t.eq["with no weekly data at all every column is empty";
  distinct (.view.withWeekly[pool;.schema.playerWeekStats;.schema.playerWeekProjections;`half;4i])`lastThree;
  enlist 0n];
.t.eq["with no weekly data the columns are still there";
  cols .view.withWeekly[pool;.schema.playerWeekStats;.schema.playerWeekProjections;`half;4i];
  cols scored];
.t.eq["an empty pool stays empty but keeps its columns";
  cols .view.withWeekly[0#pool;actuals;projections;`half;4i];
  cols scored];

.t.suite "weekly view - the end of the season";

/ Weeks 17 and 18 are the last two, so "the next three weeks" at week 17 can
/ only be two weeks, and the average is over those two rather than three.
lateProjections:.schema.playerWeekProjections upsert
  ([] playerId:`A`A`A;
      season:3#`2026;
      week:   16 17 18i;
      pointsStd:  3#0f;
      pointsHalf: 10 20 30f;
      pointsPpr:  3#0f);

late:.view.withWeekly[([] playerId:enlist `A); .schema.playerWeekStats; lateProjections; `half; 17i];

.t.eq["the window stops at the end of the season";
  first late`nextThreeProjected;
  avg 20 30f];
.t.eq["rest of season only counts the weeks left";
  first late`restOfSeasonProjected;
  sum 20 30f];
.t.eq["the season projection still counts every week";
  first late`seasonProjected;
  sum 10 20 30f];

/ And on the very last week there is only one week left.
finalWeek:.view.withWeekly[([] playerId:enlist `A); .schema.playerWeekStats; lateProjections; `half; 18i];
.t.eq["the last week averages only itself"; first finalWeek`nextThreeProjected; 30f];
