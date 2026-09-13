/ View models: pure functions that turn the stored tables into the shapes the
/ browser needs.  They take tables as arguments rather than reading globals so
/ that they can be tested directly against fixture data.

\d .view

/ One row of `source` for each element of `wanted`, matched on `keyColumn`.
/ Keys that are not found pick up `blankRow`, so the result always lines up
/ with `wanted` and no rows are silently dropped.
rowsFor:{[source;keyColumn;wanted;blankRow]
  padded:source upsert blankRow;
  padded (source keyColumn)?wanted
  }

blankUser:{[]
  .schema.users upsert enlist
    `leagueId`userId`username`displayName`teamName`avatar`isOwner!(`;`;"";"";"";"";0b)
  }

/ Use the first piece of text that is actually filled in.
coalesceText:{[preferred;fallback]
  $[count preferred; preferred; fallback]
  }

/ ---------------------------------------------------------------------------
/ Teams: rosters with their owner's names resolved
/ ---------------------------------------------------------------------------

teams:{[rosters;users]
  owners:rowsFor[users;`userId;rosters`ownerId;blankUser[]];
  joined:rosters,'`userId`username`displayName`teamName#owners;
  / Names inside a qsql statement resolve in the root namespace, so the helper
  / is fully qualified here.
  named:update
      teamName:.view.coalesceText'[teamName;.view.coalesceText'[displayName;"Team ",/:string rosterId]],
      ownerName:.view.coalesceText'[displayName;.view.coalesceText'[username;count[rosters]#enlist "Unowned"]]
    from joined;
  `rosterId`teamName`ownerName`username`userId`wins`losses`ties`pointsFor`pointsAgainst#named
  }

blankTeam:{[]
  (0#teams[.schema.rosters;.schema.users]) upsert enlist
    `rosterId`teamName`ownerName`username`userId`wins`losses`ties`pointsFor`pointsAgainst!
    (0Ni;"Unknown Team";"Unowned";"";`;0i;0i;0i;0f;0f)
  }

/ ---------------------------------------------------------------------------
/ Standings
/ ---------------------------------------------------------------------------

/ Ordered by wins, then by points scored, which is how Sleeper ranks a league.
standings:{[rosters;users]
  ordered:`wins`pointsFor xdesc teams[rosters;users];
  / `rank` is a reserved word in q, so the column is added by building the
  / column dictionary rather than with an update statement.
  ranked:flip (enlist[`rank]!enlist "i"$1+til count ordered),flip ordered;
  `rank`rosterId`teamName`ownerName`username`userId`wins`losses`ties`pointsFor`pointsAgainst#ranked
  }

/ ---------------------------------------------------------------------------
/ Matchups
/ ---------------------------------------------------------------------------

/ One head to head matchup: the teams involved, whether it has started and who
/ is ahead.  A matchup where nobody has scored yet has no winner.
buildPair:{[rows]
  scores:rows`points;
  started:any 0<scores;
  leaders:where scores=max scores;
  winner:$[started and 1=count leaders; rows[first leaders;`rosterId]; 0Ni];
  `matchupId`started`winnerRosterId`teams!(
    first rows`matchupId;
    started;
    winner;
    `rosterId`teamName`ownerName`points#rows)
  }

matchupPairs:{[matchupTable;rosters;users]
  if[0=count matchupTable; :()];
  labels:rowsFor[teams[rosters;users];`rosterId;matchupTable`rosterId;blankTeam[]];
  detailed:([] matchupId:matchupTable`matchupId;
               rosterId:matchupTable`rosterId;
               points:matchupTable`points;
               teamName:labels`teamName;
               ownerName:labels`ownerName);
  scheduled:select from detailed where not null matchupId;
  byes:select from detailed where null matchupId;
  pairs:{[scheduled;id] buildPair select from scheduled where matchupId=id}[scheduled;]
    each asc distinct scheduled`matchupId;
  / A roster with no opponent this week stands on its own, after the real games.
  pairs,{[row] buildPair enlist row} each byes
  }

/ ---------------------------------------------------------------------------
/ A single roster
/ ---------------------------------------------------------------------------

rosterPlayerColumns:`playerId`fullName`team`position`fantasyPositions`status`injuryStatus`number`age`starter`reserve`slot;

rosterDetail:{[wantedRosterId;rosters;users;rosterPlayers;playersTable]
  summary:select from teams[rosters;users] where rosterId=wantedRosterId;
  if[0=count summary; '"unknown roster ",string wantedRosterId];
  entries:select from rosterPlayers where rosterId=wantedRosterId;
  named:.tf.withPlayerNames[entries;playersTable];
  / Starters in line-up order first, then the bench alphabetically.
  starters:`slot xasc select from named where starter;
  bench:`fullName xasc select from named where not starter;
  `team`players!(first summary; rosterPlayerColumns#starters,bench)
  }

\d .
\d .view

/ ---------------------------------------------------------------------------
/ Small lookups used by the API layer
/ ---------------------------------------------------------------------------

/ A refresh downloads every week up to the one the league is currently playing,
/ so the latest stored week is the current week.
currentWeek:{[matchupTable]
  1i|0Ni^max matchupTable`week
  }

/ Which team belongs to the person named in the configuration file, so the UI
/ can highlight it.  Sleeper usernames are not case sensitive.
/ The parameter is renamed because a column of the same name would shadow it
/ inside the query.
configuredUserId:{[users;wantedUsername]
  if[0=count wantedUsername; :`];
  wanted:lower wantedUsername;
  matches:exec userId from users where wanted~/:lower each username;
  $[0=count matches; `; first matches]
  }

\d .
\d .view

/ ---------------------------------------------------------------------------
/ The player pool: who is out there, and who has them
/ ---------------------------------------------------------------------------

/ The positions every league plays.  A league that rosters defensive players
/ adds its own on top of these, so an IDP league still sees its free agents.
standardPositions:`QB`RB`WR`TE`K`DEF;

poolColumns:`playerId`fullName`team`position`available`rosteredBy`status`injuryStatus`age;

/ Everyone worth listing for this league: players on an NFL team in a position
/ the league plays, plus anybody actually on a roster here, so that a manager
/ can still see a player who has since been dropped by their NFL team.
/ Rostered ids that are not in the player reference data cannot be listed; the
/ roster page shows those by id.
playerPool:{[playersTable;rosterPlayers;rosters;users]
  owned:distinct rosterPlayers`playerId;
  rosteredPositions:exec position from playersTable where playerId in owned;
  interesting:distinct standardPositions,rosteredPositions except `;
  wanted:select from playersTable
    where ((position in interesting) and not null team) or playerId in owned;
  if[0=count wanted; :poolColumns#0#update available:0b, rosteredBy:() from playersTable];

  / Which team, if any, has each player.
  labels:teams[rosters;users];
  ownerNames:(rowsFor[labels;`rosterId;rosterPlayers`rosterId;blankTeam[]])`teamName;
  positions:(rosterPlayers`playerId)?wanted`playerId;
  listed:update
      available:not playerId in owned,
      rosteredBy:(ownerNames,enlist "") positions
    from wanted;
  poolColumns#listed
  }

\d .
\d .view

/ ---------------------------------------------------------------------------
/ Season scoring on top of the player pool
/ ---------------------------------------------------------------------------

/ Which of Sleeper's three precomputed point columns this league uses.
pointsColumnFor:{[scoringFormat]
  $[scoringFormat=`ppr;  `pointsPpr;
    scoringFormat=`half; `pointsHalf;
    `pointsStd]
  }

blankStats:{[]
  .schema.playerStats upsert enlist
    `playerId`season`games`pointsStd`pointsHalf`pointsPpr!(`;`;0i;0f;0f;0f)
  }

statsColumns:([] points:`float$(); games:`int$(); pointsPerGame:`float$());

/ Add this season's scoring to a player pool.  A player Sleeper has no stats
/ for scores nothing rather than dropping out of the list, and nobody is
/ divided by zero games.
/ A player who has not played has nothing to show rather than a score of zero.
/ Someone who played and scored nothing keeps their real zero.
withStats:{[pool;stats;scoringFormat]
  if[0=count pool; :pool,'statsColumns];
  matched:rowsFor[stats;`playerId;pool`playerId;blankStats[]];
  scored:matched pointsColumnFor scoringFormat;
  played:matched`games;
  neverPlayed:0i=played;
  pool,'([] points:?[neverPlayed; 0n; scored];
            games:played;
            pointsPerGame:?[neverPlayed; 0n; scored%played])
  }

\d .
\d .view

/ ---------------------------------------------------------------------------
/ Comparing players
/ ---------------------------------------------------------------------------

/ One row per stat that at least one of the players has, with a value for each
/ of them in the order they were asked for.  A stat a player does not have is
/ null rather than zero: they have no such stat, they did not record none.
statsSideBySide:{[statLines;playerIds]
  if[0=count playerIds; :([] stat:`$(); amounts:())];
  relevant:select from statLines where playerId in playerIds;
  if[0=count relevant; :([] stat:`$(); amounts:())];
  names:asc distinct relevant`stat;
  amountsFor:{[relevant;playerIds;name]
    forStat:select playerId,amount from relevant where stat=name;
    ((forStat`amount),0n) (forStat`playerId)?playerIds
    }[relevant;playerIds;];
  ([] stat:names; amounts:amountsFor each names)
  }

/ ---------------------------------------------------------------------------
/ Fixtures
/ ---------------------------------------------------------------------------

/ A team's week by week fixtures between two weeks, with the weeks they are not
/ playing marked as byes rather than left out.
/ The parameter is renamed because a column of the same name would shadow it
/ inside the query.
fixturesFor:{[scheduleTable;wantedTeam;fromWeek;toWeek]
  weeks:fromWeek+"i"$til 1+toWeek-fromWeek;
  played:`week xasc select week,opponent,home,gameDate,status from scheduleTable
    where team=wantedTeam, week within (fromWeek;toWeek);
  positions:(played`week)?weeks;
  ([] week:weeks;
      opponent:((played`opponent),`) positions;
      home:((played`home),0b) positions;
      gameDate:((played`gameDate),0Nd) positions;
      status:((played`status),`) positions;
      bye:not weeks in played`week)
  }

/ A player's whole season on one list: who they play each week, whether it is
/ indoors, what they scored and what they were projected.  A bye is a line of
/ its own rather than a gap.
seasonFixtures:{[scheduleTable;wantedTeam;gameLog;toWeek]
  fixtures:fixturesFor[scheduleTable;wantedTeam;1i;toWeek];
  / The roof belongs to whichever team is at home.
  hosts:?[fixtures`home; count[fixtures]#wantedTeam; fixtures`opponent];
  positions:(gameLog`week)?fixtures`week;
  fixtures,'([]
    roof:?[fixtures`bye; `; .venues.roofFor each hosts];
    points:((gameLog`points),0n) positions;
    projected:((gameLog`projected),0n) positions)
  }

/ ---------------------------------------------------------------------------
/ Form and outlook, from the weekly stats and projections
/ ---------------------------------------------------------------------------

/ Reduce a weekly table to just the points this league scores by.
actualPoints:{[weekStats;scoringFormat]
  ([] playerId:weekStats`playerId;
      week:weekStats`week;
      games:weekStats`games;
      points:weekStats pointsColumnFor scoringFormat)
  }

projectedPoints:{[weekProjections;scoringFormat]
  ([] playerId:weekProjections`playerId;
      week:weekProjections`week;
      projected:weekProjections pointsColumnFor scoringFormat)
  }

/ One value per player, lined up with `ids`.  A player the summary says nothing
/ about gets a null, which the browser shows as a dash: it means "we do not
/ know", which is not the same as zero.
valuesFor:{[summary;column;ids]
  if[0=count summary; :count[ids]#0n];
  ((summary column),0n) (summary`playerId)?ids
  }

weeklyColumns:([]
  lastThree:`float$();
  currentWeekPoints:`float$();
  currentWeekProjected:`float$();
  nextWeekProjected:`float$();
  nextThreeProjected:`float$();
  seasonProjected:`float$();
  restOfSeasonProjected:`float$();
  overUnderProjected:`float$());

/ "Next three weeks" is this week and the two after it, which is the window
/ people plan a line-up around.
nextThreeWeeks:3i;

/ How many weeks an NFL regular season runs to.
seasonWeeks:18i;

withWeekly:{[pool;weekStats;weekProjections;scoringFormat;currentWeek]
  if[0=count pool; :pool,'weeklyColumns];
  actuals:actualPoints[weekStats;scoringFormat];
  projected:projectedPoints[weekProjections;scoringFormat];
  ids:pool`playerId;

  / Only weeks the player actually appeared in count as games.
  played:`playerId`week xasc select from actuals where games>0, week<=currentWeek;
  lastThree:0!select lastThree:avg neg[3]#points by playerId from played;

  thisWeek:select playerId, currentWeekPoints:points from actuals where week=currentWeek;
  thisWeekProjected:select playerId, currentWeekProjected:projected from projected where week=currentWeek;
  nextWeek:select playerId, nextWeekProjected:projected from projected where week=currentWeek+1;
  / The next three weeks, clamped to the end of the season.  A week with no
  / projection is a bye: the player scores nothing, so the total is divided by
  / the number of weeks in the window rather than by the weeks projected.
  / (Locals, because a name inside a query resolves in the root namespace.)
  windowEnd:seasonWeeks&currentWeek+nextThreeWeeks-1i;
  windowLength:1+windowEnd-currentWeek;
  nextThree:0!select nextThreeProjected:(sum projected)%windowLength by playerId from projected
    where week within (currentWeek;windowEnd);
  seasonTotal:0!select seasonProjected:sum projected by playerId from projected;
  remaining:0!select restOfSeasonProjected:sum projected by playerId from projected
    where week>=currentWeek;

  / How a player has done against expectation, over the weeks they played.
  paired:ej[`playerId`week; played; projected];
  overUnder:0!select overUnderProjected:avg points-projected by playerId from paired;

  pool,'([]
    lastThree:             valuesFor[lastThree;`lastThree;ids];
    currentWeekPoints:     valuesFor[thisWeek;`currentWeekPoints;ids];
    currentWeekProjected:  valuesFor[thisWeekProjected;`currentWeekProjected;ids];
    nextWeekProjected:     valuesFor[nextWeek;`nextWeekProjected;ids];
    nextThreeProjected:    valuesFor[nextThree;`nextThreeProjected;ids];
    seasonProjected:       valuesFor[seasonTotal;`seasonProjected;ids];
    restOfSeasonProjected: valuesFor[remaining;`restOfSeasonProjected;ids];
    overUnderProjected:    valuesFor[overUnder;`overUnderProjected;ids])
  }

\d .
\d .view

/ ---------------------------------------------------------------------------
/ A side by side comparison of a handful of players
/ ---------------------------------------------------------------------------

/ A player the reference data has never heard of still gets a column, named by
/ their id, so a comparison never silently drops somebody.
blankPoolRow:{[playerId;owned]
  poolColumns!(playerId; string playerId; `; `; not playerId in owned; ""; `; `; 0Ni)
  }

/ What one player scored and was projected, week by week, including the weeks
/ they did not play.
gameLogFor:{[actuals;projected;wantedPlayer;upToWeek]
  weeks:1i+"i"$til upToWeek;
  mine:select week,points,games from actuals where playerId=wantedPlayer, week<=upToWeek;
  mineProjected:select week,projected from projected where playerId=wantedPlayer, week<=upToWeek;
  ([] week:weeks;
      points:((mine`points),0n) (mine`week)?weeks;
      played:((mine`games),0Ni) (mine`week)?weeks;
      projected:((mineProjected`projected),0n) (mineProjected`week)?weeks)
  }

/ One row per player asked for, in the order they were asked for, carrying
/ everything the players page shows plus a game log and their next fixtures.
/ `stored` holds the stored tables this needs: q allows a function eight
/ arguments and this wants rather more than that.
comparison:{[playerIds;stored;scoringFormat;currentWeek]
  rosterPlayers:stored`rosterPlayers;
  weekStats:stored`playerWeekStats;
  weekProjections:stored`playerWeekProjections;

  pool:playerPool[stored`players;rosterPlayers;stored`rosters;stored`users];
  missing:playerIds except pool`playerId;
  if[count missing;
    pool:pool upsert blankPoolRow[;distinct rosterPlayers`playerId] each missing];
  wanted:pool (pool`playerId)?playerIds;
  scored:withWeekly[
    withStats[wanted;stored`playerStats;scoringFormat];
    weekStats;weekProjections;scoringFormat;currentWeek];

  / Each player gets their whole season on one list: the fixture, the roof over
  / it, what they scored and what they were projected, week by week.
  actuals:actualPoints[weekStats;scoringFormat];
  projected:projectedPoints[weekProjections;scoringFormat];
  logs:gameLogFor[actuals;projected;;seasonWeeks] each playerIds;
  scored,'([]
    fixtures:seasonFixtures[stored`schedule;;;seasonWeeks] .' flip (scored`team;logs))
  }

\d .
